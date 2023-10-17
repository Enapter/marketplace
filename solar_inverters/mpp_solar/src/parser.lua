local mpp_solar = require('mpp_solar')
local moving_average = require('moving_average')
local commands = require('commands')

local device_rating_info = commands.device_rating_info
local firmware_version = commands.firmware_version
local device_protocol = commands.device_protocol
local general_parameters = commands.general_parameters
local device_mode = commands.device_mode
local output_mode = commands.output_mode
local device_warning_status = commands.device_warning_status
local serial_number = commands.serial_number
local priorities = commands.set_priorities
local device_model = commands.device_model

local parser = {}

function parser:get_device_model()
  local result, data = mpp_solar:run_with_cache(device_rating_info.command)
  if result then
    return split(data)[device_rating_info.device_model_data] .. 'VA', nil
  else
    return nil, 'no_data'
  end
end

function parser:get_firmware_version()
  local result, data = mpp_solar:run_with_cache(firmware_version.command)
  if result then
    return data, nil
  else
    return nil, 'no_data'
  end
end

function parser:get_protocol_version()
  local result, data = mpp_solar:run_with_cache(device_protocol.command)
  if result then
    return data, nil
  else
    return nil, 'no_data'
  end
end

function parser:get_device_general_status_params()
  local data = mpp_solar:run_command(general_parameters.command)
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
  local data = mpp_solar:run_command(device_rating_info.command)
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

function parser:get_priorities(telemetry)
  for name, value in pairs(priorities.charger.values) do
    if value == telemetry['charger_source_priority'] then
      telemetry['charger_source_priority'] = name
    end
  end

  for name, value in pairs(priorities.output.values) do
    if value == telemetry['output_source_priority'] then
      telemetry['output_source_priority'] = name
    end
  end

  return telemetry
end

function parser:get_device_mode()
  local data = mpp_solar:run_command(device_mode.command)
  if not data then
    return 'unknown'
  else
    return device_mode.values[data]
  end
end

function parser:get_device_alerts()
  local data = mpp_solar:run_command(device_warning_status.command)
  if data then
    local alerts = {}
    for alert, pos in pairs(device_warning_status.general) do
      if string.sub(data, pos, pos) == '1' then
        table.insert(alerts, alert)
      end
    end

    local index = device_warning_status.general.fault_flag
    local warning_flag = string.sub(data, index, index) == '1' and '' or '_w'

    for alert, pos in pairs(device_warning_status.dependent) do
      if string.sub(data, pos, pos) == '1' then
        table.insert(alerts, alert .. warning_flag)
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

function parser:get_output_mode(data)
  return output_mode.values[data]
end

function parser:get_connection_scheme(max_parallel_number)
  local scheme_table = {}
  if max_parallel_number < 2 then
    local result, data = mpp_solar:run_with_cache(serial_number.command)
    local serial_num = nil
    if result then
      serial_num = data
    end
    local device_table = { sn = serial_num, out_mode = '0' }
    scheme_table['0'] = device_table
  else
    local parallel_info = commands.parallel_info
    for i = 0, max_parallel_number do
      local command = parallel_info.command .. i
      local result, data = mpp_solar:run_with_cache(command)

      if result then
        data = split(data)
        if tonumber(data[parallel_info.data.parallel_num_exists]) == 1 then
          scheme_table[i] = {
            sn = data[parallel_info.data.serial_number],
            out_mode = data[parallel_info.data.work_mode],
          }
        end
      end
    end
  end
  return scheme_table
end

function parser:get_max_parallel_number()
  local result, data = mpp_solar:run_with_cache(device_model.command)
  if result and has_value(mpp_solar.no_qpgs, data) then
    enapter.log("Inverter doesn't support parallel mode")
    return 0
  else
    local result, data = mpp_solar:run_with_cache(device_rating_info.command)
    if result then
      -- enapter.log('device rating info: '..tostring(data))
      local max_parallel_number = split(data)[device_rating_info.data.parallel_max_num]
      if max_parallel_number == '-' then
        return 0
      else
        return tonumber(max_parallel_number)
      end
    end
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

function has_value(tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end

return parser
