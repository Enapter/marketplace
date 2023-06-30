local SmappeeHTTP = {}

local json = require('json')
local net_url = require('net.url')

function SmappeeHTTP.new(username, password, client_secret, client_id, location_name)
  assert(
    type(username) == 'string',
    'username (arg #1) must be string, given: ' .. inspect(username)
  )
  assert(
    type(password) == 'string',
    'password (arg #2) must be string, given: ' .. inspect(password)
  )
  assert(
    type(client_secret) == 'string',
    'client_secret (arg #3) must be string, given: ' .. inspect(client_secret)
  )
  assert(
    type(client_id) == 'string',
    'client_id (arg #4) must be string, given: ' .. inspect(client_id)
  )

  local self = setmetatable({}, { __index = SmappeeHTTP })

  self.username = username
  self.password = password
  self.client_secret = client_secret
  self.client_id = client_id
  self.location_name = location_name

  self.url = net_url.parse('https://app1pub.smappee.net/dev/v3')
  self.client = http.client({ timeout = 5 })

  return self
end

function SmappeeHTTP:process_unauthorized(request_type, headers, url, body)
  local request = http.request(request_type, url, body)

  if headers ~= nil then
    for name, value in pairs(headers) do
      request:set_header(name, value)
    end
  end

  local response, err = self.client:do_request(request)

  if err then
    return nil, err
  elseif response.code ~= 200 then
    return nil, 'non-OK code: ' .. tostring(response.code)
  else
    return json.decode(response.body), nil
  end
end

function SmappeeHTTP:process_authorized(request_type, url, body)
  local request = http.request(request_type, url, body)

  request:set_header('Authorization', 'Bearer ' .. self.access_token)
  request:set_header('Content-Type', 'application/json')

  local response, err = self.client:do_request(request)

  if err then
    return nil, err
  elseif response.code ~= 200 then
    return nil, 'non-OK code: ' .. tostring(response.code)
  else
    return json.decode(response.body), nil
  end
end

function SmappeeHTTP:set_token()
  local body = {
    grant_type = 'password',
    client_id = self.client_id,
    client_secret = self.client_secret,
    username = self.username,
    password = self.password,
  }

  local headers = {}
  headers['Content-Type'] = 'application/x-www-form-urlencoded'

  local response, err = self:process_unauthorized(
    'POST', headers, self.url .. 'oauth2/token', body
  )
  if err then
    return 'set_token failed: ' .. tostring(err)
  end

  if response ~= nil then
    self.access_token = response['access_token']
    self.new_token = response['refresh_token']
    if response['expires_in'] == nil then
      return 'no_expire_time'
    else
      self.expires = response['expires_in'] + os.time()
    end
  else
    return 'no_tokens_data'
  end
end

function SmappeeHTTP:refresh_token()
  local body = {
    grant_type = 'refresh_token',
    client_id = self.client_id,
    client_secret = self.client_secret,
    refresh_token = self.new_token,
  }

  local headers = {}
  headers['Content-Type'] = 'application/x-www-form-urlencoded'

  local response, err = self:process_unauthorized(
    'POST', headers, self.url .. 'oauth2/token', body
  )
  if err then
    return 'resfresh_token failed: ' .. tostring(err)
  end

  if response ~= nil then
    self.access_token = response['access_token']
    self.new_token = response['refresh_token']
    if response['expires_in'] == nil then
      return 'no_expire_time'
    else
      self.expires = response['expires_in'] + os.time()
    end
  else
    return 'no_refresh_tokens_data'
  end
end

function SmappeeHTTP:set_service_locations()
  local response, err = self:process_authorized('GET', self.url .. 'servicelocation')
  if err then
    return 'set_service_locations failed: ' .. tostring(err)
  end

  if response ~= nil then
    self.service_locations = response['serviceLocations']
  else
    return 'no_data'
  end
end

function SmappeeHTTP:set_service_location_id()
  local err = self:set_service_locations()
  if err == nil then
    if type(self.service_locations) == 'table' then
      for _, location in ipairs(self.service_locations) do
        for k, v in pairs(location) do
          if k == 'name' and v == self.location_name then
            self.service_location_id = location['serviceLocationId']
          end
        end
      end
      if not self.service_location_id then
        return 'no_service_location_id'
      end
    else
      return 'service_locations_invalid_type'
    end
  else
    return tostring(err)
  end
end

function SmappeeHTTP:set_metering_configuration()
  local response, err = self:process_authorized(
    'GET',
    self.url .. 'servicelocation/' .. self.service_location_id .. '/meteringconfiguration'
  )
  if err then
    return 'set_metering_configuration failed: ' .. tostring(err)
  end

  if response ~= nil then
    local inputs = {}

    for i, input in ipairs(response['measurements']) do
      if not inputs[i] then
        inputs[i] = {}
      end
      inputs[i]['name'] = input['name']
      for _, val in ipairs(input['channels']) do
        if not inputs[i]['indexes'] then
          inputs[i]['indexes'] = {}
        end
        inputs[i]['indexes'][val['phase']] = val['consumptionIndex']
      end
    end

    self.inputs = inputs
  else
    return 'no_metering_data'
  end
end

function SmappeeHTTP:get_electricity_consumption(from, to)
  local url = self.url / 'servicelocation' / self.service_location_id / 'consumption'
  url:setQuery({ aggregation = 1, from = from, to = to })

  local response, err = self:process_authorized('GET', url)

  if err then
    return nil, 'get_electricity_consumption failed: ' .. tostring(err)
  end

  local err = self:set_metering_configuration()
  if err ~= nil then
    return nil, err
  end

  local telemetry = {}
  if response ~= nil then
    if response['serviceLocationId'] == self.service_location_id then
      local data = response['consumptions'][1]
      if data ~= nil then
        telemetry['voltage1'] = data['lineVoltages'][1]
        telemetry['voltage2'] = data['lineVoltages'][2]
        telemetry['voltage3'] = data['lineVoltages'][3]
        telemetry['consumption_power'] = data['consumption']

        for i, input in ipairs(self.inputs) do
          for phase, index in pairs(input['indexes']) do
            telemetry['current' .. i .. '_' .. phase] = data['current'][index + 1]
            telemetry['active' .. i .. '_' .. phase] = data['active'][index + 1]
          end
        end
        telemetry['status'] = 'ok'
      end
    else
      telemetry['status'] = 'warning'
      telemetry['alerts'] = { 'invalid_service_location_id' }
    end
  end
  telemetry['status'] = 'warning'
  telemetry['alerts'] = { 'no_data' }

  return telemetry, nil
end

return SmappeeHTTP
