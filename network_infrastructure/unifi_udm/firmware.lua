-- Ubiquiti UniFi Dream Machine
-- Monitors UDM/UDM-Pro/UDM-SE via the UniFi Integration API.
-- Uses API Key authentication (X-API-Key header).
-- Generate a key in UniFi OS → Settings → Integrations.

local config = require('enapter.ucm.config')
local json = require('json')

local CONFIG_IP = 'ip_address'
local CONFIG_API_KEY = 'api_key'
local CONFIG_SITE = 'site'

local SITE_DEFAULT = 'default'

local api_client

-- Resolved site ID (UUID, looked up from site name on first poll)
local resolved_site_id

local telemetry_cache = {}
local properties_cache = {}
local active_alerts = {}

function main()
  -- config.init() automatically registers write_configuration and
  -- read_configuration commands — do NOT define them manually.
  config.init({
    [CONFIG_IP] = { type = 'string', required = true },
    [CONFIG_API_KEY] = { type = 'string', required = true },
    [CONFIG_SITE] = { type = 'string', required = false, default = SITE_DEFAULT },
  })

  api_client = http.client({ timeout = 30, insecure_tls = true })

  scheduler.add(1000, poll_data)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

-- Thin HTTP GET wrapper with API key auth.
local function api_get(path)
  local values, err = config.read_all()
  if err or not values[CONFIG_IP] or not values[CONFIG_API_KEY] then
    return nil, 'not_configured'
  end

  local url = 'https://' .. values[CONFIG_IP] .. '/proxy/network/integration/v1' .. path
  local req = http.request('GET', url)
  req:set_header('X-API-Key', values[CONFIG_API_KEY])
  req:set_header('Accept', 'application/json')

  local response, req_err = api_client:do_request(req)
  if req_err then
    enapter.log('API request failed: ' .. tostring(req_err), 'error')
    return nil, 'request_failed'
  end
  if response.code ~= 200 then
    enapter.log('API returned HTTP ' .. tostring(response.code) .. ' for ' .. path, 'error')
    return nil, 'http_' .. tostring(response.code)
  end

  local ok, decoded = pcall(json.decode, response.body)
  if not ok then
    return nil, 'json_decode_error'
  end
  return decoded, nil
end

-- Resolve the configured site name to a UUID via /v1/sites.
local function resolve_site_id()
  if resolved_site_id then
    return resolved_site_id
  end

  local result, err = api_get('/sites?limit=200')
  if err or not result or not result.data then
    return nil
  end

  local values, _ = config.read_all()
  local target = values and values[CONFIG_SITE] or SITE_DEFAULT

  for _, site in ipairs(result.data) do
    if site.name == target or site.internalReference == target then
      resolved_site_id = site.id
      return resolved_site_id
    end
  end

  -- If only one site exists, use it regardless of name
  if result.totalCount == 1 and result.data[1] then
    resolved_site_id = result.data[1].id
    return resolved_site_id
  end

  enapter.log('site "' .. target .. '" not found', 'error')
  return nil
end

-- Paginate through all results for a given endpoint.
local function api_get_all(path)
  local all_data = {}
  local offset = 0
  local limit = 200

  while true do
    local sep = path:find('?') and '&' or '?'
    local paged_path = path .. sep .. 'offset=' .. offset .. '&limit=' .. limit
    local result, err = api_get(paged_path)
    if err or not result or not result.data then
      return all_data, err
    end
    for _, item in ipairs(result.data) do
      all_data[#all_data + 1] = item
    end
    if #all_data >= (result.totalCount or 0) then
      break
    end
    offset = offset + limit
  end

  return all_data, nil
end

function poll_data()
  local alerts = {}

  local site_id = resolve_site_id()
  if not site_id then
    alerts['no_data'] = true
    telemetry_cache = {}
    active_alerts = alerts
    return
  end

  local telemetry = {}

  -- Fetch all adopted devices
  local devices, dev_err = api_get_all('/sites/' .. site_id .. '/devices')
  if dev_err then
    alerts['no_data'] = true
    telemetry_cache = {}
    active_alerts = alerts
    return
  end

  local udm_device_id
  local props = {}

  telemetry.num_devices = #devices

  for _, dev in ipairs(devices) do
    -- Identify the UDM/gateway device by model name or matching IP
    if not udm_device_id then
      local is_udm = false
      if dev.model and dev.model:find('Dream Machine') then
        is_udm = true
      end
      local cfg_values, _ = config.read_all()
      if not is_udm and cfg_values and dev.ipAddress == cfg_values[CONFIG_IP] then
        is_udm = true
      end
      if is_udm then
        udm_device_id = dev.id
        props = {
          model = dev.model or 'Unknown',
          firmware_version = dev.firmwareVersion,
          hostname = dev.name,
        }
      end
    end
  end

  -- Fetch UDM statistics (CPU, memory, uptime, uplink rates)
  if udm_device_id then
    local stats, stats_err = api_get('/sites/' .. site_id .. '/devices/' .. udm_device_id .. '/statistics/latest')
    if not stats_err and stats then
      telemetry.uptime_s = stats.uptimeSec
      telemetry.cpu_util = stats.cpuUtilizationPct
      telemetry.mem_util = stats.memoryUtilizationPct
      if stats.uplink then
        if stats.uplink.rxRateBps then
          telemetry.wan_download_mbps = stats.uplink.rxRateBps * 8 / 1000000
        end
        if stats.uplink.txRateBps then
          telemetry.wan_upload_mbps = stats.uplink.txRateBps * 8 / 1000000
        end
      end
      telemetry.status = 'ok'
      telemetry.wan_status = 'ok'
      telemetry.lan_status = 'ok'
      telemetry.wlan_status = 'ok'
    end
  end

  -- Fetch client counts
  local clients_result, _ = api_get('/sites/' .. site_id .. '/clients?limit=1')
  if clients_result then
    telemetry.num_clients = clients_result.totalCount or 0
  end

  local wired_result, _ = api_get('/sites/' .. site_id .. "/clients?limit=1&filter=type.eq('WIRED')")
  if wired_result then
    telemetry.num_lan_clients = wired_result.totalCount or 0
  end

  local wireless_result, _ = api_get('/sites/' .. site_id .. "/clients?limit=1&filter=type.eq('WIRELESS')")
  if wireless_result then
    telemetry.num_wlan_clients = wireless_result.totalCount or 0
  end

  if not telemetry.status then
    telemetry.status = 'unknown'
    telemetry.wan_status = 'unknown'
    telemetry.lan_status = 'unknown'
    telemetry.wlan_status = 'unknown'
  end

  if telemetry.cpu_util and telemetry.cpu_util > 90 then
    alerts['high_cpu'] = true
  end
  if telemetry.mem_util and telemetry.mem_util > 90 then
    alerts['high_memory'] = true
  end

  telemetry_cache = telemetry
  active_alerts = alerts
  if props and next(props) then
    properties_cache = props
  end
end

function send_telemetry()
  local telemetry = telemetry_cache
  if not telemetry.status then
    telemetry = { status = 'unknown' }
  end

  enapter.send_telemetry(telemetry)

  local alerts = active_alerts
  for alert_key, _ in pairs(alerts) do
    enapter.send_telemetry({ alerts = { alert_key } })
  end
  if next(alerts) == nil then
    enapter.send_telemetry({ alerts = {} })
  end
end

function send_properties()
  if properties_cache and next(properties_cache) then
    enapter.send_properties(properties_cache)
  end
end

main()
