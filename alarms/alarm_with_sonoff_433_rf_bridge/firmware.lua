local config = require('enapter.ucm.config')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS_CONFIG = 'ip_address'
IP_PORT_CONFIG = 'ip_port'
DEVICEID_CONFIG = 'device_id'
REMOTE_NUMBER_CONFIG = 'remote_number'

-- main() sets up scheduled functions and command handlers,
-- it's called explicitly at the end of the file
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [IP_ADDRESS_CONFIG] = { type = 'string', required = true },
    [IP_PORT_CONFIG] = { type = 'string', required = true },
    [DEVICEID_CONFIG] = { type = 'string', required = true },
    [REMOTE_NUMBER_CONFIG] = { type = 'string', required = true },
  })

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
    brandName = jb['brandName']
    productModel = jb['productModel']
    chipid = jb['extra']['extra']['chipid']
  end

  enapter.send_properties({
    vendor = brandName,
    model = productModel,
    serial_number = chipid,
  })
end

-- holds global array of alerts that are currently active
active_alerts = {}
detector_triggered = false
rfTrig = nil

function send_telemetry()
  local telemetry = {}
  local jb, err = get_data()

  if err then
    active_alerts = { err }
  else
    if jb['online'] then
      telemetry.sonoff_status = 'Online'
    else
      telemetry.sonoff_status = 'Offline'
      telemetry.alerts = { 'sonoff_offline' }
      enapter.send_telemetry(telemetry)
      return
    end

    if detector_triggered then
      telemetry.status = 'triggered'
    else
      telemetry.status = 'ok'
      active_alerts = {}
    end

    local remote = storage.read(REMOTE_NUMBER_CONFIG)
    local detector = 'rfTrig' .. tostring(tonumber(remote) - 1)

    if rfTrig == nil then
      rfTrig = jb['params'][detector]
    end

    if rfTrig ~= jb['params'][detector] then
      for k, v in pairs(jb['tags']['zyx_info']) do
        if k == tonumber(remote) then
          detector_triggered = true
          active_alerts = { underscore(tostring(v['name'])) }
        end
      end
      rfTrig = jb['params'][detector]
    end

    rfTrig = jb['params'][detector]

    telemetry.last_triggered = jb['params'][detector]
    telemetry.rssi = jb['params']['rssi']
  end

  telemetry.alerts = active_alerts
  enapter.send_telemetry(telemetry)
end

function get_data()
  local json = require('json')
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local ip_address = values[IP_ADDRESS_CONFIG]
    local ip_port = values[IP_PORT_CONFIG]
    local device_id = values[DEVICEID_CONFIG]
    local remote_number = values[REMOTE_NUMBER_CONFIG]

    if not ip_address or not ip_port or not device_id or not remote_number then
      return nil, 'not_configured'
    end

    local response, err = http.get('http://' .. ip_address .. ':' .. ip_port)

    if err then
      enapter.log('Cannot do request: ' .. err, 'error')
      return nil, 'no_connection'
    elseif response.code ~= 200 then
      enapter.log('Request returned non-OK code: ' .. response.code, 'error')
      return nil, 'wrong_response'
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

function underscore(str)
  local result = string.gsub(str, '(%s)', '_')
  return result
end

main()
