local config = require('enapter.ucm.config')
local SolarmanHTTP = require('http_connection')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
APP_ID = 'app_id'
APP_SECRET = 'app_secret'
EMAIL = 'email'
USERNAME = 'username'
PASSWORD = 'password'
MOBILE = 'mobile'
COUNTRY_CODE = 'country_code'
DEVICE_SN = 'device_sn'
ORG_NAME = 'org_name'

NOT_CONFIGURED = true

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [EMAIL] = { type = 'string', required = true },
    [PASSWORD] = { type = 'string', required = true },
    [APP_ID] = { type = 'string', required = true },
    [APP_SECRET] = { type = 'string', required = true },
    [DEVICE_SN] = { type = 'string', required = true },
    [ORG_NAME] = { type = 'string', required = true },
    [USERNAME] = { type = 'string', required = false },
    [MOBILE] = { type = 'string', required = false },
    [COUNTRY_CODE] = { type = 'number', required = false },
  }, {
    after_write = function(args)
      if args.password == nil then
        return 'password is required'
      else
        local solarman, err = connect_solarman()
        if not err then
          solarman:set_token()
        end
      end
    end,
  })
end

function send_properties()
  local properties = {}
  local sn, err = config.read(DEVICE_SN)
  if err == nil then
    properties['serial_number'] = sn
  end

  enapter.send_properties(properties)
end

function send_telemetry()
  local values, err = config.read_all()
  if next(values) then
    NOT_CONFIGURED = false
  end
  if err ~= nil then
    enapter.log(err, 'error', true)
    enapter.send_telemetry({
      status = 'warning',
      alerts = { 'invalid_config' },
    })
    return
  end

  if NOT_CONFIGURED then
    enapter.send_telemetry({
      status = 'warning',
      alerts = { 'not_configured' },
    })
    return
  else
    local solarman, err = connect_solarman()
    if err then
      enapter.log("Can't connect to Solarman: " .. err, true)
      enapter.send_telemetry({
        status = 'warning',
        alerts = { 'connection_error' },
      })
      return
    else
      local telemetry, err = solarman:get_realtime_data()
      if err ~= nil then
        enapter.log(err, 'error', true)
      end
      enapter.send_telemetry(telemetry)
    end
  end
end

-- holds global Solarman connection
local solarman

function connect_solarman()
  if solarman and solarman.expires ~= nil then
    if solarman.expires <= os.time() then
      local err = solarman:set_token()
      if err ~= nil then
        return nil, err
      end
    end

    return solarman, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local appSecret, appId = values[APP_SECRET], values[APP_ID]
    local email, password = values[EMAIL], values[PASSWORD]
    local deviceSn, org_name = values[DEVICE_SN], values[ORG_NAME]

    if not appSecret or not appId or not password or not deviceSn or not org_name then
      return nil, 'not_configured'
    else
      local optional = {
        username = values[USERNAME],
        mobile = values[MOBILE],
        country_code = values[COUNTRY_CODE],
      }
      solarman = SolarmanHTTP.new(appId, appSecret, email, password, deviceSn, org_name, optional)
      NOT_CONFIGURED = false

      local err = solarman:set_token()
      if err ~= nil then
        return nil, err
      end
      local err = solarman:bussiness_relation()
      if err ~= nil then
        return nil, err
      end
      local err = solarman:set_token()
      if err ~= nil then
        return nil, err
      end
      return solarman, nil
    end
  end
end

main()
