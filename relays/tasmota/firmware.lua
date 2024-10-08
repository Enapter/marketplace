json = require("json")
connection = http.client({timeout = 10})
local config = require('enapter.ucm.config')

-- The addres is the local IP adres of the tasmota device
-- The password is optional it is only needed in case the web-admin pasword is set on the tasmota device, be aware that this is only a very thin extra layer of security and you should not purely rely on that.
ADDRESS = 'address'
PASSWORD = 'password'

function main()
  config.init({
    [PASSWORD]  = {type = 'string', required = false},
    [ADDRESS] = { type = 'string', required = true, default = '127.0.0.1' },
  })
  enapter.register_command_handler("turn_on", function() return control_device("Power%20On") end)
  enapter.register_command_handler("turn_off", function() return control_device("Power%20Off") end)
  enapter.register_command_handler("tasmota_command", tasmota_command)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function tasmota_command(ctx, args)
  enapter.log("command arrived " .. args["command"])
  return control_device(args["command"])
end

function send_properties()
  enapter.send_properties({
     model = 'TASMOTA'
  })
end

-- Sends status, change for your specific requirements
function send_telemetry()
    local tasmota_status = control_device("Status0")
    local decoded_status = json.decode(tasmota_status) -- The status line contains all kind of info
    local power = decoded_status.Status.Power -- Access the "Power" field
    local power_bool = (power == 1)
    enapter.send_telemetry({is_on = power_bool})
end

-- Generic function to control the device
function control_device(command)
  local config_values, err = config.read_all()

  local url = "http://" .. config_values[ADDRESS] .. "/cm?cmnd=" .. command

  -- Add user and password only if password is provided
  if config_values[PASSWORD] and config_values[PASSWORD] ~= "" then
    url = url .. "&user=admin&password=" .. config_values[PASSWORD]
  end

  local response, error = connection:get(url)

  if error then
    enapter.log("HTTP request failed: " .. error)
    return error
  end

  if response and response.body then
    enapter.log("Result for command (".. command .. "): " .. response.body)
    return response.body;
  else
    enapter.log("No response body or invalid response format for command: " .. command)
  end
end

main()
