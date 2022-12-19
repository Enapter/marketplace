-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter

ADDRESS_CONFIG = 'address'
MODEL_CONFIG = 'model'
HEATER_MAX_POWER = 'heater_power'

-- main() sets up scheduled functions and command handlers,
-- it's called explicitly at the end of the file
function main()

  -- Init config & register config management commands
  config.init({
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [MODEL_CONFIG]= { type = 'string', required = false },
    [HEATER_MAX_POWER] = { type = 'number', required = false }
  })

  -- Send properties every 30s
  scheduler.add(30000, send_properties)

  -- Send telemetry every 5s
  scheduler.add(5000, send_telemetry)
end

function send_properties()
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local model = values[MODEL_CONFIG]
    if not model or model == "" then
      model = 'C4/Ping2'
    end

    local vendor = 'Komfovent'

    enapter.send_properties({
      vendor = vendor,
      model = model
    })
  end
end

function get_ahu_data()

  local values, err = config.read_all()
  local warning = {}
  local ahu = {}

  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, { 'cannot_read_config' }
  else
    local address,heater_power = values[ADDRESS_CONFIG], values[HEATER_MAX_POWER]
    if not address then
      return nil, { 'not_configured' }
    end

    if not heater_power then
      heater_power = 1000
    end

    local modbus_conn = modbustcp.new(address..":502")

    local response, err
    response, err = modbus_conn:read_holdings(0, 1001-1, 1, 1000)
    if not response then
      enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
      if err ~= 13 then
        return nil, { 'no_connection' }
      else
        return nil, nil
      end
    else
      if tonumber(response[1]) == 1 then
        ahu['season'] = 'Winter'
      elseif tonumber(response[1]) == 0 then
        ahu['season'] = 'Summer'
      end
    end

    response, err = modbus_conn:read_holdings(0, 1101-1, 1, 1000)
    if not response then
      enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
      if err ~= 13 then
        return nil, { 'no_connection' }
      else
        return nil, nil
      end
    else
      if tonumber(response[1]) == 0 then
        ahu['status'] = 'Idle'
      elseif tonumber(response[1]) == 1 then
        ahu['status'] = 'Away'
      elseif tonumber(response[1]) == 2 then
        ahu['status'] = 'Home'
      elseif tonumber(response[1]) == 3 then
        ahu['status'] = 'Forced Ventilation'
      elseif tonumber(response[1]) == 4 then
        ahu['status'] = 'Smoke Remove'
      end
    end

    response, err = modbus_conn:read_holdings(0, 1200-1, 2, 1000)
    if not response then
      enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
      if err ~= 13 then
        return nil, { 'no_connection' }
      else
        return nil, nil
      end
    else
      ahu['temperature'] = tonumber(response[1]) / 10
      ahu['temperature_setpoint'] = tonumber(response[2]) / 10
    end

    response, err = modbus_conn:read_holdings(0, 1010-1, 2, 1000)
    if not response then
      enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
      if err ~= 13 then
        return nil, { 'no_connection' }
      else
        return nil, nil
      end
    else
      ahu['recuperator'] = tonumber(response[1])
      ahu['heater'] = tonumber(response[2])
      ahu['heater_power'] = heater_power * tonumber(response[2]) / 100
    end

    response, err = modbus_conn:read_holdings(0, 1115-1, 2, 1000)
    if not response then
      enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
      if err ~= 13 then
        return nil, { 'no_connection' }
      else
        return nil, nil
      end
    else
      ahu['intake_fan'] = tonumber(response[1])
      ahu['exhaust_fan'] = tonumber(response[2])
    end

    response, err = modbus_conn:read_holdings(0, 1007-1, 3, 1000)
    if not response then
      enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
      if err ~= 13 then
        return nil, { 'no_connection' }
      else
        return nil, nil
      end
    else
      enapter.log('Warning: '..tostring(tonumber(response[1])))
      enapter.log('Alarm: '..tostring(tonumber(response[3])))

      if tonumber(response[1]) == 8192 then
        table.insert(warning,'W14')
      end
      if tonumber(response[1]) == 4096 then
        table.insert(warning,'W13')
      end
      if tonumber(response[1]) == 1024 then
        table.insert(warning,'W10')
      end
      if tonumber(response[3]) == 3 then
        table.insert(warning,'F3')
      end
      if tonumber(response[3]) == 4 then
        table.insert(warning,'F4')
      end
      if tonumber(response[3]) == 9 then
        table.insert(warning,'F9')
      end
      if tonumber(response[3]) == 19 then
        table.insert(warning,'F19')
      end
      if tonumber(response[3]) == 20 then
        table.insert(warning,'F20')
      end
      if tonumber(response[3]) == 27 then
        table.insert(warning,'F27')
      end
      if tonumber(response[3]) == 28 then
        table.insert(warning,'F28')
      end
    end


    return ahu, warning
  end
end

function send_telemetry()
  local telemetry = {}

  local ahu, err = get_ahu_data()
  telemetry.alerts = err

  if not ahu and err then
    enapter.send_telemetry(telemetry)
  elseif ahu then
    telemetry.season = ahu['season']
    telemetry.status = ahu['status']
    telemetry.temperature = ahu['temperature']
    telemetry.temperature_setpoint = ahu['temperature_setpoint']
    telemetry.recuperator = ahu['recuperator']
    telemetry.heater = ahu['heater']
    telemetry.heater_power = ahu['heater_power']
    telemetry.intake_fan = ahu['intake_fan']
    telemetry.exhaust_fan = ahu['exhaust_fan']

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
  enapter.register_command_handler('ahu_configuration', ahu_configuration_command())
  enapter.register_command_handler('read_ahu_configuration', build_read_ahu_configuration_command())
  enapter.register_command_handler('away', away_command())
  enapter.register_command_handler('home', home_command())
  enapter.register_command_handler('forced_ventilation', forced_ventilation_command())

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

function build_read_ahu_configuration_command(_config_options)
  return function(ctx)
    local values, err = config.read_all()
    if err then
      ctx.error(err)
    else
      local address = values[ADDRESS_CONFIG]
      if not address then
        ctx.error('Address not configured')
      end

      local modbus_conn = modbustcp.new(address..":502")

      local result = {}

      local response, err
      response, err = modbus_conn:read_holdings(0, 1000-1, 2, 3000)
      if not response then
        enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
        ctx.error('Can not make Modbus request')
      else
        if tonumber(response[1]) == 1 then
          result['operation'] = true
        elseif tonumber(response[1]) == 0 then
          result['operation'] = false
        end

        if tonumber(response[2]) == 1 then
          result['season'] = 'Winter'
        elseif tonumber(response[2]) == 0 then
          result['season'] = 'Summer'
        end
      end

      response, err = modbus_conn:read_holdings(0, 1201-1, 1, 1500)
      if not response then
        enapter.log('Cannot make request: '..tostring(err)..' '..modbustcp.err_to_str(err), 'error')
        ctx.error('Can not make Modbus request')
      else
        result['temperature'] = tonumber(response[1]) / 10
      end

      return result
    end
  end
end

function ahu_configuration_command()
  return function(ctx, args)
    local values, err = config.read_all()

    if err then
      ctx.error(err)
    else
      local address = values[ADDRESS_CONFIG]
      if not address then
        ctx.error('Modbus TCP IP address not configured')
      end

      local modbus_conn = modbustcp.new(address..":502")
      local value = nil

      if args['operation'] == true then
        value = 1
      elseif args['operation'] == false then
        value = 0
      end

      if not modbus_conn:write_holding(0, 1000-1, value, 1000) then
        ctx.error('Unable to Start or Stop AHU')
      else
        value = nil
      end

      if args['season'] == 'Winter' then
        value = 1
      elseif args['season'] == 'Summer' then
        value = 0
      end

      if not modbus_conn:write_holding(0, 1001-1, value, 1000) then
        ctx.error('Unable to Set Season')
      end

      value = tonumber(args['temperature']) * 10
      if not modbus_conn:write_holding(0, 1201-1, value, 1000) then
        ctx.error('Unable to Set Temperature Setpoint')
      end
    end
  end
end

function away_command()
  return function(ctx)
    local values, err = config.read_all()

    if err then
      ctx.error(err)
    else
      local address = values[ADDRESS_CONFIG]
      if not address then
        ctx.error('Modbus TCP IP address not configured')
      end

      local modbus_conn = modbustcp.new(address..":502")

      if modbus_conn:write_holding(0, 1100-1, 1, 1000) ~= 0 then
        ctx.error('Unable to Start or Stop AHU')
      end
    end
  end
end

function home_command()
  return function(ctx)
    local values, err = config.read_all()

    if err then
      ctx.error(err)
    else
      local address = values[ADDRESS_CONFIG]
      if not address then
        ctx.error('Modbus TCP IP address not configured')
      end

      local modbus_conn = modbustcp.new(address..":502")

      if modbus_conn:write_holding(0, 1100-1, 2, 1000) ~= 0 then
        ctx.error('Unable to Start or Stop AHU')
      end
    end
  end
end

function forced_ventilation_command()
  return function(ctx)
    local values, err = config.read_all()

    if err then
      ctx.error(err)
    else
      local address = values[ADDRESS_CONFIG]
      if not address then
        ctx.error('Modbus TCP IP address not configured')
      end

      local modbus_conn = modbustcp.new(address..":502")

      if modbus_conn:write_holding(0, 1100-1, 3, 1000) ~= 0 then
        ctx.error('Unable to Start or Stop AHU')
      end
    end
  end
end

main()
