local config = require('enapter.ucm.config')
local json = require('json')
telemetry = {}
active_alerts = {}

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
TOKEN_CONFIG = 'token'
LAT_CONFIG = 'lat'
LON_CONFIG = 'lon'
ZONE = nil

function get_config()
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local token = values[TOKEN_CONFIG]
    local lon = values[LON_CONFIG]
    local lat = values[LAT_CONFIG]

    if not token or not lon or not lat then
      return nil, 'not_configured'
    else
      return values, nil
    end
  end
end

function get_status()
  -- Token is not needed to access this endpoint
  local request = http.request('GET', 'https://api.electricitymap.org/health')
  local client = http.client({ timeout = 5 })
  local response, err = client:do_request(request)

  if err then
    enapter.log('Cannot do request: ' .. err, 'error')
    return nil, 'no_connection'
  elseif response.code ~= 200 then
    enapter.log('Request returned non-OK code: ' .. response.code, 'error')
    return nil, 'wrong_request'
  else
    local jb = json.decode(response.body)
    return jb, nil
  end
end

function get_data()
  local values, err = get_config()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, err
  else
    local token = values[TOKEN_CONFIG]
    local lon = values[LON_CONFIG]
    local lat = values[LAT_CONFIG]
    local result = {}

    local request =
      http.request('GET', 'https://api.electricitymap.org/v3/carbon-intensity/latest?lon=' .. lon .. '&lat=' .. lat)
    request:set_header('auth-token', token)
    local client = http.client({ timeout = 5 })
    local response, err = client:do_request(request)

    if err then
      enapter.log('Cannot do request: ' .. err, 'error')
      return nil, 'no_connection'
    elseif response.code == 401 then
      enapter.log('Request returned non-OK code: ' .. response.code, 'error')
      return nil, 'wrong_password'
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: ' .. response.code, 'error')
      return nil, 'wrong_request'
    else
      local jb = json.decode(response.body)
      if jb['error'] then
        return nil, 'no_data'
      else
        result['carbonIntensity'] = jb['carbonIntensity']
        result['zone'] = jb['zone']
      end
    end

    local request =
      http.request('GET', 'https://api.electricitymap.org/v3/power-breakdown/latest?lon=' .. lon .. '&lat=' .. lat)
    request:set_header('auth-token', token)
    local client = http.client({ timeout = 5 })
    local response, err = client:do_request(request)

    if err then
      enapter.log('Cannot do request: ' .. err, 'error')
      return nil, 'no_connection'
    elseif response.code == 401 then
      enapter.log('Request returned non-OK code: ' .. response.code, 'error')
      return nil, 'wrong_password'
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: ' .. response.code, 'error')
      return nil, 'wrong_request'
    else
      local jb = json.decode(response.body)
      if jb['error'] then
        return nil, 'no_data'
      else
        result['powerConsumptionTotal'] = jb['powerConsumptionTotal']
        result['powerProductionTotal'] = jb['powerProductionTotal']
        result['fossilFreePercentage'] = jb['fossilFreePercentage']
        result['renewablePercentage'] = jb['renewablePercentage']
      end
    end

    return result, nil
  end
end

function main()
  config.init({
    [TOKEN_CONFIG] = { type = 'string', required = true },
    [LON_CONFIG] = { type = 'string', required = true },
    [LAT_CONFIG] = { type = 'string', required = true },
  })
  scheduler.add(5000, send_properties)
  scheduler.add(120000, prepare_telemetry)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  local data, err = get_config()

  if not err then
    enapter.send_properties({
      vendor = 'Electricity Maps (Personal)',
      lat = data['lat'],
      lon = data['lon'],
      zone = ZONE,
    })
  end
end

function prepare_telemetry()
  telemetry = {}
  local status = 'Offline'

  local data, err = get_status()

  if err then
    active_alerts = { err }
  elseif data['status'] == 'ok' then
    active_alerts = {}
    status = 'Online'

    data, err = get_data()

    if err then
      active_alerts = { err }
    else
      telemetry = data
      ZONE = data['zone']
    end
  else
    active_alerts = {}
    status = 'Offline'
  end

  -- Don't send zone information
  telemetry['zone'] = nil
  telemetry['alerts'] = active_alerts
  telemetry['status'] = status
end

function send_telemetry()
  enapter.send_telemetry(telemetry)
end

main()
