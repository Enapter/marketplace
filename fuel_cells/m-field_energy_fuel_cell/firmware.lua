DEVICE_ID_CONFIG = "device_id"

-- RS485 communication interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS-485 failed: " .. result .. " " .. rs485.err_to_str(result), "error", true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [DEVICE_ID_CONFIG] = { type = 'string', required = true, default = '24' }
  })
end

function send_properties()
  local properties = {
    vendor = "M-Field",
    model = "MF-UEH"
  }

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    properties[DEVICE_ID_CONFIG] = values[DEVICE_ID_CONFIG]
  end

  enapter.send_properties(properties)
end

function send_telemetry()
  local telemetry = {}
  local status = "ok"
  -- local CACHE_LIFE_S = 2

  local raw_data, err = m_field:get_data()

  if not raw_data then
    enapter.log("RS485 receiving data failed: " .. err, "error", true)
    enapter.send_telemetry({status = 'no_data'})
    return
  else
    local volt = string.unpack("<I2", raw_data:sub(9, 10)) / 100
    local current = string.unpack("<I2", raw_data:sub(11, 12)) / 100
    telemetry["output_volt"] = volt
    telemetry["output_current"] = current
    telemetry["output_power"] = volt * current
    telemetry["hydrogen_inlet_pressure"] = (string.unpack("<I2", raw_data:sub(13, 14)) - 1000) / 4000 * 10
    telemetry["battery_volt"] = string.unpack("<I2", raw_data:sub(19, 20)) / 100
    telemetry["battery_current"] = string.unpack("<I2", raw_data:sub(21, 22)) / 100
    telemetry["system_temperature1"] = string.unpack("<i2", raw_data:sub(23, 24)) / 100
    telemetry["system_temperature2"] = string.unpack("<i2", raw_data:sub(25, 26)) / 100
  end

  telemetry["status"] = status
  enapter.send_telemetry(telemetry)
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
-- Communication API
---------------------------------

m_field = {}

-- function m_field:run_with_cache(timeout)
--     local dummy_name = 'all_data'
--     if m_field:is_in_cache(timeout) then
--         local data, err = m_field:get_data()
--         if data then
--             -- we have only once command here
--             m_field:add_to_cache(dummy_name, data, os.time())
--             return data, err
--         end
--     else
--         local result, data = m_field:read_cache(dummy_name)
--         if result then
--             return data, nil
--         end
--     end
--     return nil, 'no_data'
-- end

-- COMMAND_CACHE = {}

-- function m_field:add_to_cache(command_name, data, updated)
--     COMMAND_CACHE[command_name] = {data=data, updated=updated}
-- end

-- function m_field:read_cache(command_name)
--     if COMMAND_CACHE[command_name] then
--         return true, COMMAND_CACHE[command_name].data
--     end
--     return false
-- end

-- function m_field:is_in_cache(command_name, timeout)
--     local com_data = COMMAND_CACHE[command_name]
--     if com_data == nil then
--         return true
--     end
--     if not timeout then timeout = 10 end
--     if com_data.updated + timeout < os.time() then
--         return true
--     end
--     return false
-- end

local DEVICE_ID = '\x24' -- default

function m_field:get_data()
  local FUNCTION = "\x03"
  local STARTING_ADDR_MSB = "\x00"
  local STARTING_ADDR_LSB = "\x00"
  local DATA_SIZE = "\x24"

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    DEVICE_ID = string.char(tonumber(values[DEVICE_ID_CONFIG], 16))
  end

  local read_command = DEVICE_ID .. FUNCTION .. STARTING_ADDR_MSB .. STARTING_ADDR_LSB .. DATA_SIZE
  local result = rs485.send(read_command .. string.char(m_field:check_rcr(read_command)))
  if result ~= 0 then
    enapter.log("RS485 sending data failed: " .. rs485.err_to_str(result), "error", true)
    return nil, rs485.err_to_str()
  end

  return m_field:read_data()
end

function m_field:read_data()
  local READ_TIMEOUT_S = 3
  local RS485_RESPONSE_TIMEOUT_MS = 1000
  local FULL_LENGTH = 40

  local full_data = ""
  local timeout = os.time() + READ_TIMEOUT_S

  while #full_data < FULL_LENGTH do
    if os.time() > timeout then
      return nil, 2
    end
    local raw_data, result = rs485.receive(RS485_RESPONSE_TIMEOUT_MS)

    if raw_data == nil then
      return nil, result
    end
    full_data = full_data .. raw_data
    while #full_data > 2 and full_data:sub(1, 3) ~= DEVICE_ID.."\x03\x24" do
      full_data = full_data:sub(2, -1)
    end
  end
  full_data = full_data:sub(1, 40)

  if full_data:byte(40) == m_field:check_rcr(full_data:sub(1, 39)) then
    return full_data:sub(1, 39)
  end
  return nil, 2
end

function m_field:check_rcr(newdata)
  local CRC8_TABLE = { 0x00, 0x83, 0x85, 0x06, 0x89, 0x0A, 0x0C, 0x8F,
  0x91, 0x12, 0x14, 0x97, 0x18, 0x9B, 0x9D, 0x1E };
  local crc = 0
  for i = 1, #newdata do
    crc = (((crc << 4) & 0xFF) ~ (CRC8_TABLE[((crc >> 4) ~ (newdata:byte(i) >> 4)) + 1])) & 0xFF
    crc = (((crc << 4) & 0xFF) ~ (CRC8_TABLE[((crc >> 4) ~ (newdata:byte(i) & 0x0F)) + 1])) & 0xFF
  end
  return crc
end

main()
