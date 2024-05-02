-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter

PORT_CONFIG = 'port'
ADDRESS_CONFIG = 'address'
BAUD_RATE_CONFIG = 'baud_rate'

local CONNECTION = {}
local SERIAL_OPTIONS = {}
local TTY

function main()
  -- Init config & register config management commands
  config.init({
    [PORT_CONFIG] = { type = 'string', required = true },
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [BAUD_RATE_CONFIG] = { type = 'string', required = true },
  })

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Crowcon', model = 'Xgard Bright' })
end

function tty_init()
  if TTY then
    return TTY, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local port, address, baud_rate = values[PORT_CONFIG], values[ADDRESS_CONFIG], values[BAUD_RATE_CONFIG]
    if not port or not address or not baud_rate then
      return nil, 'not_configured'
    else
      CONNECTION = {
        read_timeout = 1000,
        address = tonumber(address),
      }

      SERIAL_OPTIONS = {
        baud_rate = tonumber(baud_rate),
        parity = 'N',
        stop_bits = 2,
        data_bits = 8,
        read_timeout = 1000,
      }

      TTY = modbusrtu.new(port, SERIAL_OPTIONS)

      if TTY then
        return TTY, nil
      else
        return nil, 'rs485_init_issue'
      end
    end
  end
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = 'ok'

  local connection, err = tty_init()

  if connection then
    local data, result = connection:read_holdings(CONNECTION.address, 1000, 2, CONNECTION.read_timeout)

    if data then
      telemetry['h2_concentration'] = tofloat(data)
    else
      enapter.log('Error reading Modbus: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end
  else
    status = 'read_error'
    alerts = { err }
  end

  telemetry['alerts'] = alerts
  telemetry['status'] = status

  enapter.send_telemetry(telemetry)
end

function tofloat(register)
  local raw_str = string.pack('BBBB', register[1] >> 8, register[1] & 0xff, register[2] >> 8, register[2] & 0xff)
  return string.unpack('>f', raw_str)
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
    assert(type_ok, 'type of `' .. name .. '` option should be either string or number or boolean')
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
      return nil, 'cannot read `' .. name .. '`: ' .. err
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
  assert(params, 'undeclared config option: `' .. name .. '`, declare with config.init')

  local ok, value, ret = pcall(function()
    return storage.read(name)
  end)

  if not ok then
    return nil, 'error reading from storage: ' .. tostring(value)
  elseif ret and ret ~= 0 then
    return nil, 'error reading from storage: ' .. storage.err_to_str(ret)
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
    return 'error writing to storage: ' .. tostring(ret)
  elseif ret and ret ~= 0 then
    return 'error writing to storage: ' .. storage.err_to_str(ret)
  end
end

-- Serializes value into string for storage
function config.serialize(_, value)
  if value then
    return tostring(value)
  else
    return ''
  end
end

-- Deserializes value from stored string
function config.deserialize(name, value)
  local params = config.options[name]
  assert(params, 'undeclared config option: `' .. name .. '`, declare with config.init')

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
        assert(args[name], '`' .. name .. '` argument required')
      end

      local err = config.write(name, args[name])
      if err then
        ctx.error('cannot write `' .. name .. '`: ' .. err)
      end
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

main()
