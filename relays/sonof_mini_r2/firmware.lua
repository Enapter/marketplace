json = require("json")

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS = 'ip_address'
PORT = 'port'

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('activate_switch', command_switch)
  config.init({
    [IP_ADDRESS] = {type = 'string', required = true},
    [PORT] = {type = 'string', required = true}
  })
end

function send_properties()
  local sonoff, err  = connect_sonoff()
  if err then
    enapter.log("Can't connect to Sonoff: "..err)
    return
  else
    ip_address = sonoff.ip_address
    port = sonoff.port
    client = sonoff.client

    local snf_data = sonoff:get_device_info()
    if next(snf_data) then
      enapter.send_properties({
      vendor = 'Sonoff',
      model = 'MINI R2',
      fw_version = snf_data['data']['fwVersion'],
      ip_address = ip_address,
      port = port
    })
    end
  end
end

-- holds global array of alerts that are currently active
active_alerts = {}

function send_telemetry()
  local sonoff, err  = connect_sonoff()
  local status
  local connection_status
  if err then
    enapter.log("Can't connect to Sonoff: "..err)
    enapter.send_telemetry({
    connection_status = 'no_data',
      alerts = {'connection_err'}
    })
    return
  else
    local snf_data = sonoff:get_device_info()
    if snf_data ~= nil then
      local telemetry = {}

      telemetry.status = pretty_status(snf_data["data"]["switch"])
      telemetry.signal = snf_data['data']['signalStrength']
      telemetry.connection_status = 'ok'
      enapter.send_telemetry(telemetry)
    else
      enapter.send_telemetry({status = 'no_data', connection_status = 'error', alerts = {'no_data'}})
    end
  end
end

function pretty_status(switch_state)
  if switch_state == 'on' then
    return 'switch_on'
  else if switch_state == 'off' then
    return 'switch_off'
  else
    enapter.log("Can't read device state "..err)
  end
  end
end

-- holds global Sonoff connection
local sonoff

function connect_sonoff()
if sonoff and sonoff:get_device_info() then
   return sonoff, nil
 else
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local ip_address, port = values[IP_ADDRESS], values[PORT]
    if not ip_address or not port then
      return nil, 'not_configured'
    else
      sonoff = Sonoff.new(ip_address, port)
      return sonoff, nil
    end
  end
end
end

function has_value (tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end
  return false
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
--Sonoff API
---------------------------------

Sonoff = {}

function Sonoff.new(ip_address, port)
  assert(type(ip_address) == 'string', 'ip_address (arg #1) must be string, given: '..inspect(ip_address))
  assert(type(port) == 'string', 'port (arg #2) must be string, given: '..inspect(port))

  local self = setmetatable({}, { __index = Sonoff })
  self.ip_address = ip_address
  self.port = port
  self.client = http.client({timeout = 10})
  return self
end

function Sonoff:get_device_info()
  local body = json.encode({
    data = {},
    deviceid =''
  })

  local response, err = self.client:post('http://'..self.ip_address..':'..self.port..'/zeroconf/info',
   'application/json', body)

  if err then
    enapter.log('Cannot do request: '..err, 'error')
  elseif response.code ~= 200 then
    enapter.log('Request returned non-OK code: '..response.code, 'error')
  else
    return json.decode(response.body)
  end
  return nil
end



function command_switch(ctx, args)
  if args['action'] then
    local body = json.encode({
      data = {switch = args['action']},
      deviceid = ''
    })

  local response, err = client:post('http://'..ip_address..':'..port..'/zeroconf/switch', 'json',body)

  if err then
    ctx.error('Cannot do request: '..err, 'error')
  elseif response.code ~= 200 then
    ctx.error('Request returned non-OK code: '..response.code, 'error')
  else
    return json.decode(response.body)
  end
  return nil
  end
end

main()
