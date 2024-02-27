local voltronic = require('voltronic')
local moving_average = require('moving_average')
local commands = require('commands')

local device_protocol = commands.device_protocol
local serial_number = commands.serial_number
local firmware_version = commands.firmware_version
local device_rating_info = commands.device_rating_info
local general_parameters = commands.general_parameters
local device_warning_status = commands.device_warning_status

local parser = {}

function parser:get_protocol_version()
  local result, data = voltronic:run_with_cache(device_protocol.command)
  if result then
    return data, nil
  else
    return nil, 'no_data'
  end
end

function parser:get_serial_number()
  local result, data = voltronic:run_with_cache(serial_number.command)
  if result then
    return data, nil
  else
    return nil, 'no_data'
  end
end

function parser:get_firmware_version()
  local result, data = voltronic:run_with_cache(firmware_version.command)
  if result then
    return data, nil
  else
    return nil, 'no_data'
  end
end

function parser:get_device_general_status_params()
  local data = voltronic:run_command(general_parameters.command)
  if data then
    local telemetry = {}
    data = split(data)

    for name, index in pairs(general_parameters.data) do
      telemetry[name] = tonumber(data[index])
    end

    telemetry['battery_volt'] = parser:get_battery_voltage(telemetry['battery_volt'])
    -- telemetry['pv_input_power'] = tonumber(data[general_parameters.data.pv_input_amp])
    --   * tonumber(data[general_parameters.data.pv_input_volt])
    return telemetry, nil
  else
    return nil, 'no_data'
  end
end

function parser:get_device_rating_info()
  local data = voltronic:run_command(device_rating_info.command)
  local telemetry = {}
  if data then
    for name, index in pairs(device_rating_info.data) do
      telemetry[name] = tonumber(split(data)[index])
    end

    telemetry = parser:get_priorities(telemetry)

    return telemetry, nil
  else
    return nil, 'no_data'
  end
end

function parser:get_device_alerts()
  local data = voltronic:run_command(device_warning_status.command)
  if data then
    local alerts = {}
    for alert, pos in pairs(device_warning_status.general) do
      if string.sub(data, pos, pos) == '1' then
        table.insert(alerts, alert)
      end
    end

    return alerts
  else
    enapter.log('Warning status failure', 'error')
    return nil
  end
end

function parser:get_battery_voltage(voltage)
  if voltage then
    moving_average:add_to_table(voltage)
    return moving_average:get_value()
  else
    moving_average.table = {}
    enapter.log('No battery voltage', 'error')
    return nil
  end
end

function split(str, sep)
  if sep == nil then
    sep = '%s'
  end

  local t = {}
  for part in string.gmatch(str, '([^' .. sep .. ']+)') do
    table.insert(t, part)
  end

  return t
end

return parser
