API_BASE_URL = 'https://api.electricitymap.org'
TELEMETRY_INTERVAL = 120000

local conn_cfg = nil
local cached_telemetry = {}

function enapter.main()
  load_config()
  configuration.after_write('connection', function()
    conn_cfg = nil
  end)

  scheduler.add(1000, load_config)
  scheduler.add(30000, send_properties)
  scheduler.add(TELEMETRY_INTERVAL, fetch_telemetry)
  scheduler.add(1000, send_telemetry)
end

function load_config()
  if conn_cfg then
    return
  end

  if not configuration.is_all_required_set('connection') then
    return
  end

  local cfg, err = configuration.read('connection')
  if err ~= nil then
    enapter.log('read connection configuration: ' .. err, 'error')
    return
  end

  conn_cfg = cfg
end

function send_properties()
  local props = { vendor = 'Electricity Maps' }

  if cached_telemetry.zone then
    props.zone = cached_telemetry.zone
  end

  enapter.send_properties(props)
end

function fetch_telemetry()
  if not conn_cfg then
    return
  end

  cached_telemetry = {}

  local data, alert = fetch_carbon_intensity()
  if alert then
    cached_telemetry = { status = 'conn_error', conn_alerts = { alert } }
    return
  end

  cached_telemetry.carbon_intensity = data.carbonIntensity
  cached_telemetry.zone = data.zone

  data, alert = fetch_power_breakdown()
  if alert then
    cached_telemetry = { status = 'conn_error', conn_alerts = { alert } }
    return
  end

  cached_telemetry.power_consumption_total = data.powerConsumptionTotal
  cached_telemetry.power_production_total = data.powerProductionTotal
  cached_telemetry.fossil_free_percentage = data.fossilFreePercentage
  cached_telemetry.renewable_percentage = data.renewablePercentage
  cached_telemetry.status = 'ok'
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', conn_alerts = { 'not_configured' } })
    return
  end

  if not cached_telemetry.status then
    enapter.send_telemetry({ status = 'conn_error', conn_alerts = { 'communication_failed' } })
    return
  end

  enapter.send_telemetry(cached_telemetry)
end

function fetch_carbon_intensity()
  local url = API_BASE_URL .. '/v3/carbon-intensity/latest?lon=' .. conn_cfg.lon .. '&lat=' .. conn_cfg.lat
  return do_api_request(url)
end

function fetch_power_breakdown()
  local url = API_BASE_URL .. '/v3/power-breakdown/latest?lon=' .. conn_cfg.lon .. '&lat=' .. conn_cfg.lat
  return do_api_request(url)
end

function do_api_request(url)
  local request = http.request('GET', url)
  request:set_header('auth-token', conn_cfg.token)

  local client = http.client({ timeout = 5 })
  local response, err = client:do_request(request)

  if err then
    enapter.log('API request failed: ' .. err, 'error', true)
    return nil, 'communication_failed'
  end

  if response.code == 401 then
    enapter.log('API authentication failed: HTTP ' .. response.code, 'error', true)
    return nil, 'wrong_credentials'
  end

  if response.code ~= 200 then
    enapter.log('API returned HTTP ' .. response.code, 'error', true)
    return nil, 'invalid_response'
  end

  local data = json.decode(response.body)

  if data['error'] then
    enapter.log('API returned error: ' .. tostring(data['error']), 'error', true)
    return nil, 'no_data'
  end

  return data, nil
end
