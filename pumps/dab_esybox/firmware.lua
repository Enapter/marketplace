-- DAB EsyBox Pump DConnect API Integration
-- Communicates with DAB EsyBox intelligent pump systems via DConnect cloud service

local config = require('enapter.ucm.config')

-- Configuration constants
local CONFIG_USERNAME = 'username'
local CONFIG_PASSWORD = 'password'
local CONFIG_INSTALLATION_ID = 'installation_id'
local CONFIG_DEVICE_SERIAL = 'device_serial'
local CONFIG_VERBOSE_LOGGING = 'verbose_logging'

-- API constants
local DCONNECT_BASE_URL = 'https://dconnect.dabpumps.com'
local DCONNECT_AUTH_URL = 'https://dconnect.dabpumps.com/auth/token'
local API_TIMEOUT = 20 -- seconds

-- Shared HTTP client (lazy-initialized, reused across all requests)
local http_client = nil

local function get_http_client()
  if not http_client then
    http_client = http.client({ timeout = API_TIMEOUT })
  end
  return http_client
end

-- State management
local access_token = nil
local token_expires_at = 0
local device_config = nil
local param_map = {}
local last_pump_disabled = nil -- nil = unknown, true/false from latest telemetry
local consecutive_failures = 0
local FAILURE_THRESHOLD = 5 -- Only show offline after this many consecutive failures

-- Helper function for verbose logging
local function log_verbose(message, level)
  local values = config.read_all()
  if values and values[CONFIG_VERBOSE_LOGGING] then
    enapter.log(message, level or 'info')
  end
end

-- Main entry point
function main()
  -- Initialize configuration
  config.init({
    [CONFIG_USERNAME] = { type = 'string', required = true },
    [CONFIG_PASSWORD] = { type = 'string', required = true },
    [CONFIG_INSTALLATION_ID] = { type = 'string', required = false },
    [CONFIG_DEVICE_SERIAL] = { type = 'string', required = false },
    [CONFIG_VERBOSE_LOGGING] = { type = 'boolean', required = false, default = false },
  })

  -- Register command handlers
  enapter.register_command_handler('start_pump', start_pump)
  enapter.register_command_handler('stop_pump', stop_pump)

  -- Schedule periodic tasks
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  -- Send initial properties
  send_properties()
end

-- Send device properties
function send_properties()
  local props = {
    vendor = 'DAB Pumps',
    model = 'EsyBox',
  }

  -- Add device info if available
  if device_config then
    if device_config.ProductName then
      props.model = device_config.ProductName
    end
    if device_config.serial then
      props.serial_number = device_config.serial
    end
    if device_config.distro_embedded then
      props.firmware_version = device_config.distro_embedded
    end
  end

  enapter.send_properties(props)
end

-- Send telemetry data
function send_telemetry()
  local telemetry = {
    alarm_active = false, -- Initialize to false, will be set to true if alarm detected
    pump_running = false, -- Initialize to false, will be set based on WorkingMode/PumpStatus
  }
  local alerts = {}

  -- Check configuration
  local values, err = config.read_all()
  if err then
    enapter.send_telemetry({ status = 'error', alerts = { 'cannot_read_config' } })
    return
  end

  -- Validate required configuration
  if not values[CONFIG_USERNAME] or not values[CONFIG_PASSWORD] then
    enapter.send_telemetry({ status = 'not_configured', alerts = { 'not_configured' } })
    return
  end

  -- Ensure authentication
  local auth_ok, auth_err = ensure_authenticated(values[CONFIG_USERNAME], values[CONFIG_PASSWORD])
  if not auth_ok then
    enapter.log('Authentication failed: ' .. (auth_err or 'unknown error'), 'error')
    enapter.send_telemetry({ status = 'error', alerts = { 'auth_failed' } })
    return
  end

  -- Get installation and device if not configured
  if not values[CONFIG_INSTALLATION_ID] or not values[CONFIG_DEVICE_SERIAL] then
    enapter.log('Starting device discovery...', 'info')
    local install_id, serial = discover_installation()
    if install_id and serial then
      -- Auto-configure first installation and device
      enapter.log('Discovered installation: ' .. install_id .. ', device: ' .. serial, 'info')

      -- Write configuration values
      local ok1 = config.write(CONFIG_INSTALLATION_ID, install_id)
      local ok2 = config.write(CONFIG_DEVICE_SERIAL, serial)

      if ok1 and ok2 then
        values[CONFIG_INSTALLATION_ID] = install_id
        values[CONFIG_DEVICE_SERIAL] = serial
        enapter.log('Auto-configuration saved successfully', 'info')
      else
        enapter.log('Failed to save auto-configuration', 'error')
        enapter.send_telemetry({ status = 'error', alerts = { 'cannot_read_config' } })
        return
      end
    else
      enapter.log('Device discovery failed - no installations or devices found', 'error')
      enapter.send_telemetry({ status = 'discoveryneeded', alerts = { 'not_configured' } })
      return
    end
  end

  -- Load device configuration if not cached
  if not device_config then
    enapter.log('Loading device configuration...', 'info')
    local config_ok = load_device_configuration(values[CONFIG_INSTALLATION_ID], values[CONFIG_DEVICE_SERIAL])
    if not config_ok then
      enapter.log('Failed to load device configuration', 'error')
      enapter.send_telemetry({ status = 'error', alerts = { 'config_load_failed' } })
      return
    end
    enapter.log('Device configuration loaded successfully', 'info')
  end

  -- Fetch device status
  enapter.log('Fetching device status for serial: ' .. values[CONFIG_DEVICE_SERIAL], 'info')
  local status_ok = read_device_status(values[CONFIG_DEVICE_SERIAL], telemetry, alerts)
  if not status_ok then
    consecutive_failures = consecutive_failures + 1
    enapter.log('Failed to read device status (failure ' ..
      consecutive_failures .. '/' .. FAILURE_THRESHOLD .. ')', 'error')

    -- Only report offline after threshold consecutive failures
    if consecutive_failures >= FAILURE_THRESHOLD then
      telemetry.status = 'error'
      table.insert(alerts, 'no_connection')
      -- Set alerts
      telemetry.alerts = alerts
      -- Send telemetry showing offline
      enapter.send_telemetry(telemetry)
    else
      -- Skip sending telemetry on transient failures to keep last good values on charts
      enapter.log('Skipping telemetry send - waiting for connection to stabilize', 'info')
    end
    return
  end

  -- Reset counter on success
  consecutive_failures = 0
  enapter.log('Device status read successfully', 'info')

  -- Parse telemetry and determine status
  process_telemetry(telemetry, alerts)

  -- Set alerts
  telemetry.alerts = alerts

  -- Send telemetry
  enapter.send_telemetry(telemetry)
end

-- Ensure we have valid authentication token
function ensure_authenticated(username, password)
  -- Check if token is still valid (with 30 second safety margin)
  local current_time = os.time()
  if access_token and current_time < (token_expires_at - 30) then
    return true
  end

  -- Authenticate using DConnect API
  enapter.log('Authenticating with DConnect...', 'info')

  local client = get_http_client()
  local response, err = client:post_form(DCONNECT_AUTH_URL .. '?isDabLive=1', {
    username = username,
    password = password,
  })

  if err then
    enapter.log('Auth request failed: ' .. err, 'error')
    return false, err
  end

  if response.code ~= 200 then
    enapter.log('Auth failed with status ' .. tostring(response.code), 'error')
    return false, 'http_' .. tostring(response.code)
  end

  -- Parse JSON response
  local auth_data = json.decode(response.body)
  if not auth_data or not auth_data.access_token then
    enapter.log('Invalid auth response', 'error')
    return false, 'invalid_response'
  end

  -- Store token
  access_token = auth_data.access_token
  token_expires_at = current_time + (auth_data.expires_in or 300)

  enapter.log('Authentication successful', 'info')
  return true
end

-- Discover first installation and device
function discover_installation()
  enapter.log('Fetching installation list from DConnect...', 'info')
  local client = get_http_client()

  -- Get installation list
  local request = http.request('GET', DCONNECT_BASE_URL .. '/api/v1/installation')
  request:set_header('Authorization', 'Bearer ' .. access_token)
  request:set_header('Cache-Control', 'no-store, no-cache, max-age=0')

  local response, err = client:do_request(request)
  if err then
    enapter.log('Failed to get installation list: ' .. err, 'error')
    return nil, nil
  end

  if response.code ~= 200 then
    enapter.log('Failed to get installation list: HTTP ' .. tostring(response.code), 'error')
    enapter.log('Response body: ' .. (response.body or 'empty'), 'error')
    return nil, nil
  end

  local install_data = json.decode(response.body)
  if not install_data then
    enapter.log('Failed to parse installation list JSON', 'error')
    return nil, nil
  end

  if not install_data.values or #install_data.values == 0 then
    enapter.log('No installations found in account', 'error')
    return nil, nil
  end

  -- Get first installation
  local installation = install_data.values[1]
  local install_id = installation.installation_id

  enapter.log('Found installation: ' .. (installation.name or install_id), 'info')

  -- Get installation details to find devices
  enapter.log('Fetching devices for installation...', 'info')
  request = http.request('GET', DCONNECT_BASE_URL .. '/api/v1/installation/' .. install_id)
  request:set_header('Authorization', 'Bearer ' .. access_token)

  response, err = client:do_request(request)
  if err or response.code ~= 200 then
    enapter.log('Failed to get installation details', 'error')
    return nil, nil
  end

  local details = json.decode(response.body)
  if not details or not details.dums or #details.dums == 0 then
    enapter.log('No devices found in installation', 'error')
    return nil, nil
  end

  -- Get first device
  local device = details.dums[1]
  local serial = device.serial

  enapter.log('Found device: ' .. (device.name or serial), 'info')

  return install_id, serial
end

-- Load device configuration from DConnect
function load_device_configuration(install_id, serial)
  local client = get_http_client()

  -- Get installation details with device info
  local request = http.request('GET', DCONNECT_BASE_URL .. '/api/v1/installation/' .. install_id)
  request:set_header('Authorization', 'Bearer ' .. access_token)

  local response, config_err = client:do_request(request)
  if config_err then
    enapter.log('Failed to get device configuration: ' .. config_err, 'error')
    return false
  end

  if response.code ~= 200 then
    enapter.log('Failed to get device configuration: HTTP ' .. tostring(response.code), 'error')
    return false
  end

  local install_data = json.decode(response.body)
  if not install_data or not install_data.dums then
    enapter.log('Invalid installation data or no devices found', 'error')
    return false
  end

  enapter.log('Found ' .. tostring(#install_data.dums) .. ' devices in installation', 'info')

  -- Find our device
  for _, device in ipairs(install_data.dums) do
    if device.serial == serial then
      enapter.log('Found device: ' .. (device.name or serial), 'info')
      device_config = device

      -- Get parameter configuration
      if device.configuration_id then
        enapter.log('Loading parameter configuration: ' .. device.configuration_id, 'info')
        local config_ok = load_parameter_config(device.configuration_id)
        if config_ok then
          return true
        else
          enapter.log('Failed to load parameter configuration', 'error')
          return false
        end
      else
        enapter.log('Device has no configuration_id', 'error')
        return false
      end
    end
  end

  enapter.log('Device with serial ' .. serial .. ' not found in installation', 'error')
  return false
end

-- Load parameter configuration
function load_parameter_config(config_id)
  local client = get_http_client()

  local request = http.request('GET', DCONNECT_BASE_URL .. '/api/v1/configuration/' .. config_id)
  request:set_header('Authorization', 'Bearer ' .. access_token)

  local response, param_err = client:do_request(request)
  if param_err then
    enapter.log('Failed to get parameter configuration: ' .. param_err, 'error')
    return false
  end

  if response.code ~= 200 then
    enapter.log('Failed to get parameter configuration: HTTP ' .. tostring(response.code), 'error')
    return false
  end

  local config_data = json.decode(response.body)
  if not config_data then
    enapter.log('Failed to parse parameter configuration JSON', 'error')
    return false
  end

  if not config_data.metadata or not config_data.metadata.params then
    enapter.log('Parameter configuration missing metadata or params', 'error')
    return false
  end

  -- Build parameter map for easier access
  param_map = {}
  local writable_params = {}
  for _, param in ipairs(config_data.metadata.params) do
    param_map[param.name] = param
    -- Log writable parameters (verbose only)
    if param.readonly == false or param.readonly == nil then
      table.insert(writable_params, param.name)
      log_verbose('Writable parameter: ' .. param.name .. ' (type: ' .. tostring(param.type) .. ')')
    end
  end

  enapter.log('Loaded ' .. tostring(#config_data.metadata.params) .. ' parameter definitions', 'info')
  log_verbose('Found ' .. tostring(#writable_params) .. ' writable parameters')
  return true
end

-- Read device status from DConnect
function read_device_status(serial, telemetry, alerts)
  local client = get_http_client()

  local request = http.request('GET', DCONNECT_BASE_URL .. '/dumstate/' .. serial)
  request:set_header('Authorization', 'Bearer ' .. access_token)
  request:set_header('Cache-Control', 'no-store, no-cache, max-age=0')

  local response, err = client:do_request(request)
  if err then
    enapter.log('Failed to get device status: ' .. err, 'error')
    return false
  end

  if response.code == 401 then
    -- Token expired, clear it to force re-authentication
    access_token = nil
    token_expires_at = 0
    return false
  end

  if response.code ~= 200 then
    enapter.log('Failed to get device status: HTTP ' .. tostring(response.code), 'error')
    return false
  end

  local status_data = json.decode(response.body)
  if not status_data then
    enapter.log('Failed to parse status response JSON', 'error')
    enapter.log('Response body: ' .. (response.body or 'empty'), 'error')
    return false
  end

  if not status_data.status then
    enapter.log('Status data missing "status" field', 'error')
    enapter.log('Status data: ' .. json.encode(status_data), 'error')
    return false
  end

  -- Parse the nested status JSON string
  enapter.log('Parsing nested status JSON...', 'info')
  local status = json.decode(status_data.status)
  if not status then
    enapter.log('Failed to parse nested status JSON', 'error')
    enapter.log('Status string: ' .. status_data.status, 'error')
    return false
  end

  -- Log parameter map size
  local param_count = 0
  for _ in pairs(param_map) do param_count = param_count + 1 end
  enapter.log('Parameter map has ' .. tostring(param_count) .. ' entries', 'info')

  -- Decode status values using parameter map
  local decoded_count = 0
  for key, value in pairs(status) do
    local param = param_map[key]
    if param then
      local decoded_value = decode_param_value(value, param)
      if decoded_value ~= nil then
        -- Log each decoded parameter (verbose only)
        log_verbose('Decoded: ' .. key .. ' = ' .. tostring(value) .. ' -> ' .. tostring(decoded_value) .. ' (type: ' .. param.type .. ')')

        -- Map to telemetry fields
        map_status_to_telemetry(key, decoded_value, telemetry)
        decoded_count = decoded_count + 1
      end
    else
      -- Log unmapped parameters for debugging (verbose only)
      log_verbose('Unmapped parameter: ' .. key .. ' = ' .. tostring(value))
    end
  end

  log_verbose('Decoded ' .. tostring(decoded_count) .. ' parameters from status')

  -- Dump all telemetry values before sending (verbose only)
  log_verbose('=== TELEMETRY DUMP ===')
  for k, v in pairs(telemetry) do
    if k ~= 'alerts' then
      log_verbose('  ' .. k .. ' = ' .. tostring(v) .. ' (' .. type(v) .. ')')
    end
  end
  log_verbose('=== END TELEMETRY DUMP ===')

  return true
end

-- Decode parameter value based on type
function decode_param_value(code, param)
  if param.type == 'measure' then
    -- Numeric value with weight scaling
    local weight = param.weight or 1.0
    local value = tonumber(code)
    if value then
      return value * weight
    end
  elseif param.type == 'enum' then
    -- Enum value - lookup in values table
    if param.values then
      for _, v in ipairs(param.values) do
        if tostring(v[1]) == code then
          return v[2] -- Return label
        end
      end
    end
    return code -- Return code if no mapping found
  elseif param.type == 'label' then
    -- String value
    return code
  end

  return code
end

-- Map DConnect status parameters to Enapter telemetry
function map_status_to_telemetry(key, value, telemetry)
  -- Common DAB EsyBox parameter names (may vary by model)
  if key == 'Flow' or key == 'VF_FlowLiter' then
    telemetry.flow_rate = value
  elseif key == 'Pressure' or key == 'VP_PressureBar' then
    telemetry.pressure = value
  elseif key == 'SetPressure' or key == 'SP_SetpointPressureBar' then
    telemetry.pressure_setpoint = value
  elseif key == 'TempMotor' or key == 'TE_HeatsinkTemperatureC' then
    telemetry.temperature = value
  elseif key == 'TempInverter' then
    telemetry.water_temperature = value
  elseif key == 'Power' or key == 'PO_OutputPower' then
    telemetry.power = value
  elseif key == 'TotalEnergy' or key == 'PartialEnergy' then
    telemetry.energy = value
  elseif key == 'StartNumber' then
    telemetry.start_count = value
  elseif key == 'SO_PowerOnSeconds' then
    -- Convert seconds to hours
    telemetry.power_on_hours = value / 3600
  elseif key == 'SO_PumpRunSeconds' then
    -- Convert seconds to hours
    telemetry.run_hours = value / 3600
  elseif key == 'HO_PowerOnHours' then
    -- Only set if value is a number (some models return "h" for hidden)
    if type(value) == 'number' then
      telemetry.power_on_hours = value
    end
  elseif key == 'HO_PumpRunHours' then
    -- Only set if value is a number (some models return "h" for hidden)
    if type(value) == 'number' then
      telemetry.run_hours = value
    end
  elseif key == 'FCt_Total_Delivered_Flow_mc' then
    telemetry.total_flow = value
  elseif key == 'WorkingMode' or key == 'PumpStatus' then
    -- PumpStatus enum: 0=StandBy, 1=Go, 2=Fault, 3=Manual Disable, 4=Test:Go,
    -- 5=Test:StandBy, 6=Warning, 7=Not Configurated, 8-10=Function F1/F3/F4, 11=No State.
    -- Only 'Go' (1) and 'Test Mode: Go' (4) mean the pump is actually running.
    telemetry.pump_running = (value == 'Go' or value == 'Test Mode: Go' or value == 1 or value == '1' or value == 4 or value == '4')
    if value == 'Fault' or value == 2 or value == '2' then
      telemetry.alarm_active = true
    elseif value == 'Manual Disable' or value == 3 or value == '3' then
      telemetry.manually_disabled = true
    end
    last_pump_disabled = telemetry.manually_disabled == true
  elseif key == 'SystemStatus' then
    telemetry.system_status = tostring(value)
    -- Check for alarm conditions (non-zero typically means alarm)
    if type(value) == 'number' and value > 0 then
      telemetry.alarm_active = true
    elseif type(value) == 'string' and value ~= '0' and value ~= 'OK' and value ~= 'SystemOk' then
      telemetry.alarm_active = true
    end
  end
end

-- Process telemetry and set status
function process_telemetry(telemetry, alerts)
  -- Determine overall status
  if telemetry.alarm_active then
    telemetry.status = 'alarm'
    table.insert(alerts, 'pump_alarm')
  elseif telemetry.manually_disabled then
    telemetry.status = 'disabled'
  elseif telemetry.pump_running then
    telemetry.status = 'running'
  else
    telemetry.status = 'idle'
  end
  -- Strip helper field that is not in manifest
  telemetry.manually_disabled = nil

  -- Check temperature alerts
  if telemetry.temperature and telemetry.temperature > 80 then
    table.insert(alerts, 'high_temperature')
  end

  -- Check pressure alerts
  if telemetry.pressure and telemetry.pressure_setpoint then
    if telemetry.pressure < (telemetry.pressure_setpoint * 0.7) then
      table.insert(alerts, 'low_pressure')
    elseif telemetry.pressure > (telemetry.pressure_setpoint * 1.3) then
      table.insert(alerts, 'high_pressure')
    end
  end
end

-- Configuration command handlers
function write_configuration(username, password, installation_id, device_serial, verbose_logging)
  -- Write required fields
  local ok1 = config.write(CONFIG_USERNAME, username)
  local ok2 = config.write(CONFIG_PASSWORD, password)

  -- Write optional fields
  local ok3 = true
  local ok4 = true
  local ok5 = true

  if installation_id and installation_id ~= '' then
    ok3 = config.write(CONFIG_INSTALLATION_ID, installation_id)
  end

  if device_serial and device_serial ~= '' then
    ok4 = config.write(CONFIG_DEVICE_SERIAL, device_serial)
  end

  -- Write verbose logging setting (default to false if nil)
  ok5 = config.write(CONFIG_VERBOSE_LOGGING, verbose_logging or false)

  local result = ok1 and ok2 and ok3 and ok4 and ok5

  if result then
    enapter.log('Configuration saved successfully', 'info')
    -- Clear cached data to force reload
    access_token = nil
    token_expires_at = 0
    device_config = nil
    param_map = {}
  else
    enapter.log('Failed to save configuration', 'error')
  end

  return result
end

function read_configuration()
  local values, err = config.read_all()
  if err then
    enapter.log('Cannot read configuration: ' .. err, 'error')
    return nil, 'cannot_read_config'
  else
    return {
      [CONFIG_USERNAME] = values[CONFIG_USERNAME],
      [CONFIG_PASSWORD] = '***',
      [CONFIG_INSTALLATION_ID] = values[CONFIG_INSTALLATION_ID],
      [CONFIG_DEVICE_SERIAL] = values[CONFIG_DEVICE_SERIAL],
      [CONFIG_VERBOSE_LOGGING] = values[CONFIG_VERBOSE_LOGGING] or false,
    }
  end
end

-- Set device parameter via DConnect API
function set_device_param(param_name, param_value)
  local values, err = config.read_all()
  if err then
    return nil, 'cannot_read_config'
  end

  if not values[CONFIG_DEVICE_SERIAL] then
    return nil, 'not_configured'
  end

  -- Ensure authentication
  local auth_ok, auth_err = ensure_authenticated(values[CONFIG_USERNAME], values[CONFIG_PASSWORD])
  if not auth_ok then
    return nil, 'auth_failed'
  end

  -- Get parameter definition
  local param = param_map[param_name]
  if not param then
    enapter.log('Unknown parameter: ' .. param_name, 'error')
    return nil, 'unknown_parameter'
  end

  -- Encode value
  local encoded_value = encode_param_value(param_value, param)
  if not encoded_value then
    return nil, 'invalid_value'
  end

  -- Send command (POST /dum/{serial} with JSON body {key, value})
  -- Mirrors hass-dab-pumps / pydabpumps change_device_status
  local body = json.encode({
    key = param_name,
    value = encoded_value,
  })

  local client = get_http_client()
  local request = http.request('POST', DCONNECT_BASE_URL .. '/dum/' .. values[CONFIG_DEVICE_SERIAL], body)
  request:set_header('Authorization', 'Bearer ' .. access_token)
  request:set_header('Content-Type', 'application/json')

  local response, err = client:do_request(request)

  if err then
    enapter.log('Failed to set parameter: ' .. err, 'error')
    return nil, 'command_failed'
  end

  if response.code ~= 200 then
    enapter.log('Set parameter failed: HTTP ' .. tostring(response.code), 'error')
    return nil, 'command_failed'
  end

  local result = json.decode(response.body)
  if result and result.res == 'OK' then
    enapter.log('Parameter ' .. param_name .. ' set to ' .. tostring(param_value), 'info')
    return 'ok'
  else
    enapter.log('Set parameter rejected: ' .. (result.msg or 'unknown error'), 'error')
    return nil, 'command_rejected'
  end
end

-- Encode parameter value for sending to DConnect
function encode_param_value(value, param)
  if param.type == 'measure' then
    local weight = param.weight or 1.0
    return tostring(math.floor(value / weight + 0.5))
  elseif param.type == 'enum' then
    -- Find code for value
    if param.values then
      for _, v in ipairs(param.values) do
        if v[2] == value or tostring(v[1]) == tostring(value) then
          return tostring(v[1])
        end
      end
    end
    return tostring(value)
  elseif param.type == 'label' then
    return tostring(value)
  end

  return tostring(value)
end

-- Pump control commands (these map to DConnect parameters)
function start_pump()
  enapter.log('start_pump called', 'info')

  if last_pump_disabled == false then
    enapter.log('Pump already enabled, skipping API call', 'info')
    return 'ok'
  end

  -- PumpDisable enum: 0='--', 1='Enable', 2='Disable'
  local result, err = set_device_param('PumpDisable', 1)

  if not result then
    enapter.log('start_pump failed: ' .. tostring(err), 'error')
  else
    last_pump_disabled = false
    enapter.log('Pump started successfully', 'info')
  end

  return result, err
end

function stop_pump()
  enapter.log('stop_pump called', 'info')

  if last_pump_disabled == true then
    enapter.log('Pump already disabled, skipping API call', 'info')
    return 'ok'
  end

  -- PumpDisable enum: 0='--', 1='Enable', 2='Disable'
  local result, err = set_device_param('PumpDisable', 2)

  if not result then
    enapter.log('stop_pump failed: ' .. tostring(err), 'error')
  else
    last_pump_disabled = true
    enapter.log('Pump stopped successfully', 'info')
  end

  return result, err
end

-- Start the main function
main()
