local mpp_solar = require("mpp_solar")
local moving_average = require("moving_average")
local commands = require("commands")

local device_rating_info = commands.device_rating_info
local firmware_version = commands.firmware_version
local device_protocol = commands.device_protocol
local device_mode = commands.device_mode
local output_mode = commands.output_mode
local priorities = commands.set_priorities
local parallel_info = commands.parallel_info

local parser = {}

function parser:get_device_model()
    local result, data = mpp_solar:run_with_cache(device_rating_info.command)
    if result then
        return split(data)[device_rating_info.data.ac_out_apparent_power].."VA", nil
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

function parser:get_device_rating_info()
    local result, data = mpp_solar:run_with_cache(device_rating_info.command)
    local telemetry = {}
    if result then
      for name, index in pairs(device_rating_info.data) do
        telemetry[name] = tonumber(split(data)[index])
      end

      return telemetry, nil
    else
      return nil, 'no_data'
    end
end

function parser:get_all_parallel_info(devices_number)
    local telemetry = {}
    local alerts = {}
    local total_pv_input_power = 0
    local non_existing_devices = 0

    for i = 0, devices_number do
      local data = parser:get_parallel_info(i)
      if data then
        if data["fault_code_"..i] then
          table.insert(alerts, data["fault_code_"..i])
        end

        if data["pv_input_power_"..i] ~= nil then
          total_pv_input_power = total_pv_input_power + data["pv_input_power_"..i]
        end

        for name, _ in pairs(parallel_info.data.total) do
          telemetry[name] = data[name]
        end

        telemetry["battery_volt"] = parser:get_battery_voltage(telemetry["battery_volt"])
      else
        non_existing_devices = non_existing_devices + 1
      end
    end

    if non_existing_devices == devices_number then
      return nil, 'no_data'
    else
      telemetry["total_pv_input_power"] = total_pv_input_power
      telemetry["alerts"] = alerts
      return telemetry, nil
    end
end

function parser:get_battery_voltage(voltage)
    if voltage then
        moving_average:add_to_table(voltage)
        return moving_average:get_value()
    else
        moving_average.table = {}
        enapter.log("No battery voltage", 'error')
        return nil
    end
end

function parser:get_parallel_info(device_number)
    local data = mpp_solar:run_command(parallel_info.command..device_number)

    if data then
      data = split(data)

      if data[parallel_info.data.general.num.parallel_num_exists] == '1' then
        local telemetry = {}
        for name, index in pairs(parallel_info.data.general.num) do
          telemetry[name.."_"..device_number] = tonumber(data[index])
        end

        for name, index in pairs(parallel_info.data.general.str) do
          telemetry[name.."_"..device_number] = data[index]
        end

        telemetry["work_mode_"..device_number] = parser:get_device_mode(
          telemetry["work_mode_"..device_number]
        )

        telemetry["output_mode_"..device_number] = parser:get_output_mode(
          telemetry["output_mode_"..device_number]
        )

        local pv_input_volt = telemetry["pv_input_volt_"..device_number]
        local pv_input_amp = telemetry["pv_input_amp_"..device_number]
        if pv_input_volt and pv_input_amp then
          telemetry["pv_input_power_"..device_number] = pv_input_volt * pv_input_amp
        end

        telemetry["fault_code_"..device_number] = parser:get_parallel_device_alerts(
          telemetry["fault_code_"..device_number]
        )

        telemetry["charger_source_priority_"..device_number] = priorities.charger.values[
          telemetry["charger_source_priority_"..device_number]
        ]

        for name, index in pairs(parallel_info.data.total) do
          telemetry[name] = tonumber(data[index])
        end

        return telemetry
      else
        return nil, 'no_device_with_such_number'
      end
    else
      return nil, 'no_data'
    end
end

function parser:get_parallel_device_alerts(value)
  if value then
    return parallel_info.fault_codes[value]
  else
    return nil
  end
end

function parser:get_device_mode(value)
    if not value then
      return 'unknown'
    else
      return device_mode.values[value]
    end
end

function parser:get_output_mode(value)
    return output_mode.values[value]
end

function parser:get_max_parallel_number()
    local result, data = mpp_solar:run_with_cache(device_rating_info.command)
    if result then
      local max_parallel_number = split(data)[device_rating_info.data.parallel_max_num]
      if max_parallel_number == '-' then
        return 0
      else
        return tonumber(max_parallel_number)
      end
    end
end

function split(str, sep)
    if sep == nil then
        sep = "%s"
    end

    local t = {}
    for part in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, part)
    end

    return t
end

return parser
