-- Starlink Gen4 Dish
-- Communicates via gRPC (HTTP/2 h2c) with the dish local API at 192.168.100.1:9200
-- Service: SpaceX.API.Device.Device/Handle
--
-- Two RPCs:
--   GetStatus  (field 1004 → field 2004 response): real-time metrics, every 30s
--   GetHistory (field 1007 → field 2006 response): power consumption, every 60s

local DISH_IP = '192.168.100.1'
local GRPC_PORT = 9200
local GRPC_PATH = '/SpaceX.API.Device.Device/Handle'

-- gRPC frame for Request { get_status: {} }
-- Field 1004, wire type 2, empty sub-message
-- Tag varint: (1004 << 3) | 2 = 8034 = 0xE2 0x3E
local STATUS_REQUEST = string.char(0x00, 0x00, 0x00, 0x00, 0x03, 0xE2, 0x3E, 0x00)

-- gRPC frame for Request { get_history: {} }
-- Field 1007, wire type 2, empty sub-message
-- Tag varint: (1007 << 3) | 2 = 8058 = 0xFA 0x3E
local HISTORY_REQUEST = string.char(0x00, 0x00, 0x00, 0x00, 0x03, 0xFA, 0x3E, 0x00)

-- gRPC frame for Request { reboot: {} }
-- Field 1001, wire type 2, empty sub-message
-- Tag varint: (1001 << 3) | 2 = 8010 = 0xCA 0x3E
local REBOOT_REQUEST = string.char(0x00, 0x00, 0x00, 0x00, 0x03, 0xCA, 0x3E, 0x00)

-- UtDisablementCode enum → manifest status string
local DISABLEMENT_STATUS = {
  [0] = 'Unknown',
  [1] = 'Connected',
  [2] = 'No active account',
  [3] = 'Too far from service address',
  [4] = 'In ocean',
  [6] = 'Blocked country',
  [7] = 'Data overage',
  [8] = 'Cell disabled',
  [10] = 'Roam restricted',
  [11] = 'Unknown location',
  [12] = 'Account disabled',
  [13] = 'Unsupported version',
  [14] = 'Moving too fast',
  [15] = 'Aviation flyover limits',
  [16] = 'Blocked area',
}

local SOFTWARE_UPDATE_STATE = {
  [0] = 'unknown',
  [1] = 'idle',
  [2] = 'fetching',
  [3] = 'pre_check',
  [4] = 'writing',
  [5] = 'post_check',
  [6] = 'reboot_required',
  [7] = 'disabled',
  [8] = 'faulted',
}

-- Cached state; fetch_status/fetch_history update these, send_telemetry reads them
local status_cache = {}
local status_err = 'no_data'
local history_cache = {}
local device_info = {}

local function pb_varint(data, pos)
  local n = 0
  local mul = 1
  local b
  repeat
    b = string.byte(data, pos)
    if not b then
      break
    end
    n = n + (b % 128) * mul
    mul = mul * 128
    pos = pos + 1
  until b < 128
  return n, pos
end

local function pb_skip(data, pos, wt)
  if wt == 0 then
    local b
    repeat
      b = string.byte(data, pos)
      pos = pos + 1
    until not b or b < 128
  elseif wt == 1 then
    pos = pos + 8
  elseif wt == 2 then
    local len
    len, pos = pb_varint(data, pos)
    pos = pos + len
  elseif wt == 5 then
    pos = pos + 4
  end
  return pos
end

local function pb_parse(data, from, to)
  local r = {}
  local pos = from
  while pos <= to do
    local tag, p = pb_varint(data, pos)
    if p > to + 1 or tag == 0 then
      break
    end
    pos = p
    local fnum = tag // 8
    local wt = tag % 8
    if wt == 0 then
      local val
      val, pos = pb_varint(data, pos)
      r[fnum] = val
    elseif wt == 5 then
      local v = (string.unpack('<f', data, pos))
      r[fnum] = (v == v) and v or nil -- drop NaN
      pos = pos + 4
    elseif wt == 2 then
      local len
      len, pos = pb_varint(data, pos)
      r[fnum] = string.sub(data, pos, pos + len - 1)
      pos = pos + len
    else
      pos = pb_skip(data, pos, wt)
    end
  end
  return r
end

local function grpc_request(body, timeout)
  local url = 'http://' .. DISH_IP .. ':' .. GRPC_PORT .. GRPC_PATH
  local req = http.request('POST', url, body)
  req:set_header('Content-Type', 'application/grpc')
  req:set_header('TE', 'trailers')

  local client = http.client({ timeout = timeout, http2 = true })
  local resp, err = client:do_request(req)
  if err then
    return nil, 'HTTP error: ' .. tostring(err)
  end
  if resp.code ~= 200 then
    return nil, 'HTTP status: ' .. tostring(resp.code)
  end
  local grpc_status = resp.headers:get('grpc-status')
  if grpc_status and grpc_status ~= '0' then
    local grpc_msg = resp.headers:get('grpc-message')
    return nil, 'gRPC error: status=' .. grpc_status .. ' ' .. tostring(grpc_msg)
  end
  return resp.body, nil
end

local function decode_status(body)
  if not body or #body < 5 then
    return nil, 'body too short'
  end
  if string.byte(body, 1) ~= 0x00 then
    return nil, 'compressed response not supported'
  end

  local msg_len = (string.unpack('>I4', body, 2))
  if #body < 5 + msg_len then
    return nil, 'truncated response'
  end

  local resp = pb_parse(body, 6, 5 + msg_len)
  local raw_st = resp[2004]
  if not raw_st then
    return nil, 'no DishGetStatusResponse (field 2004) in response'
  end

  local st = pb_parse(raw_st, 1, #raw_st)
  local d = {}

  if st[1] then
    local di = pb_parse(st[1], 1, #st[1])
    d.id = di[1]
    d.hardware_version = di[2]
    d.software_version = di[3]
    d.country_code = di[4]
  end

  if st[2] then
    local ds = pb_parse(st[2], 1, #st[2])
    d.uptime_s = ds[1]
  end

  d.ping_drop_rate = st[1003]
  d.downlink_throughput_bps = st[1007]
  d.uplink_throughput_bps = st[1008]
  d.latency_ms = st[1009]
  d.azimuth_deg = st[1011]
  d.elevation_deg = st[1012]
  d.snr_above_noise_floor = (st[1018] == 1)
  d.eth_speed_mbps = st[1016]

  local dc = st[1024] or 0
  d.disablement_code = dc
  d.status = DISABLEMENT_STATUS[dc] or 'Unknown'

  local su = st[1021] or 0
  d.software_update_state = SOFTWARE_UPDATE_STATE[su] or 'unknown'

  if st[1004] then
    local obs = pb_parse(st[1004], 1, #st[1004])
    d.fraction_obstructed = obs[1]
    d.currently_obstructed = (obs[5] == 1)
  end

  if st[1005] then
    local al = pb_parse(st[1005], 1, #st[1005])
    d.alert_motors_stuck = al[1]
    d.alert_thermal_shutdown = al[2]
    d.alert_thermal_throttle = al[3]
    d.alert_unexpected_location = al[4]
    d.alert_mast_not_near_vertical = al[5]
    d.alert_slow_ethernet = al[6]
    d.alert_roaming = al[7]
    d.alert_install_pending = al[8]
    d.alert_is_heating = al[9]
    d.alert_ps_thermal_throttle = al[10]
    d.alert_power_save_idle = al[11]
    d.alert_dish_water_detected = al[20]
    d.alert_no_ethernet_link = al[23]
  end

  if st[1015] then
    local gps = pb_parse(st[1015], 1, #st[1015])
    d.gps_valid = (gps[1] == 1)
    d.gps_sats = gps[2]
  end

  return d, nil
end

local function decode_history_power(body)
  if not body or #body < 5 then
    return nil
  end
  if string.byte(body, 1) ~= 0x00 then
    return nil
  end

  local msg_len = (string.unpack('>I4', body, 2))
  local parse_to = 5 + msg_len
  if #body < parse_to then
    parse_to = #body
  end

  local resp = pb_parse(body, 6, parse_to)
  local raw_hist = resp[2006]
  if not raw_hist then
    return nil
  end

  local hist = pb_parse(raw_hist, 1, #raw_hist)
  local ci = hist[1] or 0
  local pw = hist[1010]
  if not pw then
    return nil
  end

  local total = #pw // 4
  if total == 0 then
    return nil
  end

  local idx = (ci - 1 + total) % total
  local v = (string.unpack('<f', pw, idx * 4 + 1))
  return (v == v) and v or nil -- drop NaN
end

local function fetch_status()
  local body, err = grpc_request(STATUS_REQUEST, 5)
  if not body then
    enapter.log(tostring(err), 'error')
    status_err = 'no_data'
    return
  end

  local data, parse_err = decode_status(body)
  if not data then
    enapter.log('Status parse error: ' .. tostring(parse_err), 'error')
    status_err = 'no_data'
    return
  end

  if data.id then
    device_info.id = data.id
    device_info.hardware_version = data.hardware_version
    device_info.software_version = data.software_version
    device_info.country_code = data.country_code
    device_info.eth_speed_mbps = data.eth_speed_mbps
  end

  status_cache = data
  status_err = nil
end

local function fetch_history()
  local body, err = grpc_request(HISTORY_REQUEST, 30)
  if not body then
    enapter.log('History request failed: ' .. tostring(err), 'error')
    return
  end

  local power_w = decode_history_power(body)
  if power_w then
    history_cache.power_w = power_w
  end
end

local function send_properties()
  enapter.send_properties({
    id = device_info.id,
    hardware_version = device_info.hardware_version,
    software_version = device_info.software_version,
    country_code = device_info.country_code,
    eth_speed_mbps = device_info.eth_speed_mbps,
  })
end

local function send_telemetry()
  if status_err then
    enapter.send_telemetry({ status = 'No data', alerts = { 'no_data' } })
    return
  end

  local d = status_cache
  local al = {}

  if d.currently_obstructed then
    table.insert(al, 'obstructed')
  end
  if d.alert_motors_stuck == 1 then
    table.insert(al, 'motors_stuck')
  end
  if d.alert_thermal_shutdown == 1 then
    table.insert(al, 'thermal_shutdown')
  end
  if d.alert_thermal_throttle == 1 then
    table.insert(al, 'thermal_throttle')
  end
  if d.alert_ps_thermal_throttle == 1 then
    table.insert(al, 'power_supply_thermal_throttle')
  end
  if d.alert_mast_not_near_vertical == 1 then
    table.insert(al, 'mast_not_near_vertical')
  end
  if d.alert_slow_ethernet == 1 then
    table.insert(al, 'slow_ethernet_speeds')
  end
  if d.alert_install_pending == 1 then
    table.insert(al, 'install_pending')
  end
  if d.alert_is_heating == 1 then
    table.insert(al, 'is_heating')
  end
  if d.alert_roaming == 1 then
    table.insert(al, 'roaming')
  end
  if d.alert_unexpected_location == 1 then
    table.insert(al, 'unexpected_location')
  end
  if d.alert_power_save_idle == 1 then
    table.insert(al, 'power_save_idle')
  end
  if d.alert_dish_water_detected == 1 then
    table.insert(al, 'dish_water_detected')
  end
  if d.alert_no_ethernet_link == 1 then
    table.insert(al, 'no_ethernet_link')
  end

  enapter.send_telemetry({
    status = d.status,
    software_update_state = d.software_update_state,
    downlink_throughput_mbps = d.downlink_throughput_bps and d.downlink_throughput_bps / 1e6,
    uplink_throughput_mbps = d.uplink_throughput_bps and d.uplink_throughput_bps / 1e6,
    ping_latency_ms = d.latency_ms,
    ping_drop_rate = d.ping_drop_rate and d.ping_drop_rate * 100,
    azimuth_deg = d.azimuth_deg,
    elevation_deg = d.elevation_deg,
    fraction_obstructed = d.fraction_obstructed and d.fraction_obstructed * 100,
    snr_above_noise_floor = d.snr_above_noise_floor,
    gps_valid = d.gps_valid,
    gps_sats = d.gps_sats,
    uptime_s = d.uptime_s,
    power_w = history_cache.power_w,
    alerts = al,
  })
end

local function cmd_reboot(ctx, _args)
  local _, err = grpc_request(REBOOT_REQUEST, 10)
  if err then
    ctx.error('Reboot failed: ' .. err)
  end
end

local function main()
  enapter.register_command_handler('reboot', cmd_reboot)

  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, fetch_status)
  scheduler.add(60000, fetch_history)
  scheduler.add(30000, send_properties)

  fetch_status()
  fetch_history()
  send_properties()
end

main()
