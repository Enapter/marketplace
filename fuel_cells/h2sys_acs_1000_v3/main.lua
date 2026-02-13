-- H2SYS AIRCELL ACS 1000 — Air Cooled Hydrogen Fuel Cell System
-- Communication: CAN bus 500 kbps
--
-- CAN messages received from device:
--   0x666 — fault/warning bitfields: byte0 (error/warning flags), byte1 (error flags), byte2 (error flags)
--   0x090 — voltage (bytes 0-1, uint16 BE), current (bytes 2-3, uint16 BE)
--   0x091 — temperature (byte 0), internal H2 pressure (byte 4), state (byte 5)
--
-- CAN messages sent to device:
--   0x001 — start: [1,0,0,0,0,0,0,0]  stop: [0,1,0,0,0,0,0,0]

local client = nil
local conn_cfg = nil
local monitor = nil

function enapter.main()
  reconnect()
  configuration.after_write('connection', function()
    client = nil
    conn_cfg = nil
    monitor = nil
  end)
  scheduler.add(1000, reconnect)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('start', cmd_start)
  enapter.register_command_handler('stop', cmd_stop)
end

function reconnect()
  if client then
    return
  end

  if not configuration.is_all_required_set('connection') then
    return
  end

  local config, err = configuration.read('connection')
  if err ~= nil then
    enapter.log('read configuration: ' .. err, 'error')
    return
  end
  conn_cfg = config

  local cl, cl_err = can.new(conn_cfg.conn_str)
  if not cl then
    enapter.log('connect: client creation failed: ' .. cl_err, 'error')
    return
  end

  local mon, mon_err = cl:monitor({ 0x666, 0x090, 0x091 })
  if not mon then
    enapter.log('connect: monitor creation failed: ' .. mon_err, 'error')
    return
  end

  client = cl
  monitor = mon
end

function send_properties()
  enapter.send_properties({ vendor = 'H2SYS', model = 'ACS 1000' })
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', conn_alerts = { 'not_configured' } })
    return
  end

  if not monitor then
    enapter.send_telemetry({ status = 'conn_error', conn_alerts = { 'communication_failed' } })
    return
  end

  local data, err = monitor:pop({ 0x666, 0x090, 0x091 })
  if err then
    enapter.log('monitor pop: ' .. err, 'error')
    client = nil
    monitor = nil
    enapter.send_telemetry({ status = 'conn_error', conn_alerts = { 'communication_failed' } })
    return
  end

  local telemetry = { conn_alerts = {} }
  local alerts = {}
  local status = 'ok'

  -- 0x666: fault/warning bitfields
  if data[1] then
    local byte0, byte1, byte2 = string.unpack('I1I1I1', data[1])

    -- byte0 errors
    if byte0 & 0x01 ~= 0 then
      table.insert(alerts, 'low_cell_voltage')
    end
    if byte0 & 0x02 ~= 0 then
      table.insert(alerts, 'fuel_cell_high_temperature')
    end
    if byte0 & 0x04 ~= 0 then
      table.insert(alerts, 'fuel_cell_low_voltage')
    end
    if byte0 & 0x08 ~= 0 then
      table.insert(alerts, 'low_h2_pressure')
    end
    if byte0 & 0x10 ~= 0 then
      table.insert(alerts, 'auxilary_voltage')
    end
    if byte0 & 0x80 ~= 0 then
      table.insert(alerts, 'start_phase_error')
    end

    -- byte1 errors
    if byte1 & 0x01 ~= 0 then
      table.insert(alerts, 'fccc_board')
    end
    if byte1 & 0x02 ~= 0 then
      table.insert(alerts, 'can_fail')
    end
    if byte1 & 0x04 ~= 0 then
      table.insert(alerts, 'fuel_cell_current')
    end
    if byte1 & 0x10 ~= 0 then
      table.insert(alerts, 'fan_error')
    end
    if byte1 & 0x20 ~= 0 then
      table.insert(alerts, 'h2_leakage')
    end
    if byte1 & 0x40 ~= 0 then
      table.insert(alerts, 'low_internal_pressure')
    end
    if byte1 & 0x80 ~= 0 then
      table.insert(alerts, 'high_internal_pressure')
    end

    -- byte2 errors
    if byte2 & 0x01 ~= 0 then
      table.insert(alerts, 'fuel_cell_temperature_variation')
    end

    if #alerts > 0 then
      status = 'error'
    end

    -- byte0 warnings
    if byte0 & 0x20 ~= 0 then
      table.insert(alerts, 'fcvm_board')
    end
    if byte0 & 0x40 ~= 0 then
      table.insert(alerts, 'idle_state')
    end
  end

  -- 0x090: voltage + current
  if data[2] then
    local raw_v, raw_i = string.unpack('>I2>I2', data[2])
    telemetry.voltage = 0.0216 * raw_v
    telemetry.current = (raw_i - 2048) * 0.06105
  end

  -- 0x091: temperature, internal H2 pressure, state
  if data[3] then
    local b0, _, _, _, b4, b5 = string.unpack('I1I1I1I1I1I1', data[3])
    telemetry.temperature = sign_magnitude(b0)
    telemetry.internal_h2_pressure = sign_magnitude(b4) / 10.0
    status = parse_state(b5)
  end

  telemetry.status = status
  telemetry.alerts = alerts
  enapter.send_telemetry(telemetry)
end

-- Commands

function cmd_start(ctx)
  if not client then
    reconnect()
  end
  if not client then
    ctx.error('Device connection not initialized')
    return
  end
  local err = client:send(0x001, string.pack('BBBBBBBB', 1, 0, 0, 0, 0, 0, 0, 0))
  if err then
    ctx.error('CAN send failed: ' .. err)
  else
    ctx.log('Start command sent')
  end
end

function cmd_stop(ctx)
  if not client then
    reconnect()
  end
  if not client then
    ctx.error('Device connection not initialized')
    return
  end
  local err = client:send(0x001, string.pack('BBBBBBBB', 0, 1, 0, 0, 0, 0, 0, 0))
  if err then
    ctx.error('CAN send failed: ' .. err)
  else
    ctx.log('Stop command sent')
  end
end

-- Helpers

-- Decode 7-bit sign-magnitude: bit7 = sign flag, bits 0-6 = magnitude
function sign_magnitude(byte)
  local magnitude = byte & 0x7F
  if byte >> 7 == 1 then
    return -magnitude
  end
  return magnitude
end

function parse_state(state)
  if state == 0 then
    return 'auto_check'
  elseif state == 1 then
    return 'h2_inlet_pressure'
  elseif state == 10 then
    return 'waiting'
  elseif state >= 11 and state <= 14 then
    return 'start_up'
  elseif state == 15 then
    return 'idle'
  elseif state == 17 then
    return 'operation'
  elseif state == 21 then
    return 'switch_off'
  elseif state == 22 then
    return 'locked_out'
  end
end
