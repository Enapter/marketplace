local config = require('enapter.ucm.config')
local sinexcel_modbus = require('sinexcel')

ADDRESS_CONFIG = 'address'
BAUDRATE_CONFIG = 'baudrate'
DATA_BITS_CONFIG = 'data_bits'
STOP_BITS_CONFIG = 'stop_bits'
PARITY_CONFIG = 'parity_bits'

-- global Modbus connection, initialized below
sinexcel = nil

function main()
  local sinexcel, err = connect_sinexcel()
  if not sinexcel then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'communication_error', alerts = { 'cannot_read_config' } })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    end
    return
  end

  scheduler.add(1000, send_realtime_telemetry)
  scheduler.add(30000, send_properties)
  scheduler.add(5000, send_detailed_telemetry)

  config.init({
    [ADDRESS_CONFIG] = { type = 'number', required = true, default = 1 },
    [BAUDRATE_CONFIG] = { type = 'number', required = true, default = 19200 },
    [DATA_BITS_CONFIG] = { type = 'number', required = true, default = 8 },
    [STOP_BITS_CONFIG] = { type = 'number', required = true, default = 1 },
    [PARITY_CONFIG] = { type = 'string', required = true, default = 'N' },
  })
end

function send_properties()
  local properties = {}

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
  else
    for name, val in pairs(values) do
      properties[name] = val
    end
  end

  enapter.send_properties(properties)
end

function send_realtime_telemetry()
  local telemetry = {
    status = parse_status(sinexcel:read_i16(32)),

    output_voltage_a = sinexcel:read_i16(101) / 10,
    output_voltage_b = sinexcel:read_i16(102) / 10,
    output_voltage_c = sinexcel:read_i16(103) / 10,
    grid_current_a = sinexcel:read_i16(104) / 10,
    grid_current_b = sinexcel:read_i16(105) / 10,
    grid_current_c = sinexcel:read_i16(106) / 10,
    grid_frequency = sinexcel:read_i16(107) / 100,
    active_power_a = sinexcel:read_i16(110) / 100,
    active_power_b = sinexcel:read_i16(111) / 100,
    active_power_c = sinexcel:read_i16(112) / 100,
    reactive_power_a = sinexcel:read_i16(113) / 100,
    reactive_power_b = sinexcel:read_i16(114) / 100,
    reactive_power_c = sinexcel:read_i16(115) / 100,

    dc_power = sinexcel:read_i16(141) / 100,
    dc_voltage = sinexcel:read_i16(142) / 10,
    dc_current = sinexcel:read_i16(143) / 10,
  }

  enapter.send_telemetry(telemetry)
end

function send_detailed_telemetry()
  local started = os.clock()
  local telemetry = {
    total_active_power = sinexcel:read_i16(122) / 100,
    total_reactive_power = sinexcel:read_i16(123) / 100,
    total_apparent_power = sinexcel:read_i16(124) / 100,
    total_power_factor = sinexcel:read_i16(125) / 100,
    discharge_energy = sinexcel:read_u32(126) / 100,
    charge_energy = sinexcel:read_u32(128) / 100,
    dc_discharge_energy = sinexcel:read_u32(144) / 10,
    dc_charge_energy = sinexcel:read_u32(146) / 10,
  }
  telemetry.read_time = math.ceil((os.clock() - started) * 1000) / 1000 -- round

  enapter.send_telemetry(telemetry)
end

function connect_sinexcel()
  if sinexcel then
    return sinexcel, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    for _, value in pairs(values) do
      if not value then
        return nil, 'not_configured'
      end
    end

    sinexcel = sinexcel_modbus.new(
      tonumber(values[ADDRESS_CONFIG]),
      tonumber(values[BAUDRATE_CONFIG]),
      tonumber(values[DATA_BITS_CONFIG]),
      values[PARITY_CONFIG],
      tonumber(values[STOP_BITS_CONFIG])
    )

    -- Declare global variable to reuse connection between function calls
    sinexcel:connect()
    return sinexcel, nil
  end
end

function parse_status(value)
  if not value then
    return
  end

  if value & (1 << 0) ~= 0 then
    return 'fault'
  elseif value & (1 << 1) ~= 0 then
    return 'alert'
  elseif value & (1 << 2) ~= 0 then
    return 'on-off'
  elseif value & (1 << 3) ~= 0 then
    return 'grid-tied'
  elseif value & (1 << 4) ~= 0 then
    return 'off-grid'
  elseif value & (1 << 5) ~= 0 then
    return 'derating'
  elseif value & (1 << 6) ~= 0 then
    return 'allow_grid_connection_judgement'
  elseif value & (1 << 7) ~= 0 then
    return 'standby'
  else
    enapter.log('Cannot decode status: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

main()
