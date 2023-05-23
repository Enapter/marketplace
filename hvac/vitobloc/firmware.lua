local config = require('enapter.ucm.config')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
ADDRESS_CONFIG = 'address'
UNIT_ID_CONFIG = 'unit_id'

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(2000, send_telemetry)

  config.init({
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [UNIT_ID_CONFIG] = { type = 'number', required = true },
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

  properties['vendor'] = 'Viessman'
  enapter.send_properties(properties)
end

function send_telemetry()
  local vitobloc, err = connect_vitobloc()
  if not vitobloc then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = { 'cannot_read_config' } })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    end
    return
  end

  enapter.send_telemetry({
    status = parse_status(vitobloc:read_u16(5)),
    alerts = {
      table.unpack(parse_start_stop_error(vitobloc:read_u16(100))),
      table.unpack(parse_digital_error(vitobloc:read_u16(132))),
      table.unpack(parse_external_error(vitobloc:read_u16(140))),
      table.unpack(parse_other_error(vitobloc:read_u16(144))),
      table.unpack(parse_operating_states(vitobloc:read_u16(190))),
    },
    ext_power_setpoint = vitobloc:read_i16(7, 0.1),
    int_power_setpoint = vitobloc:read_i16(8, 0.1),
    uptime = vitobloc:read_u32(9),
    number_of_launches = vitobloc:read_i16(12),
    time_till_next_maintenance = vitobloc:read_i16(18),
    time_till_next_repair = vitobloc:read_u32(22),
    kwh_counter = vitobloc:read_u32(26, 0.1),
    t_cooling_water_inlet = vitobloc:read_i16(40, 0.1),
    t_cooling_water_outlet = vitobloc:read_i16(44, 0.1),
    t_engine_oil_tank_A = vitobloc:read_i16(47, 0.1),
    t_engine_oil_tank_B = vitobloc:read_i16(48, 0.1),
    generator_temp = vitobloc:read_i16(49, 0.1),
    battery_voltage = vitobloc:read_i16(64, 0.1),
    oil_pressure = vitobloc:read_i16(65, 0.1),
    grid_voltage_L1 = vitobloc:read_i16(73, 0.1),
    grid_voltage_L2 = vitobloc:read_i16(74, 0.1),
    grid_voltage_L3 = vitobloc:read_i16(75, 0.1),
    generator_voltage_L1 = vitobloc:read_i16(77, 0.1),
    generator_voltage_L2 = vitobloc:read_i16(78, 0.1),
    generator_voltage_L3 = vitobloc:read_i16(79, 0.1),
  })
end

-- holds global Vitobloc connection
local vitobloc

function connect_vitobloc()
  if vitobloc then
    return vitobloc, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local address, unit_id = values[ADDRESS_CONFIG], values[UNIT_ID_CONFIG]
    if not address or not unit_id then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      vitobloc = VitoblocModbusTcp.new(address, unit_id)
      vitobloc:connect()
      return vitobloc, nil
    end
  end
end

function parse_status(value)
  if not value then
    return 'unknown'
  end

  if type(value) == 'number' then
    if value == 0 then
      return 'Off'
    elseif value == 1 then
      return 'Ready'
    elseif value == 2 then
      return 'Start'
    elseif value == 3 then
      return 'Operation'
    elseif value == 4 then
      return 'Error'
    else
      enapter.log('Cannot decode status: ' .. tostring(value), 'error')
      return tostring(value)
    end
  end
end

function parse_operating_states(value)
  if not value then
    return {}
  end
  if value == 0 then
    return { 'unknown_value_operating_states' }
  end
  if type(value) == 'number' then
    local operating_states = {}

    if value & 64 then
      table.insert(operating_states, 'engine_stopped')
    end
    if value & 128 then
      table.insert(operating_states, 'engine_on')
    end
    if value & 256 then
      table.insert(operating_states, 'fan_on')
    end
    if value & 512 then
      table.insert(operating_states, 'cooling_water_pump_on')
    end
    if value & 1024 then
      table.insert(operating_states, 'heating_water_pump_on')
    end
    if value & 4096 then
      table.insert(operating_states, 'ignition_on')
    end
    if value & 8192 then
      table.insert(operating_states, 'gas_valves_open')
    end
    return operating_states
  end
end

function parse_start_stop_error(value)
  if not value then
    return {}
  end
  if value == 0 then
    return { 'unknown_value_start_stop_error' }
  end
  if type(value) == 'number' then
    local stop_start_errors = {}

    if value & 1 then
      table.insert(stop_start_errors, 'no_interference')
    end
    if value & 2 then
      table.insert(stop_start_errors, 'underspeed')
    end
    if value & 32 then
      table.insert(stop_start_errors, 'slow_speed')
    end
    if value & 1024 then
      table.insert(stop_start_errors, 'engine_doesnt_stop')
    end
    return stop_start_errors
  end
end

function parse_digital_error(value)
  if not value then
    return {}
  end
  if value == 0 then
    return { 'unknown_value_digital_error' }
  end
  if type(value) == 'number' then
    local digital_errors = {}

    if value & 8 then
      table.insert(digital_errors, 'gas_pressure_max')
    end
    if value & 16 then
      table.insert(digital_errors, 'gas_pressure_min')
    end
    return digital_errors
  end
end

function parse_external_error(value)
  if not value then
    return {}
  end
  if value == 0 then
    return { 'unknown_value_external_error' }
  end
  if type(value) == 'number' then
    local external_errors = {}

    if value & 1 then
      table.insert(external_errors, 'power_module_generator')
    end
    if value & 2 then
      table.insert(external_errors, 'power_module_reverse')
    end
    return external_errors
  end
end

function parse_other_error(value)
  if not value then
    return {}
  end
  if value == 0 then
    return { 'unknown_value_other_error' }
  end
  if type(value) == 'number' then
    local other_errors = {}

    if value & 1 then
      table.insert(other_errors, 'pump_dry_1')
    end
    if value & 2 then
      table.insert(other_errors, 'pump_dry_2')
    end
    if value & 4 then
      table.insert(other_errors, 'pump_dry')
    end
    return other_errors
  end
end

---------------------------------
-- Vitobloc ModbusTCP API
---------------------------------

VitoblocModbusTcp = {}

function VitoblocModbusTcp.new(ip_address, unit_id)
  assert(
    type(ip_address) == 'string',
    'ip_address (arg #1) must be string, given: ' .. inspect(ip_address)
  )
  assert(type(unit_id) == 'number', 'unit_id (arg #2) must be number, given: ' .. inspect(unit_id))

  local self = setmetatable({}, { __index = VitoblocModbusTcp })
  self.ip_address = ip_address
  self.unit_id = unit_id
  return self
end

function VitoblocModbusTcp:connect()
  self.modbus = modbustcp.new(self.ip_address)
end

function VitoblocModbusTcp:read_holdings(address, registers_count)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(
    type(registers_count) == 'number',
    'refisters_count (arg #2) must be number, given: ' .. inspect(registers_count)
  )

  local registers, err = self.modbus:read_holdings(self.unit_id, address, registers_count, 1000)
  if err and err ~= 0 then
    enapter.log('read error: ' .. err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
    return nil
  end
  return registers
end

function VitoblocModbusTcp:read_u32(address, factor)
  if not factor then
    factor = 1
  end

  local reg = self:read_holdings(address, 2)
  if not reg then
    return
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw) * factor
end

function VitoblocModbusTcp:read_u8(address, factor)
  if not factor then
    factor = 1
  end

  local reg = self:read_holdings(address, 1)
  if not reg then
    return
  end

  -- NaN for U16 values
  if reg[1] == 0xFFFF then
    return nil
  end

  local raw = string.pack('>I2', reg[1])
  return string.unpack('>I2', raw) * factor
end

function VitoblocModbusTcp:read_u16(address, factor)
  if not factor then
    factor = 1
  end

  local reg = self:read_holdings(address, 1)
  if not reg then
    return
  end

  local raw = string.pack('>I2', reg[1])
  return string.unpack('>I2', raw) * factor
end

function VitoblocModbusTcp:read_i16(address, factor)
  if not factor then
    factor = 1
  end

  local reg = self:read_holdings(address, 1)
  if not reg then
    return
  end

  local raw = string.pack('>i2', reg[1])
  return string.unpack('>i2', raw) * factor
end

main()
