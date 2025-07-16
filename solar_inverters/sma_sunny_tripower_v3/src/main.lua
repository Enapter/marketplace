local smamodbus = require('./smamodbus')

local conn = nil
local conn_cfg = nil
local conn_error_msg = nil

function main()
  reconnect()
  configuration.after_write('connection', function()
    conn = nil
    conn_cfg = nil
  end)
  scheduler.add(1000, reconnect)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_realtime_telemetry)
  scheduler.add(5000, send_detailed_telemetry)
end

function reconnect()
  if conn then
    return
  end

  local configured = configuration.is_all_required_set('connection')
  if not configured then
    return
  end

  local cfg, err = configuration.read('connection')
  if err ~= nil then
    conn_error_msg = 'failed to read configuration: ' .. err
    return
  end

  conn_cfg = cfg
  local sma = smamodbus.new(conn_cfg.address, conn_cfg.unit_id)
  local err = sma:connect()
  if err then
    conn_error_msg = 'failed to connect: ' .. err
    return
  end

  conn = sma
  conn_error_msg = nil
end

function send_properties()
  if not conn then
    return
  end

  local properties = {}
  properties.vendor = 'SMA'
  properties.model = parse_model(conn:read_u32_enum(30053))
  properties.serial_number = tostring(conn:read_u32_fix0(30057))
  properties.firmware_version = parse_firmware_version(conn:read_u32_fix0(30059))
  properties.inverter_nameplate_capacity = conn:read_u32_fix0(40185)
  properties.country_code = parse_country_code(conn:read_u32_fix0(40109))
  if conn_cfg then
    properties.address = conn_cfg.address
    properties.unit_id = conn_cfg.unit_id
  end

  enapter.send_properties(properties)
end

function send_realtime_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ alerts = { 'not_configured' } })
    return
  end

  if not conn then
    enapter.send_telemetry({
      alerts = { 'conn_error' },
      alert_details = { conn_error = { errmsg = conn_error_msg } },
    })
    enapter.log(conn_error_msg, 'error', true)
    return
  end

  local started = os.clock()
  local operating_status = parse_operating_status(conn:read_u32_enum(40029))
  local telemetry = {
    alerts = parse_alerts(conn:read_u32_enum(30213), conn:read_u32_enum(30247)),
    operating_status = operating_status,
    status = convert_operating_status_to_status(operating_status),

    pv_voltage = conn:read_s32_fix2(30771),
    pv_power = conn:read_s32_fix0(30773),

    ac_total_power = conn:read_s32_fix0(30775),
    ac_frequency = conn:read_u32_fix2(30803),
  }
  telemetry.read_time = math.ceil((os.clock() - started) * 1000) / 1000 -- round

  enapter.send_telemetry(telemetry)
end

function send_detailed_telemetry()
  -- send_realtime_telemetry reports alert
  if not conn then
    return
  end

  local started = os.clock()
  local ac_l1_power = conn:read_s32_fix0(30777)
  local ac_l2_power = conn:read_s32_fix0(30779)
  local ac_l3_power = conn:read_s32_fix0(30781)
  local ac_l1_power_va = conn:read_s32_fix0(30815)
  local ac_l2_power_va = conn:read_s32_fix0(30817)
  local ac_l3_power_va = conn:read_s32_fix0(30819)
  local pv_throttled = false
  local derating_reason = parse_derating_reason(conn:read_u32_enum(30219))
  if derating_reason ~= 'ok' then
    pv_throttled = true
  end

  local telemetry = {
    recommended_action = parse_recommended_action(conn:read_u32_enum(30211)),
    derating_reason = derating_reason,
    pv_throttled = pv_throttled,

    grid_relay_closed = parse_grid_relay_closed(conn:read_u32_enum(30217)),

    pv_current = conn:read_s32_fix3(30769),

    ac_power_var = conn:read_s32_fix0(30805),
    ac_power_va = conn:read_s32_fix0(30813),
    ac_cos_phi = conn:read_u32_fix3(30949),

    ac_l1_power = ac_l1_power,
    ac_l2_power = ac_l2_power,
    ac_l3_power = ac_l3_power,
    ac_l1_current = conn:read_s32_fix3(31435),
    ac_l2_current = conn:read_s32_fix3(31437),
    ac_l3_current = conn:read_s32_fix3(31439),
    ac_l1_voltage = conn:read_u32_fix2(30783),
    ac_l2_voltage = conn:read_u32_fix2(30785),
    ac_l3_voltage = conn:read_u32_fix2(30787),
    ac_l1_power_var = conn:read_s32_fix0(30807),
    ac_l2_power_var = conn:read_s32_fix0(30809),
    ac_l3_power_var = conn:read_s32_fix0(30811),
    ac_l1_power_va = ac_l1_power_va,
    ac_l2_power_va = ac_l2_power_va,
    ac_l3_power_va = ac_l3_power_va,
    ac_l1_power_factor = ac_l1_power / ac_l1_power_va,
    ac_l2_power_factor = ac_l2_power / ac_l2_power_va,
    ac_l3_power_factor = ac_l3_power / ac_l3_power_va,

    residual_current = conn:read_s32_fix3(31247),
    heatsink_temperature = conn:read_s32_fix1(34109),
    internal_temperature = conn:read_s32_fix1(34113),

    ac_energy_total = conn:read_u32_fix0(30529),
    ac_energy_today = conn:read_u32_fix0(30535),
  }
  telemetry.read_time = math.ceil((os.clock() - started) * 1000) / 1000 -- round

  enapter.send_telemetry(telemetry)
end

function parse_model(value)
  if not value then
    return
  end

  if value == 19048 then
    return 'STP5.0-3SE-40'
  elseif value == 19049 then
    return 'STP6.0-3SE-40'
  elseif value == 19050 then
    return 'STP8.0-3SE-40'
  elseif value == 19051 then
    return 'STP10.0-3SE-40'
  elseif value == 9284 then
    return 'STP 20000TL-30'
  elseif value == 9285 then
    return 'STP 25000TL-30'
  elseif value == 9336 then
    return 'STP 15000TL-30'
  elseif value == 9337 then
    return 'STP 17000TL-30'
  elseif value == 9338 then
    return 'STP50-40'
  elseif value == 9339 then
    return 'STP50-US-40'
  elseif value == 9340 then
    return 'STP50-JP-40'
  elseif value == 9344 then
    return 'STP4.0-3AV-40'
  elseif value == 9345 then
    return 'STP5.0-3AV-40'
  elseif value == 9346 then
    return 'STP6.0-3AV-40'
  elseif value == 9347 then
    return 'STP8.0-3AV-40'
  elseif value == 9348 then
    return 'STP10.0-3AV-40'
  elseif value == 9366 then
    return 'STP3.0-3AV-40'
  elseif value == 9428 then
    return 'STP62-US-41'
  elseif value == 9429 then
    return 'STP50-US-41'
  elseif value == 9430 then
    return 'STP33-US-41'
  elseif value == 9431 then
    return 'STP50-41'
  elseif value == 9432 then
    return 'STP50-JP-41'
  -- archive models
  elseif value == 9067 then
    return 'STP 10000TL-10'
  elseif value == 9068 then
    return 'STP 12000TL-10'
  elseif value == 9069 then
    return 'STP 15000TL-10'
  elseif value == 9070 then
    return 'STP 17000TL-10'
  elseif value == 9098 then
    return 'STP 5000TL-20'
  elseif value == 9099 then
    return 'STP 6000TL-20'
  elseif value == 9100 then
    return 'STP 7000TL-20'
  elseif value == 9101 then
    return 'STP 8000TL-10'
  elseif value == 9102 then
    return 'STP 9000TL-20'
  elseif value == 9103 then
    return 'STP 8000TL-20'
  elseif value == 9131 then
    return 'STP 20000TL-10'
  elseif value == 9139 then
    return 'STP 20000TLHE-10'
  elseif value == 9140 then
    return 'STP 15000TLHE-10'
  elseif value == 9181 then
    return 'STP 20000TLEE-10'
  elseif value == 9182 then
    return 'STP 15000TLEE-10'
  elseif value == 9281 then
    return 'STP 10000TL-20'
  elseif value == 9282 then
    return 'STP 11000TL-20'
  elseif value == 9283 then
    return 'STP 12000TL-20'
  else
    enapter.log('Cannot decode model: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function parse_recommended_action(value)
  if not value then
    return
  end

  if value == 336 then
    return 'contact_manufacturer'
  elseif value == 337 then
    return 'contact_installer'
  elseif value == 338 or value == 887 then
    return 'ok'
  else
    enapter.log('Cannot decode recommended action: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function parse_grid_relay_closed(value)
  if not value then
    return
  end

  if value == 51 then
    return true -- closed
  elseif value == 311 then
    return false -- open
  else
    enapter.log('Cannot decode grid relay status: ' .. tostring(value), 'error')
    return
  end
end

function parse_operating_status(value)
  if not value then
    return
  end

  if value == 1295 then
    return 'standby'
  elseif value == 1392 then
    return 'fault'
  elseif value == 1393 then
    return 'waiting_pv_voltage'
  elseif value == 1467 then
    return 'starting'
  elseif value == 1469 then
    return 'shutting_down'
  elseif value == 1480 then
    return 'waiting_utilities'
  elseif value == 1795 then
    return 'bolted'
  elseif value == 1855 then
    return 'standalone'
  elseif value == 2119 then
    return 'derating'
  elseif value == 295 then
    return 'mpp'
  elseif value == 303 then
    return 'off'
  elseif value == 381 then
    return 'stop'
  elseif value == 443 then
    return 'const_voltage'
  elseif value == 455 then
    return 'warning'
  elseif value == 569 then
    return 'operating'
  else
    enapter.log('Cannot decode operation status: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function convert_operating_status_to_status(value)
  if not value then
    return
  end

  if value == 'off' or value == 'stop' then
    return 'off'
  elseif value == 'standby' or value == 'waiting_pv_voltage' or value == 'waiting_utilities' or value == 'bolted' then
    return 'standby'
  elseif value == 'start' then
    return 'starting'
  elseif value == 'derating' or value == 'mpp' or value == 'run' then
    return 'operating'
  elseif value == 'shutdown' then
    return 'shutting_down'
  elseif value == 'fault' then
    return 'fault'
  end
end

function parse_alerts(presence, message)
  if not presence and not message then
    return
  end

  if presence == 886 or presence == 302 then
    return {}
  elseif message then
    return { 'e' .. tostring(message) }
  else
    return { 'unknown_event' }
  end
end

function parse_firmware_version(value)
  if not value then
    return
  end

  local release_id = value & 0xFF
  local build = (value >> 8) & 0xFF
  local minor = (value >> 16) & 0xFF
  local major = (value >> 24) & 0xFF

  local release
  if release_id == 0 then
    release = 'N'
  elseif release_id == 1 then
    release = 'E'
  elseif release_id == 2 then
    release = 'A'
  elseif release_id == 3 then
    release = 'B'
  elseif release_id == 4 then
    release = 'R'
  elseif release_id == 4 then
    release = 'S'
  else
    release = tostring(release_id)
  end

  return major .. '.' .. minor .. '.' .. build .. '.' .. release
end

function parse_derating_reason(value)
  if not value then
    return
  end

  if value == 1705 then
    return 'frequency_deviation'
  elseif value == 3520 then
    return 'voltage_deviation'
  elseif value == 3554 then
    return 'reactive_power_priority'
  elseif value == 3556 then
    return 'high_dc_voltage'
  elseif value == 4560 then
    return 'external_setting'
  elseif value == 4561 then
    return 'external_setting_2'
  elseif value == 557 then
    return 'overtemperature'
  elseif value == 884 then
    return 'ok'
  else
    enapter.log('Cannot decode derating reason: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function parse_country_code(value)
  if not value then
    return
  end

  if value == 1199 then
    return 'PPDS'
  elseif value == 27 then
    return 'Adj'
  elseif value == 306 then
    return 'Off-Grid60'
  elseif value == 313 then
    return 'Off-Grid50'
  elseif value == 333 then
    return 'PPC'
  elseif value == 42 then
    return 'AS4777.3'
  elseif value == 438 then
    return 'VDE0126-1-1'
  elseif value == 7504 then
    return 'SI4777-2'
  elseif value == 7508 then
    return 'JP50'
  elseif value == 7509 then
    return 'JP60'
  elseif value == 7510 then
    return 'VDE-AR-N4105'
  elseif value == 7513 then
    return 'VDE-AR-N4105-MP'
  elseif value == 7514 then
    return 'VDE-AR-N4105-HP'
  elseif value == 7517 then
    return 'CEI0-21Int'
  elseif value == 7518 then
    return 'CEI0-21Ext'
  elseif value == 7523 then
    return 'C10/11/2012'
  elseif value == 7525 then
    return 'G83/2'
  elseif value == 7527 then
    return 'VFR2014'
  elseif value == 7528 then
    return 'G59/3'
  elseif value == 7530 then
    return 'MEA2013'
  elseif value == 7531 then
    return 'PEA2013'
  elseif value == 7532 then
    return 'EN50438_2013'
  elseif value == 7533 then
    return 'NEN-EN50438_13'
  elseif value == 7535 then
    return 'WorstCase'
  elseif value == 7536 then
    return 'DftEN'
  elseif value == 7538 then
    return 'SI4777_HS131_13'
  elseif value == 7539 then
    return 'RD1699/413'
  elseif value == 7549 then
    return 'AS4777.2_2015'
  elseif value == 7550 then
    return 'NRS97-2-1'
  elseif value == 7551 then
    return 'NT_Ley2057'
  elseif value == 7556 then
    return 'MEA2016'
  elseif value == 7557 then
    return 'PEA2016'
  elseif value == 7559 then
    return 'UL1741/2016/120'
  elseif value == 7560 then
    return 'UL1741/2016/240'
  elseif value == 7561 then
    return 'UL1741/2016/208'
  elseif value == 7562 then
    return 'HECO2017/120'
  elseif value == 7563 then
    return 'HECO2017/208'
  elseif value == 7564 then
    return 'HECO2017/240'
  elseif value == 7565 then
    return 'ABNT_NBR_16149_2013'
  elseif value == 7566 then
    return 'IE-EN50438_2013'
  elseif value == 7567 then
    return 'DEWA_2016_intern'
  elseif value == 7568 then
    return 'DEWA_2016_extern'
  elseif value == 7569 then
    return 'TOR_D4_2016'
  elseif value == 7573 then
    return 'G83/2-1_2018'
  elseif value == 7574 then
    return 'G59/3-4_2018'
  elseif value == 7584 then
    return 'VDEARN4105/18a'
  elseif value == 7586 then
    return 'VDEARN4105/18c'
  elseif value == 7590 then
    return 'EN50549-1/18'
  elseif value == 7592 then
    return 'DftSMA/19'
  elseif value == 7594 then
    return 'ENA-G98/1/18'
  elseif value == 7595 then
    return 'ENA-G99/1/18'
  elseif value == 7599 then
    return 'DK1-West/19'
  elseif value == 7600 then
    return 'DK2-East/19'
  elseif value == 7602 then
    return 'BE-C10/11/19-09 PV_a'
  elseif value == 7603 then
    return 'BE-C10/11/19-09 PV_b'
  elseif value == 7610 then
    return 'IT-CEI0-21/19_a'
  elseif value == 7612 then
    return 'IT-CEI0-21/19_c'
  elseif value == 7615 then
    return 'AT-TOR-Erzeuger-A/19_b'
  else
    enapter.log('Cannot decode country code: ' .. tostring(value), 'error')
    return
  end
end

main()
