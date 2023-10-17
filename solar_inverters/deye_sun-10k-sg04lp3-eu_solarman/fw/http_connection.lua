local SolarmanHTTP = {}

local json = require('json')
local net_url = require('net.url')
local sha256 = require('hashings.sha256')

function SolarmanHTTP.new(app_id, app_secret, email, password, device_sn, org_name, optional)
  assert(type(app_id) == 'string', 'app_id (arg #1) must be string, given: ' .. inspect(app_id))
  assert(
    type(app_secret) == 'string',
    'app_secret (arg #2) must be string, given: ' .. inspect(app_secret)
  )
  assert(type(email) == 'string', 'email (arg #3) must be string, given: ' .. inspect(email))
  assert(
    type(password) == 'string',
    'password (arg #4) must be string, given: ' .. inspect(password)
  )
  assert(
    type(device_sn) == 'string',
    'device_sn (arg #5) must be string, given: ' .. inspect(device_sn)
  )
  assert(
    type(org_name) == 'string',
    'org_name (arg #6) must be string, given: ' .. inspect(org_name)
  )

  local self = setmetatable({}, { __index = SolarmanHTTP })

  if email ~= nil then
    self.email = email
  elseif optional.username ~= nil then
    self.username = optional.username
  elseif optional.mobile ~= nil then
    if optional.coutry_code ~= nil then
      self.country_code = optional.coutry_code
    else
      return 'country code must be provided along with mobile number'
    end
  else
    return nil, 'one of: email, username or mobile with country code must be provided'
  end

  self.password = password
  self.app_secret = app_secret
  self.app_id = app_id
  self.device_sn = device_sn
  self.org_name = org_name

  self.url = 'https://globalapi.solarmanpv.com/'
  self.client = http.client({ timeout = 5 })

  return self
end

function SolarmanHTTP:process_unauthorized(request_type, headers, url, body)
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

function SolarmanHTTP:process_authorized(request_type, url, body)
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

function SolarmanHTTP:set_token()
  local body = {}

  if self.email ~= nil then
    body.email = self.email
  elseif self.username ~= nil then
    body.username = self.username
  elseif self.mobile ~= nil then
    if self.country_code ~= nil then
      body.mobile = self.mobile
      body.countryCode = self.country_code
    else
      return 'country code must be provided along with mobile number'
    end
  else
    return 'one of: email, username or mobile with country code must be provided'
  end

  body.appSecret = self.app_secret
  body.orgId = self.org_id
  body.password = string.lower(sha256:new(self.password):hexdigest())

  local url = net_url.parse(self.url) / 'account' / 'v1.0' / 'token'
  url:setQuery({ appId = self.app_id })

  local headers = {}
  headers['Content-Type'] = 'application/json'

  local response, err = self:process_unauthorized('POST', headers, tostring(url), json.encode(body))
  if err then
    return 'set_token failed: ' .. tostring(err)
  end

  if response ~= nil then
    if response['success'] == false then
      return response['msg']
    end
    if self.access_token ~= response['access_token'] and self.access_token ~= nil then
      enapter.log('Bussiness access tokens are obtained', 'info')
    else
      enapter.log('Tokens are obtained', 'info')
    end
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

function SolarmanHTTP:bussiness_relation()
  local url = net_url.parse(self.url) / 'account' / 'v1.0' / 'info'

  local body = ''

  local response, err = self:process_authorized('POST', tostring(url), body)

  if err then
    return nil, 'bussiness_relation failed: ' .. tostring(err)
  end

  if response ~= nil then
    if response['success'] then
      if response['orgInfoList'] ~= nil then
        for _, org in pairs(response['orgInfoList']) do
          if org['companyName'] == self.org_name then
            self.org_id = org['companyId']
            break
          end
        end
      else
        return 'empty orgInfoList'
      end
    else
      return response['msg']
    end
  else
    return 'no response'
  end
end

function SolarmanHTTP:get_realtime_data()
  local url = net_url.parse(self.url) / 'device' / 'v1.0' / 'currentData'

  local body = json.encode({
    deviceSn = self.device_sn,
  })

  local response, err = self:process_authorized('POST', tostring(url), body)

  if err then
    return nil, 'get_realtime_data failed: ' .. tostring(err)
  end

  local function map_by_key(t)
    local tt = {}
    for _, el in pairs(t) do
      if tonumber(el.value) then
        tt[el.key] = tonumber(el.value)
      else
        tt[el.key] = el.value
      end
    end
    return tt
  end

  local telemetry = {}
  if response ~= nil then
    if response['success'] then
      if response['dataList'] ~= nil then
        local metrics = map_by_key(response['dataList'])
        telemetry['DV1'] = metrics['DV1']
        telemetry['DC1'] = metrics['DC1']
        telemetry['DP1'] = metrics['DP1']
        telemetry['DV2'] = metrics['DV2']
        telemetry['DC2'] = metrics['DC2']
        telemetry['DP2'] = metrics['DP2']
        telemetry['S_P_T'] = metrics['S_P_T']
        telemetry['G_V_L1'] = metrics['G_V_L1']
        telemetry['G_C_L1'] = metrics['G_C_L1']
        telemetry['G_P_L1'] = metrics['G_P_L1']
        telemetry['G_V_L2'] = metrics['G_V_L2']
        telemetry['G_C_L2'] = metrics['G_C_L2']
        telemetry['G_P_L2'] = metrics['G_P_L2']
        telemetry['G_V_L3'] = metrics['G_V_L3']
        telemetry['G_C_L3'] = metrics['G_C_L3']
        telemetry['G_P_L3'] = metrics['G_P_L3']
        telemetry['PG_F1'] = metrics['PG_F1']
        telemetry['PG_Pt1'] = metrics['PG_Pt1']
        telemetry['CT1_P_E'] = metrics['CT1_P_E']
        telemetry['CT2_P_E'] = metrics['CT2_P_E']
        telemetry['CT3_P_E'] = metrics['CT3_P_E']
        telemetry['CT_T_E'] = metrics['CT_T_E']
        telemetry['L_F'] = metrics['L_F']
        telemetry['LPP_A'] = metrics['LPP_A']
        telemetry['LPP_B'] = metrics['LPP_B']
        telemetry['LPP_C'] = metrics['LPP_C']
        telemetry['LPP_C'] = metrics['LPP_C']
        telemetry['E_Puse_t1'] = metrics['E_Puse_t1']
        telemetry['B_V1'] = metrics['B_V1']
        telemetry['B_C1'] = metrics['B_C1']
        telemetry['B_P1'] = metrics['B_P1']
        telemetry['B_left_cap1'] = metrics['B_left_cap1']
        telemetry['ST_PG1'] = metrics['ST_PG1']
        telemetry['B_ST1'] = metrics['B_ST1']
        telemetry['Etdy_use1'] = metrics['Etdy_use1']
        telemetry['Etdy_dcg1'] = metrics['Etdy_dcg1']
        telemetry['Etdy_ge1'] = metrics['Etdy_ge1']
        telemetry['GRID_RELAY_ST1'] = metrics['GRID_RELAY_ST1']
        telemetry['status'] = 'ok'
        telemetry['alerts'] = {}
      else
        telemetry['status'] = 'warning'
        telemetry['alerts'] = { 'no_data' }
      end
    else
      telemetry['status'] = 'warning'
      telemetry['alerts'] = { 'invalid_request' }
      return telemetry, response['msg']
    end
  else
    telemetry['status'] = 'warning'
    telemetry['alerts'] = { 'no_response' }
  end

  return telemetry, nil
end

return SolarmanHTTP
