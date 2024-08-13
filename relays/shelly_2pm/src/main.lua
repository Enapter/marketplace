local config = require('enapter.ucm.config')
local json = require('json')
local sha2 = require('sha2')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS_CONFIG = 'address'
PASSWORD = 'password'

local CONNECTION = {}
local TTY

function get_auth(response, password)
  if response.headers['Www-Authenticate'] and password then
    math.randomseed(os.time())
    math.random()
    math.random()
    math.random()
    local cnonce = math.random(99999999)
    local www_values = response.headers['Www-Authenticate'][1]
    local realm = www_values:match('realm="([^"]+)"')
    local nonce = www_values:match('nonce="([^"]+)"')
    local ha1 = sha2.sha256('admin:' .. realm .. ':' .. password)
    local ha2 = sha2.sha256('dummy_method:dummy_uri')
    local result =
      sha2.sha256(tostring(ha1) .. ':' .. tostring(nonce) .. ':1:' .. tostring(cnonce) .. ':auth:' .. tostring(ha2))
    local auth = '"auth": { "realm":"'
      .. realm
      .. '", "username":"admin", "nonce":"'
      .. nonce
      .. '", "nc":"1", "qop":"auth", "cnonce":"'
      .. cnonce
      .. '", "response":"'
      .. result
      .. '", "algorithm": "SHA-256"}'
    return auth, nil
  else
    return nil, 'No data available to make auth data'
  end
end

function get_device_info()
  -- Password is not needed to access this endpoint
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local ip_address = values[IP_ADDRESS_CONFIG]

    if not ip_address then
      return nil, 'not_configured'
    end

    local response, err = http.get('http://' .. ip_address .. '/rpc/Shelly.GetDeviceInfo')

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
end

function get_device_status()
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local ip_address = values[IP_ADDRESS_CONFIG]
    local password = values[PASSWORD]

    if not ip_address then
      return nil, 'not_configured'
    end

    local request, err =
      http.request('POST', 'http://' .. ip_address .. '/rpc','{"id":1, "method":"Shelly.GetStatus"}')
    local client = http.client({ timeout = 5 })
    local response, err = client:do_request(request)

    if err then
      enapter.log('Cannot do request: ' .. err, 'error')
      return nil, 'no_connection'
    elseif response.code == 401 then
      if not password then
        return nil, 'not_configured'
      end

      local auth = get_auth(response, password)
      if auth then
        local request, err = http.request(
          'POST',
          'http://' .. ip_address .. '/rpc',
          '{"id":1, "method":"Shelly.GetStatus",' .. auth .. '}'
        )
        local client = http.client({ timeout = 5 })
        local response, err = client:do_request(request)

        if response.code == 401 then
          enapter.log('Request returned non-OK code: ' .. response.code, 'error')
          return nil, 'wrong_password'
        elseif response.code ~= 200 then
          enapter.log('Request returned non-OK code: ' .. response.code, 'error')
          return nil, 'wrong_request'
        else
          local jb = json.decode(response.body)
          return jb, nil
        end
      else
        return nil, 'wrong_request'
      end
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: ' .. response.code, 'error')
      return nil, 'wrong_request'
    else
      local jb = json.decode(response.body)
      return jb, nil
    end
  end
end

function switch_on(switch, ctx)
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    ctx.error(tostring(err))
    return false, 'cannot_read_config'
  else
    local ip_address = values[IP_ADDRESS_CONFIG]
    local password = values[PASSWORD]

    if not ip_address then
      ctx.error(tostring('not_configured'))
      return false, 'not_configured'
    end

    local request, err = http.request(
      'POST',
      'http://' .. ip_address .. '/rpc',
      '{"id":1, "method":"Switch.Set", "params":{"id":' .. switch .. ',"on":true}}')
    local client = http.client({ timeout = 5 })
    local response, err = client:do_request(request)

    if err then
      enapter.log('Cannot do request: ' .. err, 'error')
      ctx.error(tostring(err))
      return false, 'no_connection'
    elseif response.code == 401 then
      if not password then
        return false, 'not_configured'
      end

      local auth = get_auth(response, password)
      if auth then
        local request, err = http.request(
          'POST',
          'http://' .. ip_address .. '/rpc',
          '{"id":1, "method":"Switch.Set", "params":{"id":' .. switch .. ',"on":true}, ' .. auth .. '}'
        )
        local client = http.client({ timeout = 5 })
        local response, err = client:do_request(request)

        if response.code == 401 then
          ctx.error('Request returned non-OK code: ' .. response.code, 'error')
          return false, 'wrong_password'
        elseif response.code ~= 200 then
          ctx.error('Request returned non-OK code: ' .. response.code, 'error')
          return false, 'wrong_request'
        else
          return true, nil
        end
      else
        return false, 'wrong_request'
      end
    elseif response.code ~= 200 then
      ctx.error('Request returned non-OK code: ' .. response.code, 'error')
      return false, 'wrong_request'
    else
      return true, nil
    end
  end
end

function switch_off(switch, ctx)
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    ctx.error(tostring(err))
    return false, 'cannot_read_config'
  else
    local ip_address = values[IP_ADDRESS_CONFIG]
    local password = values[PASSWORD]

    if not ip_address then
      ctx.error(tostring('not_configured'))
      return false, 'not_configured'
    end

    local request, err = http.request(
      'POST',
      'http://' .. ip_address .. '/rpc',
      '{"id":1, "method":"Switch.Set","params":{"id":' .. switch .. ',"on":false}'
    )
    local client = http.client({ timeout = 5 })
    local response, err = client:do_request(request)

    if err then
      enapter.log('Cannot do request: ' .. err, 'error')
      ctx.error(tostring(err))
      return false, 'no_connection'
    elseif response.code == 401 then
      if not password then
        return false, 'not_configured'
      end

      local auth = get_auth(response, password)
      if auth then
        local request, err = http.request(
          'POST',
          'http://' .. ip_address .. '/rpc',
          '{"id":1, "method":"Switch.Set","params":{"id":' .. switch .. ',"on":false}, ' .. auth .. '}'
        )
        local client = http.client({ timeout = 5 })
        local response, err = client:do_request(request)

        if response.code == 401 then
          ctx.error('Request returned non-OK code: ' .. response.code, 'error')
          return false, 'wrong_password'
        elseif response.code ~= 200 then
          ctx.error('Request returned non-OK code: ' .. response.code, 'error')
          return false, 'wrong_request'
        else
          return true, nil
        end
      else
        return false, 'wrong_request'
      end
    elseif response.code ~= 200 then
      ctx.error('Request returned non-OK code: ' .. response.code, 'error')
      return false, 'wrong_request'
    else
      return true, nil
    end
  end
end

function main()
  config.init({
    [IP_ADDRESS_CONFIG] = { type = 'string', required = true },
    [PASSWORD] = { type = 'string', defult = '' },
  })
  scheduler.add(1000, send_properties)
  scheduler.add(1000, send_telemetry)
  -- Register command handlers
  enapter.register_command_handler('switch_on_0', function(ctx)
    switch_on(0, ctx)
  end)
  enapter.register_command_handler('switch_off_0', function(ctx)
    switch_off(0, ctx)
  end)
  enapter.register_command_handler('switch_on_1', function(ctx)
    switch_on(1, ctx)
  end)
  enapter.register_command_handler('switch_off_1', function(ctx)
    switch_off(1, ctx)
  end)
end

function send_properties()
  local data, err = get_device_info()

  if not err then
    enapter.send_properties({
      vendor = 'Shelly',
      model = data['model'],
      mac = data['mac'],
      ver = data['ver'],
    })
  end
end

active_alerts = {}

function send_telemetry()
  local telemetry = {}
  local status = 'Offline'

  local data, err = get_device_status()

  if err then
    active_alerts = { err }
  else
    active_alerts = {}
    status = 'Online'
    telemetry['rssi'] = data['result']['wifi']['rssi']

    for i = 0, 1, 1 do
      if data['result']['switch:' .. i]['output'] then
        telemetry['switch' .. i] = 'On'
      else
        telemetry['switch' .. i] = 'Off'
      end

      telemetry['voltage' .. i] = data['result']['switch:' .. i]['voltage']
      telemetry['current' .. i] = data['result']['switch:' .. i]['current']
      telemetry['power' .. i] = data['result']['switch:' .. i]['apower']

      if data['result']['input:' .. i]['state'] then
        telemetry['input' .. i] = 'On'
      else
        telemetry['input' .. i] = 'Off'
      end
    end
  end

  telemetry['alerts'] = active_alerts
  telemetry['status'] = status

  enapter.send_telemetry(telemetry)
end

main()
