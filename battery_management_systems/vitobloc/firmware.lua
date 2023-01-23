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
    [UNIT_ID_CONFIG] = { type = 'number', required = true }
  })
end

function send_properties()
  local properties = {}

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


function send_telemetry()
  local vitobloc, err = connect_vitobloc()
  if not vitobloc then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = {'cannot_read_config'} })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = {'not_configured'} })
    end
    return
  end

  --status = uint16(5)
  -- External_power_setpoint = int16(7) kW
    --Internal_power_setpoint = int16(8) kW
    --uptime = uint32(9-10) h
    -- number_of_launches = uint16 (12)
    -- h_until_next_maintenance = int16 (18) h
    -- next_repair = unit32(22-23) h
    --time_until_next_repair = int32(24) h
    --kwh_counter = unit32(26)
    -- cooling_water_t_inlet = int16(40) °C
    -- cooling_water_t_outlet = int16(41) °C
    --engine_oil_t_bank_A = int16(47) °C
    --engine_oil_t_bank_B = int16(48) °C
    -- generator_t = int16(49)
    --battery_voltage = int16(64) V
    -- oil_pressure = int16(65)
    -- grid_voltage_L1 = int16(73)
    -- grid_voltage_L2 = int16(74)
    -- grid_voltage_L3 = int16(75)
    -- generator_voltage_L1 = int16(77)
    -- generator_voltage_L2 = int16(78)
    -- generator_voltage_L3 = int16(79)
    -- start_stop_error = uint8[4](100-101)
    -- digital_errors = uint8[16](132-139)
    --external_errors = uint8[8](140-143)
    --other_errors = unit8[4](144-145)
    --operating_states = uint8[4](190-191)

  enapter.send_telemetry({

    status= parse_status(vitobloc:read_u16(5)),
    alerts = parse_start_stop_error(vitobloc:read_u8(100)),
    start_stop_errors = parse_start_stop_error(vitobloc:read_u8(100)),
    operating_states = parse_operating_states(vitobloc:read_u8(190)),
    digital_errors = parse_digital_error(vitobloc:read_u8(132)),
    external_errors = parse_external_error(vitobloc:read_u8(140)),
    other_errors = parse_other_error(vitobloc:read_u8(144)),
    ext_power_setpoint = vitobloc:read_i16(7),
    int_power_setpoint = vitobloc:read_i16(8),
    uptime = vitobloc:read_u32(9),
    number_of_launches = vitobloc:read_i16(12),
    time_till_next_maintenance = vitobloc:read_i16(18),
    time_till_next_repair = vitobloc:read_u32(22),
    kwh_counter = vitobloc:read_u32(26),
    t_cooling_water_inlet = vitobloc:read_i16(40),
    t_cooling_water_outlet = vitobloc:read_i16(48),
    t_engine_oil_tank_A = vitobloc:read_i16(47),
    t_engine_oil_tank_B = vitobloc:read_i16(48),
    generator_temp = vitobloc:read_i16(49),
    battery_voltage = vitobloc:read_i16(64),
    oil_pressure = vitobloc:read_i16(65),
    grid_voltage_L1 = vitobloc:read_i16(73),
    grid_voltage_L2 = vitobloc:read_i16(74),
    grid_voltage_L3 = vitobloc:read_i16(75),
    generator_voltage_L1 = vitobloc:read_i16(77),
    generator_voltage_L2 = vitobloc:read_i16(78),
    generator_voltage_L3 = vitobloc:read_i16(79)
  })
end

-- holds global Vitobloc connection
local vitobloc

function connect_vitobloc()
  if vitobloc then return vitobloc, nil end

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
        vitobloc = VitoblocModbusTcp.new(address, unit_id)
        vitobloc:connect()
      return vitobloc, nil
    end
  end
end





function parse_status(value)
  -- 0: Aus
  -- 1: Bereit
  -- 2: Start
  -- 3: Betrieb
  -- 4: Störung -- I'd say this is error

  if not value then return {} end
  local status = {}

  if value & 1 then table.insert(status, 'Off') end
  if value & 2 then table.insert(status,'Ready') end
  if value & 4 then table.insert(status, 'Start') end
  if value & 8 then table.insert(status, 'Operation') end
  if value & 16 then table.insert(status, 'Error')
  else
    enapter.log('Cannot decode status: '..tostring(value), 'error')
    return tostring(value)
    end
  end



function parse_operating_states(value)

  if not value then return {} end
  local operating_states = {}

    if value & 64 then table.insert(operating_states,'Engine stopped')
    if value & 128  then table.insert(operating_states, 'Engine switch ON')
    if value & 256 then table.insert(operating_states,'Fan ON')
    if value & 512 then table.insert(operating_states,'Cooling Water Pump ON')
    if value & 1024 then table.insert(operating_states, 'Heating water pump ON')
    if value & 4096 then table.insert(operating_states,'Ignition ON')
    if value & 8192 then table.insert(operating_states, 'Gas valves OPEN')
      else
        enapter.log('Cannot decode status: '..tostring(value), 'error')
        return tostring(value)
        end
      end
    end
  end
end
end
end
end


function parse_start_stop_error(value)
  if not value then return {} end

  local stop_start_errors = {}
    if value & 1 then table.insert(stop_start_errors,'No Interference')
    if value & 2 then table.insert(stop_start_errors,'Underspeed')
    if value & 32 then table.insert(stop_start_errors,'Speed < 50 rpm')
    if value & 1024 then table.insert(stop_start_errors, "Engine Doesn't Stop")
      else
        enapter.log('Cannot decode error: '..tostring(value), 'error')
          return tostring(value)
        end
      end
    end
  end
  return stop_start_errors
end

function parse_digital_error(value)
  if not value then return {} end

  local digital_errors = {}
    if value & 8 then table.insert(digital_errors, "Gas pressure max")
    if value & 16 then table.insert(digital_errors, 'Gas pressure min')
      else
        enapter.log('Cannot decode digital error: '..tostring(value), 'error')
        return tostring(value)
      end
    end
  return digital_errors
end

function parse_external_error(value)
  if not value then return {} end

  local external_errors = {}
    if value & 1 then table.insert(external_errors, "Power module generator contactor stuck")
    if value & 2 then table.insert(external_errors, 'Power module reverse power')
      else
        enapter.log('Cannot decode external error: '..tostring(value), 'error')
        return tostring(value)
      end
    end
  return external_errors
end


function parse_other_error(value)
  if not value then return {} end

  local other_errors = {}
    if value & 1 then table.insert(other_errors, "Pump dry running protection 1")
    if value & 2 then table.insert(other_errors, 'Pump dry running protection 2')
    if value & 4 then table.insert(other_errors,'Pump dry run protection')
      else
        enapter.log('Cannot decode other error: '..tostring(value), 'error')
          return tostring(value)
        end
      end
    end
  return other_errors
end


---------------------------------
-- Stored Configuration API
---------------------------------

config = {}

-- Initializes config options. Registers required UCM commands.
-- @param options: key-value pairs with option name and option params
-- @example
--   config.init({
--     address = { type = 'string', required = true },
--     unit_id = { type = 'number', default = 1 },
--     reconnect = { type = 'boolean', required = true }
--   })
function config.init(options)
  assert(next(options) ~= nil, 'at least one config option should be provided')
  assert(not config.initialized, 'config can be initialized only once')
  for name, params in pairs(options) do
    local type_ok = params.type == 'string' or params.type == 'number' or params.type == 'boolean'
    assert(type_ok, 'type of `'..name..'` option should be either string or number or boolean')
  end

  enapter.register_command_handler('write_configuration', config.build_write_configuration_command(options))
  enapter.register_command_handler('read_configuration', config.build_read_configuration_command(options))

  config.options = options
  config.initialized = true
end

-- Reads all initialized config options
-- @return table: key-value pairs
-- @return nil|error
function config.read_all()
  local result = {}

  for name, _ in pairs(config.options) do
    local value, err = config.read(name)
    if err then
      return nil, 'cannot read `'..name..'`: '..err
    else
      result[name] = value
    end
  end

  return result, nil
end

-- @param name string: option name to read
-- @return string
-- @return nil|error
function config.read(name)
  local params = config.options[name]
  assert(params, 'undeclared config option: `'..name..'`, declare with config.init')

  local ok, value, ret = pcall(function()
    return storage.read(name)
  end)

  if not ok then
    return nil, 'error reading from storage: '..tostring(value)
  elseif ret and ret ~= 0 then
    return nil, 'error reading from storage: '..storage.err_to_str(ret)
  elseif value then
    return config.deserialize(name, value), nil
  else
    return params.default, nil
  end
end

-- @param name string: option name to write
-- @param val string: value to write
-- @return nil|error
function config.write(name, val)
  local ok, ret = pcall(function()
    return storage.write(name, config.serialize(name, val))
  end)

  if not ok then
    return 'error writing to storage: '..tostring(ret)
  elseif ret and ret ~= 0 then
    return 'error writing to storage: '..storage.err_to_str(ret)
  end
end

-- Serializes value into string for storage
function config.serialize(_, value)
  if value then
    return tostring(value)
  else
    return nil
  end
end

-- Deserializes value from stored string
function config.deserialize(name, value)
  local params = config.options[name]
  assert(params, 'undeclared config option: `'..name..'`, declare with config.init')

  if params.type == 'number' then
    return tonumber(value)
  elseif params.type == 'string' then
    return value
  elseif params.type == 'boolean' then
    if value == 'true' then
      return true
  elseif value == 'false' then
      return false
    else
      return nil
    end
  end
end

function config.build_write_configuration_command(options)
  return function(ctx, args)
    for name, params in pairs(options) do
      if params.required then
        assert(args[name], '`'..name..'` argument required')
      end

      local err = config.write(name, args[name])
      if err then ctx.error('cannot write `'..name..'`: '..err) end
    end
  end
end

function config.build_read_configuration_command(_config_options)
  return function(ctx)
    local result, err = config.read_all()
    if err then
      ctx.error(err)
    else
      return result
    end
  end
end

---------------------------------
-- Vitobloc ModbusTCP API
---------------------------------

VitoblocModbusTcp = {}

function VitoblocModbusTcp.new(addr, unit_id)
  assert(type(addr) == 'string', 'addr (arg #1) must be string, given: '..inspect(addr))
  assert(type(unit_id) == 'number', 'unit_id (arg #2) must be number, given: '..inspect(unit_id))

  local self = setmetatable({}, { __index = SmaModbusTcp })
  self.addr = addr
  self.unit_id = unit_id
  return self
end

function VitoblocModbusTcp:connect()
  self.modbus = modbustcp.new(self.addr)
end

function VitoblocModbusTcp:read_holdings(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: '..inspect(address))
  assert(type(number) == 'number', 'number (arg #1) must be number, given: '..inspect(number))

  local registers, err = self.modbus:read_holdings(self.unit_id, address, number, 1000)
  if err and err ~= 0 then
    enapter.log('read error: '..err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
    return nil
  end

  return registers
end

function VitoblocModbusTcp:read_u32(address)
  local reg = self:read_holdings(address, 2)
  if not reg then return end

  -- NaN for U32 values
  if reg[1] == 0xFFFF and reg[2] == 0xFFFF then
    return nil
  end

  -- NaN for ENUM values
  if reg[1] == 0x00FF and reg[2] == 0xFFFD then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw)
end


function VitoblocModbusTcp:read_u32_enum(address)
  return self:read_u32(address)
end


function VitoblocModbusTcp:read_u8(address)
  local reg = self:read_holdings(address, 1)
  if not reg then return end

  -- NaN for U16 values
  if reg[1] == 0xFFFF then
    return nil
  end

  -- NaN for ENUM values
  if reg[1] == 0x00FF then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw)
end

function VitoblocModbusTcp:read_u8_enum(address)
  return self:read_u32(address)
end


function VitoblocModbusTcp:read_u16(address)
  local reg = self:read_holdings(address, 1)
  if not reg then return end

  -- NaN for U16 values
  if reg[1] == 0xFFFF and reg[2] == 0xFFFF then
    return nil
  end

  -- NaN for ENUM values
  if reg[1] == 0x00FF and reg[2] == 0xFFFD then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw)
end


function VitoblocModbusTcp:read_u16_enum(address)
  return self:read_u32(address)
end


function VitoblocModbusTcp:read_i16(address)
  local reg = self:read_holdings(address, 1)
  if not reg then return end

  -- NaN for ENUM values
  if reg[1] == 0x00FF and reg[2] == 0xFFFD then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw)
end


function VitoblocModbusTcp:read_i16_enum(address)
  return self:read_u32(address)
end



function VitoblocModbusTcp:read_i32(address)
  local reg = self:read_holdings(address, 1)
  if not reg then return end

  -- NaN for ENUM values
  if reg[1] == 0x00FF and reg[2] == 0xFFFD then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw)
end


function VitoblocModbusTcp:read_i32_enum(address)
  return self:read_u32(address)
end




main()