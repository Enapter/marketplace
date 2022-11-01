-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter

ADDRESS_CONFIG = 'address'
TOKEN_CONFIG = 'token'
VENDOR_CONFIG = 'vendor'
MODEL_CONFIG = 'model'

-- holds global array of alerts that are currently active
active_alerts = {}

-- load additional libraries
json = require("json")

-- main() sets up scheduled functions and command handlers,
-- it's called explicitly at the end of the file
function main()

  -- Init config & register config management commands
  config.init({
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [TOKEN_CONFIG] = { type = 'string', required = false },
    [VENDOR_CONFIG] = { type = 'string', required = false },
    [MODEL_CONFIG]= { type = 'string', required = false }
  })

  -- Send properties every 30s
  scheduler.add(30000, send_properties)

  -- Send telemetry every 1s
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local vendor, model = values[VENDOR_CONFIG], values[MODEL_CONFIG]
    if not vendor or vendor == "" then
      vendor = 'EMS-ESP'
    end
    if not model or model == "" then
      model = 'Bosch'
    end

    enapter.send_properties({
      vendor = vendor,
      model = model
    })
  end
end

function get_boiler_data()

  local values, err = config.read_all()
  local warning = nil

  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local address, token = values[ADDRESS_CONFIG], values[TOKEN_CONFIG]
    if not address then
      return nil, 'not_configured'
    elseif not token or token == "" then
      warning = 'no_token'
    end

    local client = http.client({timeout = 10})
    local response, err = client:get('http://'..address..'/api/boiler')

    if err then
      enapter.log('Cannot do request: '..err, 'error')
      return nil, 'no_connection'
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: '..response.code, 'error')
      return nil, 'wrong_request'
    else
      return json.decode(response.body), warning
    end
  end
end

function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

function send_telemetry()
  local telemetry = {}

  local boiler, err = get_boiler_data()
  local alert
  if not boiler and err then
    active_alerts = { err }
  else
    active_alerts = { err }
    telemetry.heating_temp_cur = boiler['curflowtemp']
    -- telemetry.heating = firstToUpper(boiler['heatingactive'])
    -- telemetry.wwater = firstToUpper(boiler['wwheat'])
    telemetry.heating_temp_set = boiler['selflowtemp']
    telemetry.wwater_temp_cur = boiler['wwcurtemp']
    telemetry.wwater_temp_set = boiler['wwsettemp']
    telemetry.fan_state = firstToUpper(boiler['fanwork'])
    telemetry.pump_speed = boiler['heatingpumpmod']
    telemetry.gas = firstToUpper(boiler['burngas'])
    telemetry.flame = boiler['flamecurr']
    telemetry.scnum = boiler['servicecodenumber']
    telemetry.sc = boiler['servicecode']


    local status

    if boiler['heatingactive'] == 'on' then
        status = 'Heating'
    elseif boiler['wwheat'] == 'on' then
        status = 'Loading DHW Cylinder'
    else
        status = 'Idle'
    end

    telemetry.status = status

    alert = bc25_err_decode(boiler['servicecode'], boiler['servicecodenumber'])
    if alert then
      table.insert(active_alerts, alert)
    end
  end

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
    assert(type_ok, 'type of `'..name..'` option should be either string or number or boolean')
  end

  enapter.register_command_handler('write_configuration', config.build_write_configuration_command(options))
  enapter.register_command_handler('read_configuration', config.build_read_configuration_command(options))
  enapter.register_command_handler('boiler_configuration', boiler_configuration_command())
  enapter.register_command_handler('read_boiler_configuration', build_read_boiler_configuration_command())

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
    return ""
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

function build_read_boiler_configuration_command(_config_options)
  return function(ctx)
    local values, err = config.read_all()
    if err then
      ctx.error(err)
    else
      local address = values[ADDRESS_CONFIG]
      if not address then
        ctx.error('Address not configured')
      end

      local client = http.client({timeout = 10})
      local response, err = client:get('http://'..address..'/api/boiler')

      if err then
        enapter.log('Cannot do request: '..err, 'error')
        ctx.error('Can not make request to the API')
      elseif response.code ~= 200 then
        enapter.log('Request returned non-OK code: '..response.code, 'error')
        ctx.error('Wrong API response')
      else
        local result = {}
        local settings = json.decode(response.body)

        if settings['heatingactivated'] == "on" then
          result['heating'] = true
        elseif settings['heatingactivated'] == "off" then
          result['heating'] = false
        end

        if settings['wwactivated'] == "on" then
          result['dhw'] = true
        elseif settings['wwactivated'] == "off" then
          result['dhw'] = false
        end

        if settings['heatingtemp'] then
          result['heating_temp'] = settings['heatingtemp']
        end

        if settings['wwsettemp'] then
          result['dhw_temp'] = settings['wwsettemp']
        end

        return result
      end
    end
  end
end

function boiler_set_param(address, token, param, data)
  local request = http.request('POST',
                  'http://'..tostring(address)..'/api/boiler/'..tostring(param), tostring(data))
  local client = http.client({ timeout = 5 })
  request:set_header('Authorization', 'Bearer '..tostring(token))
  request:set_header('Content-Type', 'application/json')
  local response, err = client:do_request(request)

  if err then
    enapter.log('Cannot do request: '..err, 'error')
  else
    enapter.log('Response code: '..response.code)
    local result = json.decode(response.body)
    if result["message"] == "OK" then
      return true
    end
  end
end

function boiler_configuration_command()
  return function(ctx, args)
    local values, err = config.read_all()

    if err then
      ctx.error(err)
    else
      local address, token = values[ADDRESS_CONFIG], values[TOKEN_CONFIG]
      if not address or not token or token == "" then
        ctx.error('Address or Bearer Authentication Token not configured')
      end

      if not boiler_set_param(address, token, 'heatingtemp', '{"value":'..tostring(args["heating_temp"])..'}') then
        ctx.error('Unable to set Heating Temperature')
      end

      if not boiler_set_param(address, token, 'wwseltemp', '{"value":'..tostring(args["dhw_temp"])..'}') then
        ctx.error('Unable to set DHW Temperature')
      end

      local dhw
      if args["dhw"] == true then
        dhw = "on"
      elseif args["dhw"] == false then
        dhw = "off"
      end

      if not boiler_set_param(address, token, 'wwactivated', '{"value": "'..dhw..'"}') then
        ctx.error('Unable to switch DHW')
      end

      local heating
      if args["heating"] == true then
        heating = "on"
      elseif args["heating"] == false then
        heating = "off"
      end

      if not boiler_set_param(address, token, 'heatingactivated', '{"value": "'..heating..'"}') then
        ctx.error('Unable to switch Heating')
      end

    end
  end
end

-- This function responsible to check if error is type B (self-healing), V (blocking, fatal), or non-blocking (R).
-- This is explained in  BC25 Bosch installers manual.
function bc25_err_decode(sc, scnum)
  local scnum_list = {276, 359, 341, 281, 264, 217, 273, 214, 216, 215, 224, 350, 351, 227, 228, 306, 229, 356,
                328, 231, 261, 280, 232, 233, 230, 815, 323, 258, 290, 222, 223, 235, 360, 361, 362, 238, 239, 259}
  local sc_r_list = {'H11','H12','H13','H31'}

  if sc and has_value(sc_r_list,sc) then
    return sc
  end

  if sc and scnum then
    if has_value(scnum_list,scnum) then
        return tostring(scnum)..sc
    end
  end
  return nil
end

function has_value (tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end

main()
