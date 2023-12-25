-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter

ADDRESS_CONFIG = 'address'
DEVICE_NAME_CONFIG = 'device_name'
TEMP_WARN_LOW = 'temperature_warning_low'
TEMP_CRIT_LOW = 'temperature_critical_low'
TEMP_WARN_HIGH = 'temperature_warning_high'
TEMP_CRIT_HIGH = 'temperature_critical_high'
HUM_WARN_LOW = 'humidity_warning_low'
HUM_CRIT_LOW = 'humidity_critical_low'
HUM_WARN_HIGH = 'humidity_warning_high'
HUM_CRIT_HIGH = 'humidity_critical_high'
BAT_WARN = 'battery_voltage_threshold'

-- holds global array of alerts that are currently active
active_alerts = {}

-- load additional libraries
json = require('json')

-- main() sets up scheduled functions and command handlers,
-- it's called explicitly at the end of the file
function main()
  -- Init config & register config management commands
  config.init({
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [DEVICE_NAME_CONFIG] = { type = 'string', required = true },
    [TEMP_WARN_LOW] = { type = 'number', required = false },
    [TEMP_CRIT_LOW] = { type = 'number', required = false },
    [TEMP_WARN_HIGH] = { type = 'number', required = false },
    [TEMP_CRIT_HIGH] = { type = 'number', required = false },
    [HUM_WARN_LOW] = { type = 'number', required = false },
    [HUM_CRIT_LOW] = { type = 'number', required = false },
    [HUM_WARN_HIGH] = { type = 'number', required = false },
    [HUM_CRIT_HIGH] = { type = 'number', required = false },
    [BAT_WARN] = { type = 'number', required = false },
  })

  -- Send properties every 30s
  scheduler.add(30000, send_properties)

  -- Send telemetry every 1s
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({
    vendor = 'SONOFF',
    model = 'SNZB-02D',
  })
end

local function urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub(' ', '+')
  return url
end

function get_sensor_data()
  local values, err = config.read_all()
  local warning = nil

  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local address, device_name = values[ADDRESS_CONFIG], values[DEVICE_NAME_CONFIG]
    if not address or not device_name then
      return nil, 'not_configured'
    end

    local client = http.client({ timeout = 10 })
    local response, err = client:get(urlencode(address .. '?device=' .. device_name))

    if err then
      enapter.log('Cannot do request: ' .. err, 'error')
      return nil, 'no_connection'
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: ' .. response.code, 'error')
      return nil, 'wrong_request'
    else
      return json.decode(response.body), warning
    end
  end
end

function get_alerts_and_status(telemetry)
  local values, err = config.read_all()
  local alerts = {}
  local critical_present = false
  local warning_present = false

  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    table.insert(alerts, 'cannot_read_config')
    critical_present = true
  else
    local temperature_warning_low = values[TEMP_WARN_LOW]
    local temperature_critical_low = values[TEMP_CRIT_LOW]
    local temperature_warning_high = values[TEMP_WARN_HIGH]
    local temperature_critical_high = values[TEMP_CRIT_HIGH]
    local humidity_warning_low = values[HUM_WARN_LOW]
    local humidity_critical_low = values[HUM_CRIT_LOW]
    local humidity_warning_high = values[HUM_WARN_HIGH]
    local humidity_critical_high = values[HUM_CRIT_HIGH]
    local battery_voltage_threshold = values[BAT_WARN]

    if temperature_warning_low and temperature_critical_low then
      if telemetry.temperature <= temperature_critical_low then
        table.insert(alerts, 'temperature_critical_low')
        critical_present = true
      elseif telemetry.temperature <= temperature_warning_low then
        table.insert(alerts, 'temperature_warning_low')
        warning_present = true
      end
    elseif temperature_warning_low then
      if telemetry.temperature <= temperature_warning_low then
        table.insert(alerts, 'temperature_warning_low')
        warning_present = true
      end
    elseif temperature_critical_low then
      if telemetry.temperature <= temperature_critical_low then
        table.insert(alerts, 'temperature_critical_low')
        critical_present = true
      end
    end

    if temperature_warning_high and temperature_critical_high then
      if telemetry.temperature >= temperature_critical_high then
        table.insert(alerts, 'temperature_critical_high')
        critical_present = true
      elseif telemetry.temperature >= temperature_warning_high then
        table.insert(alerts, 'temperature_warning_high')
        warning_present = true
      end
    elseif temperature_warning_high then
      if telemetry.temperature >= temperature_warning_high then
        table.insert(alerts, 'temperature_warning_high')
        warning_present = true
      end
    elseif temperature_critical_high then
      if telemetry.temperature >= temperature_critical_high then
        table.insert(alerts, 'temperature_critical_high')
        critical_present = true
      end
    end

    if humidity_warning_low and humidity_critical_low then
      if telemetry.humidity <= humidity_critical_low then
        table.insert(alerts, 'humidity_critical_low')
        critical_present = true
      elseif telemetry.humidity <= humidity_warning_low then
        table.insert(alerts, 'humidity_warning_low')
        warning_present = true
      end
    elseif humidity_warning_low then
      if telemetry.humidity <= humidity_warning_low then
        table.insert(alerts, 'humidity_warning_low')
        warning_present = true
      end
    elseif humidity_critical_low then
      if telemetry.humidity <= humidity_critical_low then
        table.insert(alerts, 'humidity_critical_low')
        critical_present = true
      end
    end

    if humidity_warning_high and humidity_critical_high then
      if telemetry.humidity >= humidity_critical_high then
        table.insert(alerts, 'humidity_critical_high')
        critical_present = true
      elseif telemetry.humidity >= humidity_warning_high then
        table.insert(alerts, 'humidity_warning_high')
        warning_present = true
      end
    elseif humidity_warning_high then
      if telemetry.humidity >= humidity_warning_high then
        table.insert(alerts, 'humidity_warning_high')
        warning_present = true
      end
    elseif humidity_critical_high then
      if telemetry.humidity >= humidity_critical_high then
        table.insert(alerts, 'humidity_critical_high')
        critical_present = true
      end
    end

    if battery_voltage_threshold then
      if telemetry.battery <= battery_voltage_threshold then
        table.insert(alerts, 'battery_voltage_low')
        warning_present = true
      end
    else
      if telemetry.battery <= 20 then
        table.insert(alerts, 'battery_voltage_low')
        warning_present = true
      end
    end
  end

  local status = nil

  if critical_present == true then
    status = true
  elseif warning_present == true then
    status = false
  end

  return alerts, status
end

function send_telemetry()
  local telemetry = {}
  local sensor, err = get_sensor_data()
  local status

  if not sensor and err then
    active_alerts = { err }
    status = 'crit'
  else
    active_alerts = { err }
    telemetry.temperature = sensor['temperature']
    telemetry.humidity = sensor['humidity']
    telemetry.battery = sensor['battery']
    telemetry.linkquality = sensor['linkquality']

    local data_alerts, data_status = get_alerts_and_status(telemetry)

    if data_status == nil then
      status = 'okay'
    else
      for _, v in ipairs(data_alerts) do
        table.insert(active_alerts, v)
      end
      if data_status == true then
        status = 'crit'
      else
        status = 'warn'
      end
    end
  end

  telemetry.status = status
  telemetry.alerts = active_alerts
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
