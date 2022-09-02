-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS_CONFIG = 'ip_address'
IP_PORT_CONFIG = 'ip_port'
DEVICEID_CONFIG = 'device_id'
REMOTE_NUMBER_CONFIG = 'remote_number'

json = require("json")

detector_triggered = false

function get_data()
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local ip_address, ip_port, device_id, remote_number = values[IP_ADDRESS_CONFIG],
    values[IP_PORT_CONFIG], values[DEVICEID_CONFIG], values[REMOTE_NUMBER_CONFIG]

    if not ip_address or not ip_port or not device_id or not remote_number then
      return nil, 'not_configured'
    end

    local response, err = http.get('http://'..ip_address..':'..ip_port)

    if err then
      enapter.log('Cannot do request: '..err, 'error')
      return nil, 'no_connection'
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: '..response.code, 'error')
      return nil, 'wrong_request'
    else
      local index
      local jb = json.decode(response.body)
      for k, v in pairs(jb) do
        if v['deviceid'] == device_id then
          index = k
        end
      end

      if not index then
        return nil, 'deviceid_not_found'
      end

      return jb[index], nil
    end
  end
end

function disable_alert()
    detector_triggered = false
    active_alerts = {}
end

  -- main() sets up scheduled functions and command handlers,
  -- it's called explicitly at the end of the file
function main()
    -- Send properties every 30s
    scheduler.add(30000, send_properties)

    -- Send telemetry every 1s
    scheduler.add(1000, send_telemetry)

    config.init({
        [IP_ADDRESS_CONFIG] = { type = 'string', required = true },
        [IP_PORT_CONFIG] = { type = 'string', required = true },
        [DEVICEID_CONFIG] = { type = 'string', required = true },
        [REMOTE_NUMBER_CONFIG] = { type = 'string', required = true },
        })

    -- Register command handlers
    enapter.register_command_handler('disable_alert', disable_alert)
end

function send_properties()
    local brandName, productModel, chipid

    local jb, err = get_data()
    if err then
        brandName = ''
        productModel = ''
        chipid = ''
    else
        brandName = jb["brandName"]
        productModel = jb["productModel"]
        chipid = jb["extra"]["extra"]["chipid"]
    end

    enapter.send_properties({
        vendor = brandName,
        model = productModel,
        serial_number = chipid
    })
end

-- holds global array of alerts that are currently active
active_alerts = {}

function send_telemetry()
    local telemetry = {}

    local remote = storage.read(REMOTE_NUMBER_CONFIG)

    local jb, err = get_data()

    if err then
        active_alerts = { err }
    else
        active_alerts = {}

        if detector_triggered then
            active_alerts = {"detector_triggered"}
        end

        local status
        if jb["online"] then
            status = "Online"
        else
            status = "Offline"
        end
        telemetry.status = status

        if detector_triggered then
            telemetry.detector = "On"
        else
            telemetry.detector = "Off"
        end

        local detector = "rfTrig" .. remote

        local rfTrig
--        if rfTrig == nil then
        if not rfTrig then
            rfTrig = jb["params"][detector]
        end

        if rfTrig ~= jb["params"][detector] then
            for k,v in pairs(jb["tags"]["zyx_info"]) do
                if k == tonumber(remote) + 1 then
                    detector_triggered = true
                    active_alerts = {"detector_triggered"}
                    enapter.log(tostring(v["name"]) .. " triggered!")
                end
            end
            rfTrig = jb["params"][detector]
        end

        telemetry.last_triggered = jb["params"][detector]
        telemetry.rssi = jb["params"]["rssi"]

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
