-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter


json = require("json")
client = http.client({timeout = 10})

function get_juicebox_token(account_token,juicebox_unit_id)

  local json_body = '{"cmd":"get_account_units","device_id":"vucm","account_token":"' .. account_token .. '"}'

  local response, err = client:post('https://jbv1-api.emotorwerks.com/box_pin', 'application/json', json_body)
  
  if err then
    enapter.log('Cannot do request: '..err, 'error')
  elseif response.code ~= 200 then
    enapter.log('Request returned non-OK code: '..response.code, 'error')
  else
    local t = json.decode(response.body)
    for k,v in pairs(t['units']) do
      if v['unit_id'] == juicebox_unit_id then
        return v['token']
      end
    end
  end
end

function has_value (tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
  end
  return false
end

function get_juicebox_state(account_token,juicebox_token)

  local json_body = '{"cmd":"get_state","device_id":"vucm","account_token":"'.. account_token ..'", "token":"'.. juicebox_token ..'"}'

  local response, err = client:post('https://jbv1-api.emotorwerks.com/box_api_secure', 'application/json', json_body)
    
  if err then
    enapter.log('Cannot do request: '..err, 'error')
  elseif response.code ~= 200 then
    enapter.log('Request returned non-OK code: '..response.code, 'error')
  else
    return json.decode(response.body)
  end
end

-- main() sets up scheduled functions and command handlers,
-- it's called explicitly at the end of the file
function main()
  -- Send properties every 30s
  scheduler.add(30000, send_properties)

  -- Send telemetry every 1s
  scheduler.add(1000, send_telemetry)
  
  -- Register command handlers
end





function send_properties()
  enapter.send_properties({
    vendor = 'Enel',
    model = 'JuiceBox 32'
  })
end

-- holds global array of alerts that are currently active
active_alerts = {}

function send_telemetry()

  local jb_account_token = "57525119-04f9-4a78-9055-28805a03cf6b"
  local jb_unit_id = "0910042001150513726321610608"
  local jb_token = get_juicebox_token (jb_account_token, jb_unit_id)
  jb = get_juicebox_state(jb_account_token,jb_token)


  local telemetry = {}

  telemetry.alerts = active_alerts
  telemetry.serial_number = jb_unit_id
  telemetry.status = jb["state"]
  telemetry.current = jb["charging"]["amps_current"]
  telemetry.chargetime = jb["charging"]["seconds_charging"]
  telemetry.chargeenergy = jb["charging"]["wh_energy"]
  telemetry.voltage = jb["charging"]["voltage"]
  telemetry.frequency = jb["frequency"] / 100
  telemetry.power = jb["charging"]["watt_power"] / 1000
  telemetry.temperature = jb["temperature"]
  telemetry.totalenergy = jb["lifetime"]["wh_energy"] / 1000
  
  if telemetry.status == "charging" then
    telemetry.charging_time_left = math.floor(jb["charging_time_left"] / 60)
  else
    telemetry.charging_time_left = 0
  end

  if not has_value(active_alerts, "charging_started") and telemetry.status == "charging" then
    active_alerts = {"charging_started"}
  end
  
  if has_value(active_alerts, "charging_started") and telemetry.status == "plugged" then
    active_alerts = {"charging_stopped"}
  end

  if telemetry.status == "standby" then
    active_alerts = { }
  end
    
  enapter.send_telemetry(telemetry)
end

main()
