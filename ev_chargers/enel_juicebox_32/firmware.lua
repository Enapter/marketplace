json = require("json")

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
ACCOUNT_TOKEN = 'account_token'
UNIT_ID = 'unit_id'

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [ACCOUNT_TOKEN] = {type = 'string', required = true},
    [UNIT_ID] = {type = 'string', required = true}
  })
end

function send_properties()
  local juicebox, err  = connect_juicebox()
  if err then
    enapter.log("Can't connect to JuiceBox: "..err)
    return
  else
    enapter.send_properties({
      vendor = 'Enel',
      model = 'JuiceBox 32',
      serial_number = juicebox.unit_id
    })
  end
end

-- holds global array of alerts that are currently active
active_alerts = {}

function send_telemetry()
  local juicebox, err  = connect_juicebox()
  if err then
    enapter.log("Can't connect to JuiceBox: "..err)
    enapter.send_telemetry({
      status = 'no_data',
      alerts = {'connection_err'}
    })
    return
  else
    local jb_data = juicebox:get_state()
    if next(jb_data) then
      local telemetry = {}

      telemetry.alerts = active_alerts
      telemetry.status = jb_data["state"]
      telemetry.current = jb_data["charging"]["amps_current"]
      telemetry.chargetime = jb_data["charging"]["seconds_charging"]
      telemetry.chargeenergy = jb_data["charging"]["wh_energy"]
      telemetry.voltage = jb_data["charging"]["voltage"]
      telemetry.frequency = jb_data["frequency"] / 100
      telemetry.power = jb_data["charging"]["watt_power"] / 1000
      telemetry.temperature = jb_data["temperature"]
      telemetry.totalenergy = jb_data["lifetime"]["wh_energy"] / 1000

      if telemetry.status == "charging" then
        telemetry.charging_time_left = math.floor(jb_data["charging_time_left"] / 60)
      else
        telemetry.charging_time_left = 0
      end

      if not has_value(active_alerts, "charging_started") and telemetry.status == "charging" then
        active_alerts = {"charging_started"}
      end

      if has_value(active_alerts, "charging_started") and telemetry.status == "plugged" then
        active_alerts = {"charging_stopped"}
      end

      if telemetry.status == "standby" then
        active_alerts = { }
      end
      enapter.send_telemetry(telemetry)
    else
      enapter.send_telemetry({status = 'no_data', alerts = {'no_data'}})
    end
  end
end

-- holds global JuiceBox connection
local juicebox

function connect_juicebox()
  if juicebox then return juicebox, nil end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local account_token, unit_id = values[ACCOUNT_TOKEN], values[UNIT_ID]
    if not account_token or not unit_id then
      return nil, 'not_configured'
    else
      juicebox = JuiceBox.new(account_token, unit_id)
      return juicebox, nil
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
-- JuiceNet API
---------------------------------

JuiceBox = {}

function JuiceBox.new(account_token, unit_id)
  assert(type(account_token) == 'string', 'account_token (arg #1) must be string, given: '..inspect(account_token))
  assert(type(unit_id) == 'string', 'unit_id (arg #2) must be string, given: '..inspect(unit_id))

  local self = setmetatable({}, { __index = JuiceBox })
  self.account_token = account_token
  self.unit_id = unit_id
  self.url = 'https://jbv1-api.emotorwerks.com/'
  self.client = http.client({timeout = 10})
  self.token = self:get_token()
  return self
end

function JuiceBox:get_token()
  local body = json.encode({
    cmd = 'get_account_units',
    device_id = 'vucm',
    account_token = self.account_token
  })

  local response, err = self.client:post(self.url..'box_pin', 'application/json', body)

  if err then
    enapter.log('Cannot do request: '..err, 'error')
  elseif response.code ~= 200 then
    enapter.log('Request returned non-OK code: '..response.code, 'error')
  else
    local t = json.decode(response.body)
    for _,v in pairs(t['units']) do
      if v['unit_id'] == self.unit_id then
        return v['token']
      end
    end
  end
  return nil
end

function JuiceBox:get_state()
  local body = json.encode({
    cmd = 'get_state',
    device_id = 'vucm',
    account_token = self.account_token,
    token = self.token
  })

  local response, err = self.client:post(self.url..'box_api_secure', 'application/json', body)

  if err then
    enapter.log('Cannot do request: '..err, 'error')
  elseif response.code ~= 200 then
    enapter.log('Request returned non-OK code: '..response.code, 'error')
  else
    return json.decode(response.body)
  end
  return nil
end

main()
