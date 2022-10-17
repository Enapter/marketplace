local config = require('enapter.ucm.config')
local smamodbus = require('enapter.sma.modbustcp')

ADDRESS_CONFIG = 'address'
UNIT_ID_CONFIG = 'unit_id'

-- global SMA Modbus TCP connection, initialized below
sma = nil

function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_realtime_telemetry)
  scheduler.add(5000, send_detailed_telemetry)

  config.init({
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [UNIT_ID_CONFIG] = { type = 'number', required = true }
  })
end

function send_properties()
  local properties = {}

  local sma, _ = connect_sma()
  if sma then
    properties.model = parse_model(sma:read_u32_enum(30053))
    properties.serial_num = sma:read_u32_fix0(30057)
    properties.fw_ver = parse_firmware_version(sma:read_u32_fix0(30059))
    properties.rated_power_va = sma:read_u32_fix0(40185)
    properties.country_code = parse_country_code(sma:read_u32_fix0(40109))
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    for name, val in pairs(values) do
      properties[name] = val
    end
  end

  enapter.send_properties(properties)
end

function send_realtime_telemetry()
  local sma, err = connect_sma()
  if not sma then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = {'cannot_read_config'} })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = {'not_configured'} })
    end
    return
  end

  local started = os.clock()
  local telemetry = {
    alerts = parse_alerts(
      sma:read_u32_enum(30213),
      sma:read_u32_enum(30247)
    ),

    status = parse_status(sma:read_u32_enum(30201)),
    operation_status = parse_operation_status(sma:read_u32_enum(40029)),

    dc_voltage = sma:read_s32_fix2(30771),
    dc_power = sma:read_s32_fix0(30773),

    ac_power = sma:read_s32_fix0(30775),
    ac_frequency = sma:read_u32_fix2(30803),
  }
  telemetry.read_time = math.ceil((os.clock() - started) * 1000) / 1000 -- round

  enapter.send_telemetry(telemetry)
end

function send_detailed_telemetry()
  local sma = connect_sma()
  if not sma then return end -- send_realtime_telemetry reports alert

  local started = os.clock()
  local telemetry = {
    recommended_action = parse_recom_action(sma:read_u32_enum(30211)),
    derating_reason = parse_derating_reason(sma:read_u32_enum(30219)),
    grid_relay_closed = parse_grid_relay_closed(sma:read_u32_enum(30217)),

    dc_amperage = sma:read_s32_fix3(30769),

    ac_power_var = sma:read_s32_fix0(30805),
    ac_power_va = sma:read_s32_fix0(30813),
    ac_cos_phi = sma:read_u32_fix3(30949),

    ac_p1_power = sma:read_s32_fix0(30777),
    ac_p2_power = sma:read_s32_fix0(30779),
    ac_p3_power = sma:read_s32_fix0(30781),
    ac_p1_voltage = sma:read_u32_fix2(30783),
    ac_p2_voltage = sma:read_u32_fix2(30785),
    ac_p3_voltage = sma:read_u32_fix2(30787),
    ac_p1_power_var = sma:read_s32_fix0(30807),
    ac_p2_power_var = sma:read_s32_fix0(30809),
    ac_p3_power_var = sma:read_s32_fix0(30811),

    residual_amperage = sma:read_s32_fix3(31247),
    internal_temperature = sma:read_s32_fix1(34113),

    total_yield = sma:read_u32_fix0(30529),
    daily_yield = sma:read_u32_fix0(30535)
  }
  telemetry.read_time = math.ceil((os.clock() - started) * 1000) / 1000 -- round

  enapter.send_telemetry(telemetry)
end

function connect_sma()
  if sma then return sma, nil end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local address, unit_id = values[ADDRESS_CONFIG], values[UNIT_ID_CONFIG]
    if not address or not unit_id then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      sma = smamodbus.new(address, tonumber(unit_id))
      sma:connect()
      return sma, nil
    end
  end
end

function parse_model(value)
  if not value then return end

  if value == 19048 then return 'STP5.0-3SE-40'
  elseif value == 19049 then return 'STP6.0-3SE-40'
  elseif value == 19050 then return 'STP8.0-3SE-40'
  elseif value == 19051 then return 'STP10.0-3SE-40'
  elseif value == 9284 then return 'STP 20000TL-30'
  elseif value == 9285 then return 'STP 25000TL-30'
  elseif value == 9336 then return 'STP 15000TL-30'
  elseif value == 9337 then return 'STP 17000TL-30'
  elseif value == 9338 then return 'STP50-40'
  elseif value == 9339 then return 'STP50-US-40'
  elseif value == 9340 then return 'STP50-JP-40'
  elseif value == 9344 then return 'STP4.0-3AV-40'
  elseif value == 9345 then return 'STP5.0-3AV-40'
  elseif value == 9346 then return 'STP6.0-3AV-40'
  elseif value == 9347 then return 'STP8.0-3AV-40'
  elseif value == 9348 then return 'STP10.0-3AV-40'
  elseif value == 9366 then return 'STP3.0-3AV-40'
  elseif value == 9428 then return 'STP62-US-41'
  elseif value == 9429 then return 'STP50-US-41'
  elseif value == 9430 then return 'STP33-US-41'
  elseif value == 9431 then return 'STP50-41'
  elseif value == 9432 then return 'STP50-JP-41'
  -- archive models
  elseif value == 9067 then return 'STP 10000TL-10'
  elseif value == 9068 then return 'STP 12000TL-10'
  elseif value == 9069 then return 'STP 15000TL-10'
  elseif value == 9070 then return 'STP 17000TL-10'
  elseif value == 9098 then return 'STP 5000TL-20'
  elseif value == 9099 then return 'STP 6000TL-20'
  elseif value == 9100 then return 'STP 7000TL-20'
  elseif value == 9101 then return 'STP 8000TL-10'
  elseif value == 9102 then return 'STP 9000TL-20'
  elseif value == 9103 then return 'STP 8000TL-20'
  elseif value == 9131 then return 'STP 20000TL-10'
  elseif value == 9139 then return 'STP 20000TLHE-10'
  elseif value == 9140 then return 'STP 15000TLHE-10'
  elseif value == 9181 then return 'STP 20000TLEE-10'
  elseif value == 9182 then return 'STP 15000TLEE-10'
  elseif value == 9281 then return 'STP 10000TL-20'
  elseif value == 9282 then return 'STP 11000TL-20'
  elseif value == 9283 then return 'STP 12000TL-20'
  else
    enapter.log('Cannot decode model: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_status(value)
  if not value then return end

  if value == 35 then return 'fault'
  elseif value == 303 then return 'off'
  elseif value == 307 then return 'ok'
  elseif value == 455 then return 'warning'
  else
    enapter.log('Cannot decode status: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_recom_action(value)
  if not value then return end

  if value == 336 then return 'contact_manufacturer'
  elseif value == 337 then return 'contact_installer'
  elseif value == 338 or value == 887 then return 'ok'
  else
    enapter.log('Cannot decode recommended action: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_grid_relay_closed(value)
  if not value then return end

  if value == 51 then return true -- closed
  elseif value == 311 then return false -- open
  else
    enapter.log('Cannot decode grid relay status: '..tostring(value), 'error')
    return
  end
end

function parse_operation_status(value)
  if not value then return end

  if value == 1295 then return 'standby'
  elseif value == 1392 then return 'fault'
  elseif value == 1393 then return 'waiting_pv_voltage'
  elseif value == 1467 then return 'start'
  elseif value == 1469 then return 'shutdown'
  elseif value == 1480 then return 'waiting_utilities'
  elseif value == 1795 then return 'bolted'
  elseif value == 1855 then return 'standalone'
  elseif value == 2119 then return 'derating'
  elseif value == 295 then return 'mpp'
  elseif value == 303 then return 'off'
  elseif value == 381 then return 'stop'
  elseif value == 443 then return 'const_voltage'
  elseif value == 455 then return 'warning'
  elseif value == 569 then return 'run'
  else
    enapter.log('Cannot decode operation status: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_alerts(presence, message)
  if not presence and not message then return end

  if presence == 886 or presence == 302 then
    return {}
  elseif message then
    return {"e"..tostring(message)}
  else
    return {"unknown_event"}
  end
end

function parse_firmware_version(value)
  if not value then return end

  local release_id = value & 0xFF
  local build = (value >> 8) & 0xFF
  local minor = (value >> 16) & 0xFF
  local major = (value >> 24) & 0xFF

  local release
  if release_id == 0 then release = 'N'
  elseif release_id == 1 then release = 'E'
  elseif release_id == 2 then release = 'A'
  elseif release_id == 3 then release = 'B'
  elseif release_id == 4 then release = 'R'
  elseif release_id == 4 then release = 'S'
  else release = tostring(release_id)
  end

  return major..'.'..minor..'.'..build..'.'..release
end

function parse_derating_reason(value)
  if not value then return end

  if value == 1705 then return 'frequency_deviation'
  elseif value == 3520 then return 'voltage_deviation'
  elseif value == 3554 then return 'reactive_power_priority'
  elseif value == 3556 then return 'high_dc_voltage'
  elseif value == 4560 then return 'external_setting'
  elseif value == 4561 then return 'external_setting_2'
  elseif value == 557 then return 'overtemperature'
  elseif value == 884 then return 'ok'
  else
    enapter.log('Cannot decode derating reason: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_country_code(value)
  if not value then return end

  if value == 1199 then return 'PPDS'
  elseif value == 27 then return 'Adj'
  elseif value == 306 then return 'Off-Grid60'
  elseif value == 313 then return 'Off-Grid50'
  elseif value == 333 then return 'PPC'
  elseif value == 42 then return 'AS4777.3'
  elseif value == 438 then return 'VDE0126-1-1'
  elseif value == 7504 then return 'SI4777-2'
  elseif value == 7508 then return 'JP50'
  elseif value == 7509 then return 'JP60'
  elseif value == 7510 then return 'VDE-AR-N4105'
  elseif value == 7513 then return 'VDE-AR-N4105-MP'
  elseif value == 7514 then return 'VDE-AR-N4105-HP'
  elseif value == 7517 then return 'CEI0-21Int'
  elseif value == 7518 then return 'CEI0-21Ext'
  elseif value == 7523 then return 'C10/11/2012'
  elseif value == 7525 then return 'G83/2'
  elseif value == 7527 then return 'VFR2014'
  elseif value == 7528 then return 'G59/3'
  elseif value == 7530 then return 'MEA2013'
  elseif value == 7531 then return 'PEA2013'
  elseif value == 7532 then return 'EN50438_2013'
  elseif value == 7533 then return 'NEN-EN50438_13'
  elseif value == 7535 then return 'WorstCase'
  elseif value == 7536 then return 'DftEN'
  elseif value == 7538 then return 'SI4777_HS131_13'
  elseif value == 7539 then return 'RD1699/413'
  elseif value == 7549 then return 'AS4777.2_2015'
  elseif value == 7550 then return 'NRS97-2-1'
  elseif value == 7551 then return 'NT_Ley2057'
  elseif value == 7556 then return 'MEA2016'
  elseif value == 7557 then return 'PEA2016'
  elseif value == 7559 then return 'UL1741/2016/120'
  elseif value == 7560 then return 'UL1741/2016/240'
  elseif value == 7561 then return 'UL1741/2016/208'
  elseif value == 7562 then return 'HECO2017/120'
  elseif value == 7563 then return 'HECO2017/208'
  elseif value == 7564 then return 'HECO2017/240'
  elseif value == 7565 then return 'ABNT_NBR_16149_2013'
  elseif value == 7566 then return 'IE-EN50438_2013'
  elseif value == 7567 then return 'DEWA_2016_intern'
  elseif value == 7568 then return 'DEWA_2016_extern'
  elseif value == 7569 then return 'TOR_D4_2016'
  elseif value == 7573 then return 'G83/2-1_2018'
  elseif value == 7574 then return 'G59/3-4_2018'
  elseif value == 7584 then return 'VDEARN4105/18a'
  elseif value == 7586 then return 'VDEARN4105/18c'
  elseif value == 7590 then return 'EN50549-1/18'
  elseif value == 7592 then return 'DftSMA/19'
  elseif value == 7594 then return 'ENA-G98/1/18'
  elseif value == 7595 then return 'ENA-G99/1/18'
  elseif value == 7599 then return 'DK1-West/19'
  elseif value == 7600 then return 'DK2-East/19'
  elseif value == 7602 then return 'BE-C10/11/19-09 PV_a'
  elseif value == 7603 then return 'BE-C10/11/19-09 PV_b'
  elseif value == 7610 then return 'IT-CEI0-21/19_a'
  elseif value == 7612 then return 'IT-CEI0-21/19_c'
  elseif value == 7615 then return 'AT-TOR-Erzeuger-A/19_b'
  else
    enapter.log('Cannot decode country code: '..tostring(value), 'error')
    return
  end
end

main()
