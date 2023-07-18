local config = require('enapter.ucm.config')
local SmappeeHTTP = require('http_connection')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
USERNAME = 'username'
PASSWORD = 'password'
CLIENT_SECRET = 'client_secret'
CLIENT_ID = 'client_id'
SERVICE_LOCATION_NAME = 'service_location_name'

-- holds global Smappee connection
local smappee

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(2000, send_telemetry)

  config.init({
    [USERNAME] = { type = 'string', required = true },
    [PASSWORD] = { type = 'string', required = true },
    [CLIENT_SECRET] = { type = 'string', required = true },
    [CLIENT_ID] = { type = 'string', required = true },
    [SERVICE_LOCATION_NAME] = { type = 'string', required = true },
  },
  {
    after_write = function(args)
      if args.service_location_name == nil then
        return "service_location_name is required"
      else
        smappee:refresh_token()
        smappee:set_service_location_id()
      end
    end
  })
end

function send_properties()
  enapter.send_properties({
    vendor = 'Smappee',
    model = 'Infinity',
  })
end

function send_telemetry()
  local smappee, err = connect_smappee()
  if err then
    enapter.log("Can't connect to Smappee: " .. err)
    enapter.send_telemetry({
      status = 'warning',
      alerts = { 'connection_error' },
    })
    return
  else
    local location_name = config.read(SERVICE_LOCATION_NAME)
    if tostring(location_name) ~= '' then
      smappee:set_service_location_id(location_name, smappee:get_service_locations())

      local telemetry, err = smappee:get_electricity_consumption((os.time() - 600) * 1000, os.time() * 1000)
      if err == nil then
        enapter.send_telemetry(telemetry)
      else
        enapter.log(err, 'error', true)
        enapter.send_telemetry({ status = 'warning', alerts = 'no_data' })
      end
    end
  end
end

function connect_smappee()
  if smappee and smappee.expires ~= nil then
    if smappee.expires <= os.time() then
      local err = smappee:refresh_token()
      if err ~= nil then
        return nil, err
      end
    end

    return smappee, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local client_secret, client_id = values[CLIENT_SECRET], values[CLIENT_ID]
    local username, password = values[USERNAME], values[PASSWORD]
    local location_name = values[SERVICE_LOCATION_NAME]

    if not client_secret or not client_id or not username or not password or not location_name then
      return nil, 'not_configured'
    else
      smappee = SmappeeHTTP.new(username, password, client_secret, client_id)

      local err = smappee:set_token()
      if err == nil then
        return smappee, nil
      else
        return nil, err
      end
    end
  end
end

main()
