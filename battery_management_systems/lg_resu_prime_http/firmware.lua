json = require 'json'

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS_CONFIG = 'ip_address'

MYModel=''

function main()
  scheduler.add(30000, sendmyproperties)
  scheduler.add(15000, sendmytelemetry)

  config.init({
    [IP_ADDRESS_CONFIG] = { type = 'string', required = true }
  })

end

-- To send data to Enapter Cloud use `enapter` variable as shown below.
function registration()
--  enapter.send_registration({ vendor = "C-Labs", model = "LG RESU PRIME" })
end

function sendmyproperties()
  local properties = {}
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    for name, val in pairs(values) do
      properties[name] = val
    end
  end
  if (MYModel~='') then
    properties['model']=MYModel
  end
  enapter.send_properties(properties)
end

function sendmytelemetry()
  local json = require('json')

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local ip_address = values[IP_ADDRESS_CONFIG]
    local telemetry = {}

    local response, err = http.get('http://'..ip_address..'/getbmsdata')
    if err then
      enapter.log('Cannot do request: '..err, 'error')
      return 
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: '..response.code, 'error')
      return 
    end
    
    local tres=response.body
    tres=string.gsub(tres, '<caption>BMS Data</caption><tr><th class=','')
    tres=string.gsub(tres, '>Item</th><th class=','')
    tres=string.gsub(tres, '\"text','')
    tres=string.gsub(tres, '%-center\"','')
    tres=string.gsub(tres, '>Value</th></tr>', '{')
    tres=string.gsub(tres, '</td></tr><tr><td>', '", "')
    tres=string.gsub(tres, '<tr><td>',' "')
    tres=string.gsub(tres, '</td><td>','": "')
    tres=string.gsub(tres, '</td></tr>', '" }')
    --enapter.log('Request succeeded: '..tres, 'info')

    local deco=json.decode(tres)
    telemetry["battery_soc"] = tonumber(deco.SOC)/100
    telemetry["battery_power"]= tonumber(deco.Current)
    telemetry["battery_temp"]= tonumber(deco.Temperature)/10
    telemetry["lastresponse"]='All Good'
    local tcur=tonumber(deco.OperationModeStatus);
    telemetry["battery_energy"]= tonumber(deco.SOH)
    telemetry["battery_voltage"]= tonumber(deco.AvgCellVoltage)/100

    if (MYModel=='') then
      if (tonumber(deco.SOH)==10000) then
        MYModel="LG RESU10 Prime"
      else
        MYModel="LG RESU16 Prime"
      end
    end

    if (tcur==0) then
      telemetry["status"]='Off'
    elseif (tcur==1) then
      telemetry["status"]='Standby'
    elseif (tcur==2) then
      telemetry["status"]='Initializing'
    elseif (tcur==3) then
      telemetry["status"]='Charging'
    elseif (tcur==4) then
      telemetry["status"]='Discharging'
    elseif (tcur==5) then
      telemetry["status"]='Fault'
    elseif (tcur==7) then
      telemetry["status"]='Idle'
    end
    enapter.send_telemetry(telemetry)
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

main()
