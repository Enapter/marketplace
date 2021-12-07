json = require 'json'

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS_CONFIG = 'ip_address'
EMAIL_CONFIG = 'email'
PASSWORD_CONFIG = 'password'

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(5000, send_telemetry)

  config.init({
    [IP_ADDRESS_CONFIG] = { type = 'string', required = true },
    [EMAIL_CONFIG] = { type = 'string', required = true },
    [PASSWORD_CONFIG] = { type = 'string', required = true },
  })

  enapter.register_command_handler('read_powerwall_config', command_read_powerwall_config)
  enapter.register_command_handler('write_powerwall_config', command_write_powerwall_config)
end

function send_properties()
  local properties = {}

  --[[local tesla, _ = connect_tesla()
  if tesla then
     local status, err = tesla:get('/api/config/completed')
     if err then
       enapter.log(tostring(err), 'error')
     else
       properties.fw_ver = status.version
     end
  end]]

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
  local tesla, err = connect_tesla()
  if not tesla then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = {'cannot_read_config'} })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = {'not_configured'} })
    end
    return
  end

  local telemetry = { alerts = {} }

  local master, err = tesla:get('/api/sitemaster')
  if err then
    enapter.log(tostring(err), 'error')
  else
    if master.running == true then
      telemetry.status = 'ok'
    elseif master.running == false then
      telemetry.status = 'stopped'
    end
  end

  local operation, err = tesla:get('/api/operation')
  if err then
    enapter.log(tostring(err), 'error')
  else
    telemetry.operation_mode = operation.mode or operation.real_mode
    telemetry.backup_reserve_percent = operation.backup_reserve_percent
  end

  local sys, err = tesla:get('/api/system_status')
  if err then
    enapter.log(tostring(err), 'error')
  else
    telemetry.nominal_full_pack_energy = sys.nominal_full_pack_energy
  end

  local grid, err = tesla:get('/api/system_status/grid_status')
  if err then
    enapter.log(tostring(err), 'error')
  else
    telemetry.grid_status = grid.grid_status
  end

  local soe, err = tesla:get('/api/system_status/soe')
  if err then
    enapter.log(tostring(err), 'error')
  else
    telemetry.battery_soc = soe.percentage
  end

  local meters, err = tesla:get('/api/meters/aggregates')
  if err then
    enapter.log(tostring(err), 'error')
  else
    telemetry.grid_power = (meters.site or {}).instant_power
    telemetry.grid_energy_exported = (meters.site or {}).energy_exported
    telemetry.grid_energy_imported = (meters.site or {}).energy_imported

    -- this is microgrid frequency (when connected or disconnected to utility grid)
    telemetry.frequency = (meters.battery or {}).frequency

    telemetry.battery_power = (meters.battery or {}).instant_power
    telemetry.battery_voltage = (meters.battery or {}).instant_average_voltage
    telemetry.battery_amperage = (meters.battery or {}).instant_total_current
    telemetry.battery_energy_exported = (meters.battery or {}).energy_exported
    telemetry.battery_energy_imported = (meters.battery or {}).energy_imported

    telemetry.load_power = (meters.load or {}).instant_power
    telemetry.load_voltage = (meters.load or {}).instant_average_voltage
    telemetry.load_amperage = (meters.load or {}).instant_total_current
    telemetry.load_energy_exported = (meters.load or {}).energy_exported
    telemetry.load_energy_imported = (meters.load or {}).energy_imported

    telemetry.solar_power = (meters.solar or {}).instant_power
    telemetry.solar_voltage = (meters.solar or {}).instant_average_voltage
    telemetry.solar_amperage = (meters.solar or {}).instant_total_current
    telemetry.solar_energy_exported = (meters.solar or {}).energy_exported
    telemetry.solar_energy_imported = (meters.solar or {}).energy_imported
  end

  enapter.send_telemetry(telemetry)
end

-- Holds global Tesla connection
local tesla

function connect_tesla()
  if tesla then return tesla, nil end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local ip_address, email, password = values[IP_ADDRESS_CONFIG], values[EMAIL_CONFIG], values[PASSWORD_CONFIG]
    if not ip_address or not email or not password then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      tesla = TeslaPowerwall.new(ip_address, email, password)
      return tesla, nil
    end
  end
end

function command_read_powerwall_config(ctx)
  local connected_tesla, err = connect_tesla()
  if connected_tesla then
    local operation, err = connected_tesla:get('/api/operation')
    if err then
      ctx.error(err)
    else
      return {
        operation_mode = operation.mode or operation.real_mode,
        backup_reserve_percent = operation.backup_reserve_percent
      }
    end
  else
    ctx.error(err)
  end
end

function command_write_powerwall_config(ctx, args)
  -- assert(
  --   type(args.operation_mode) == 'string',
  --   'operation_mode arg must be string, given: '..inspect(args.operation_mode)
  -- )
  assert(
    type(args.backup_reserve_percent) == 'number',
    'backup_reserve_percent arg must be number, given: '..inspect(args.backup_reserve_percent)
  )

  local connected_tesla, err = connect_tesla()
  if connected_tesla then
    local json = require('json')
    local body = json.encode({
      -- mode = args.operation_mode,
      backup_reserve_percent = args.backup_reserve_percent
    })
    local _, err = connected_tesla:post('/api/operation', 'application/json', body)
    if err then
      ctx.error(err)
    end
  else
    ctx.error(err)
  end
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
-- Tesla Powerwall API
---------------------------------

TeslaPowerwall = {}

function TeslaPowerwall.new(ip_addr, email, password, _login_type)
  assert(type(ip_addr) == 'string', 'ip_addr (arg #1) must be string, given: '..inspect(ip_addr))
  assert(type(email) == 'string', 'email (arg #2) must be string, given: '..inspect(email))
  assert(type(password) == 'string', 'password (arg #3) must be string, given: '..inspect(password))
  -- assert(type(login_type) == 'string', 'login_type (arg #4) must be string, given: '..inspect(login_type))

  local self = setmetatable({}, { __index = TeslaPowerwall })
  self.ip_addr = ip_addr
  self.email = email
  self.password = password
  self.client = http.client({
    timeout = 5,
    insecure_tls = true,
    enable_cookie_jar = true
  })
  return self
end

function TeslaPowerwall:authenticate()
  local json = require('json')

  local body = json.encode({
    username = 'customer',
    password = self.password,
    email = self.email,
    force_sm_off = false
  })
  local request = http.request('POST', 'https://'..self.ip_addr..'/api/login/Basic', body)
  request:set_header('Content-Type', 'application/json')

  local result, err = self.client:do_request(request)
  if err then return nil, err end
  if not(result.code >= 200 and result.code < 300) then
    return nil, 'HTTP '..result.code..': '..result.body
  end

  local token = json.decode(result.body).token

  return token, nil
end

function TeslaPowerwall:request(request)
  local result, err = self.client:do_request(request)
  if err then return nil, err end
  if result.code == 401 or result.code == 403 then
    local _, err = self:authenticate()
    if err then return nil, err end

    -- redo request
    result, err = self.client:do_request(request)
    if err then return nil, err end
  end
  if not(result.code >= 200 and result.code < 300) then
    return nil, 'HTTP '..result.code..': '..result.body
  end

  local result, err = json.decode(result.body)
  if err then return nil, err end

  return result, nil
end

function TeslaPowerwall:get(path)
  local request = http.request('GET', 'https://'..self.ip_addr..path)
  return self:request(request)
end

function TeslaPowerwall:post(path, content_type, body)
  local request = http.request('POST', 'https://'..self.ip_addr..path, body)
  local token, err = self:authenticate()
  if err then return nil, err end
  request:set_header('Authorization', 'Bearer '..token)
  request:set_header('Content-Type', content_type)
  return self:request(request)
end

main()
