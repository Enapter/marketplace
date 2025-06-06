local smamodbus = require('./smamodbus')

local conn = nil
local conn_cfg = nil

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
    enapter.log('read configuration: ' .. err, 'error')
    return
  end

  conn_cfg = cfg
  local sma = smamodbus.new(conn_cfg.address, conn_cfg.unit_id)
  local err = sma:connect()
  if err ~= nil then
    enapter.log('connect: ' .. err, 'error')
    return
  end

  conn = sma
end

function send_properties()
  if not conn then
    return
  end

  local properties = {}
  properties.model = parse_model(conn:read_u32_enum(30053))
  properties.vendor = 'SMA'
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
    enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    return
  end
  if not conn then
    enapter.send_telemetry({ status = 'error', alerts = { 'cannot_connect' } })
    return
  end

  local started = os.clock()
  local operating_status = parse_operating_status(conn:read_u32_enum(40029))
  local telemetry = {
    alerts = parse_alerts(conn:read_u32_enum(30213), conn:read_u32_enum(30247)),
    health = parse_health_status(conn:read_u32_enum(30201)),
    operating_status = operating_status,
    status = convert_operating_status_to_status(operating_status),

    dc_voltage = conn:read_s32_fix2(30771),
    dc_power = conn:read_s32_fix0(30773),
    ac_power = conn:read_s32_fix0(30775),
    ac_total_power = conn:read_s32_fix0(30777),
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
  local telemetry = {
    recommended_action = parse_recom_action(conn:read_u32_enum(30211)),
    derating_reason = parse_derating_reason(conn:read_u32_enum(30219)),
    grid_relay_closed = parse_grid_relay_closed(conn:read_u32_enum(30217)),

    dc_amperage = conn:read_s32_fix3(30769),

    -- there are 3 phases in Modbus, but SB is 1-phase inverter
    ac_voltage = conn:read_u32_fix2(30783),
    ac_power_var = conn:read_s32_fix0(30805),
    ac_power_va = conn:read_s32_fix0(30813),
    ac_cos_phi = conn:read_u32_fix3(30949),

    residual_amperage = conn:read_s32_fix3(31247),
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

  if value == 9301 then
    return 'SB1.5-1VL-40'
  elseif value == 9302 then
    return 'SB2.5-1VL-40'
  elseif value == 9303 then
    return 'SB2.0-1VL-40'
  elseif value == 9304 then
    return 'SB5.0-1SP-US-40'
  elseif value == 9305 then
    return 'SB6.0-1SP-US-40'
  elseif value == 9306 then
    return 'SB7.7-1SP-US-40'
  elseif value == 9319 then
    return 'SB3.0-1AV-40'
  elseif value == 9320 then
    return 'SB3.6-1AV-40'
  elseif value == 9321 then
    return 'SB4.0-1AV-40'
  elseif value == 9322 then
    return 'SB5.0-1AV-40'
  elseif value == 9328 then
    return 'SB3.0-1SP-US-40'
  elseif value == 9329 then
    return 'SB3.8-1SP-US-40'
  elseif value == 9330 then
    return 'SB7.0-1SP-US-40'
  elseif value == 9401 then
    return 'SB3.0-1AV-41'
  elseif value == 9402 then
    return 'SB3.6-1AV-41'
  elseif value == 9403 then
    return 'SB4.0-1AV-41'
  elseif value == 9404 then
    return 'SB5.0-1AV-41'
  elseif value == 9405 then
    return 'SB6.0-1AV-41'
  elseif value == 9455 then
    return 'SB5.5-LV-JP-41'
    -- archive models
  elseif value == 9015 then
    return 'SB 700'
  elseif value == 9016 then
    return 'SB 700U'
  elseif value == 9017 then
    return 'SB 1100'
  elseif value == 9018 then
    return 'SB 1100U'
  elseif value == 9019 then
    return 'SB 1100LV'
  elseif value == 9020 then
    return 'SB 1700'
  elseif value == 9021 then
    return 'SB 1900TLJ'
  elseif value == 9022 then
    return 'SB 2100TL'
  elseif value == 9023 then
    return 'SB 2500'
  elseif value == 9024 then
    return 'SB 2800'
  elseif value == 9025 then
    return 'SB 2800i'
  elseif value == 9026 then
    return 'SB 3000'
  elseif value == 9027 then
    return 'SB 3000US'
  elseif value == 9028 then
    return 'SB 3300'
  elseif value == 9029 then
    return 'SB 3300U'
  elseif value == 9030 then
    return 'SB 3300TL'
  elseif value == 9031 then
    return 'SB 3300TL HC'
  elseif value == 9032 then
    return 'SB 3800'
  elseif value == 9033 then
    return 'SB 3800U'
  elseif value == 9034 then
    return 'SB 4000US'
  elseif value == 9035 then
    return 'SB 4200TL'
  elseif value == 9036 then
    return 'SB 4200TL HC'
  elseif value == 9037 then
    return 'SB 5000TL'
  elseif value == 9038 then
    return 'SB 5000TLW'
  elseif value == 9039 then
    return 'SB 5000TL HC'
  elseif value == 9066 then
    return 'SB 1200'
  elseif value == 9074 then
    return 'SB 3000TL-21'
  elseif value == 9075 then
    return 'SB 4000TL-21'
  elseif value == 9076 then
    return 'SB 5000TL-21'
  elseif value == 9086 then
    return 'SB 3800US-10'
  elseif value == 9104 then
    return 'SB 3000TL-JP-21'
  elseif value == 9105 then
    return 'SB 3500TL-JP-21'
  elseif value == 9106 then
    return 'SB 4000TL-JP-21'
  elseif value == 9107 then
    return 'SB 4500TL-JP-21'
  elseif value == 9109 then
    return 'SB 1600TL-10'
  elseif value == 9160 then
    return 'SB 3600TL-20'
  elseif value == 9162 then
    return 'SB 3500TL-JP-22'
  elseif value == 9164 then
    return 'SB 4500TL-JP-22'
  elseif value == 9165 then
    return 'SB 3600TL-21'
  elseif value == 9177 then
    return 'SB 240-10'
  elseif value == 9183 then
    return 'SB 2000TLST-21'
  elseif value == 9184 then
    return 'SB 2500TLST-21'
  elseif value == 9185 then
    return 'SB 3000TLST-21'
  elseif value == 9198 then
    return 'SB 3000TL-US-22'
  elseif value == 9199 then
    return 'SB 3800TL-US-22'
  elseif value == 9200 then
    return 'SB 4000TL-US-22'
  elseif value == 9201 then
    return 'SB 5000TL-US-22'
  elseif value == 9225 then
    return 'SB 5000SE-10'
  elseif value == 9226 then
    return 'SB 3600SE-10'
  elseif value == 9274 then
    return 'SB 6000TL-US-22'
  elseif value == 9275 then
    return 'SB 7000TL-US-22'
  elseif value == 9293 then
    return 'SB 7700TL-US-22'
  else
    enapter.log('Cannot decode model: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function parse_health_status(value)
  if not value then
    return
  end

  if value == 35 then
    return 'fault'
  elseif value == 303 then
    return nil
  elseif value == 307 then
    return 'ok'
  elseif value == 455 then
    return 'warning'
  else
    enapter.log('Cannot decode status: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function parse_recom_action(value)
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
  elseif value == 569 then
    return 'operating'
  else
    enapter.log('Cannot decode operating status: ' .. tostring(value), 'error')
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
