local mpp_solar = require("mpp_solar")
local moving_average = require("moving_average")
local commands = require("commands")
local device_rating_info = commands.device_rating_info
local firmware_version = commands.firmware_version
local device_protocol = commands.device_protocol
local general_status_parameters = commands.general_status_parameters
local device_mode = commands.device_mode
local device_warning_status = commands.device_warning_status
local serial_number = commands.serial_number

local parser_module = {}

-- mpp_solar.device_rating_info = 'QPIRI'
-- mpp_solar.device_general_status_params = 'QPIGS'
-- mpp_solar.parallel_info = 'QPGS'
-- mpp_solar.output_mode = 'QOPM'
-- mpp_solar.device_serial_number = 'QID'

function parser_module:get_device_model()
    local result, data = mpp_solar:run_with_cache(device_rating_info.command)
    if result then
        return split(data)[device_rating_info.data.ac_out_apparent_power] .. "VA", nil
    else
        return nil, 'no_data'
    end
end

function parser_module:get_firmware_version()
    local result, data = mpp_solar:run_with_cache(firmware_version.command)
    if result then
      return data, nil
    else
      return nil, 'no_data'
    end
end

function parser_module:get_protocol_version()
    local result, data = mpp_solar:run_with_cache(device_protocol.command)
    if result then
      return data, nil
    else
      return nil, 'no_data'
    end
end

-- function parser_module:get_data_list(command)
--     local data = mpp_solar:run_command(command)
--     if data then
--       return split(data)
--     end
--     return nil, 'no_data'
-- end

function parser_module:get_device_general_status_params()
    local data = mpp_solar:run_command(general_status_parameters.command)
    if data then
      local telemetry = {}
      data = split(data)

      for name, index in pairs(general_status_parameters.data) do
        telemetry[name] = tonumber(data[index])
      end

      telemetry["pv_input_power"] = tonumber(data[general_status_parameters.data.pv_input_amp])
      * tonumber(data[general_status_parameters.data.pv_input_amp])
      return telemetry, nil
    else
      return nil, 'no_data'
    end
end

function parser_module:get_device_rating_info()
    local data = mpp_solar:run_command(device_rating_info.command)
    local telemetry = {}
    if data then
      for name, index in pairs(general_status_parameters.data) do
        telemetry[name] = tonumber(data[index])
      end
      return telemetry, nil
    else
      return nil, 'no_data'
    end
end

function parser_module:get_priorities(telemetry)
    local output_priorities = {}
    output_priorities[0] = "Utility First"
    output_priorities[1] = "Solar First"
    output_priorities[2] = "SBU"

    local charger_priorities = {}
    charger_priorities[0] = "Utility first"
    charger_priorities[1] = "Solar first"
    charger_priorities[2] = "Solar and utility"
    charger_priorities[3] = "Only solar"

    telemetry["output_source_priority"] = output_priorities[telemetry["output_source_priority"]]
    telemetry["charger_source_priority"] = charger_priorities[telemetry["charger_source_priority"]]
end

function parser_module:get_device_mode()
    local data = mpp_solar:run_command(device_mode.command)
    if data then
      if data == "P" then
        return "power_on"
      elseif data == "S" then
        return "standby"
      elseif data == "L" then
        return "line"
      elseif data == "B" then
        return "battery"
      elseif data == "F" then
        return "error"
      elseif data == "H" then
        return "power_saving"
      else
        return data
      end
    else
      return 'unknown'
    end
end

function parser_module:get_device_alerts()
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
          table.insert(alerts, alert..warning_flag)
        end
      end

      return alerts
    else
      enapter.log("Warning status failure", 'error')
      return nil
    end
end

function parser_module:get_battery_voltage(voltage)
    if voltage then
        moving_average:add_to_table(tonumber(voltage))
        return moving_average:get_value()
    else
        moving_average.table = {}
        enapter.log("No battery voltage", 'error')
        return nil
    end
end

-- For 4K/5K
function parser_module:get_output_mode(data)
    if data == '0' then
      return 'Single'
    elseif data == '1' then
      return 'Parallel'
    elseif data == '2' then
      return 'Phase 1'
    elseif data == '3' then
      return 'Phase 2'
    elseif data == '4' then
      return 'Phase 3'
    else
      return data
    end
end

function parser_module:get_connection_scheme(max_parallel_number)
    local scheme_table = {}
    if max_parallel_number == 0 then
        local result, data = mpp_solar:run_with_cache(serial_number.command)
        local serial_num = nil
        if result then serial_num = data end
        local device_table = {sn=serial_num, out_mode="0"}
        scheme_table["0"] = device_table
    else
        for i = 0, max_parallel_number do
            local command = mpp_solar.parallel_info..i

            local result, data = mpp_solar:run_with_cache(command)

            if result then
                -- if The parallel num whether exist
                if tonumber(string.sub(data, 1, 1)) == 1 then
                    scheme_table[i] = {
                      sn=string.sub(data, 3, 16),
                      out_mode=string.sub(data, 109, 109)
                    }
                end
            end
        end
    end
    return scheme_table
end

function parser_module:get_max_parallel_number()
    local result, data = mpp_solar:run_with_cache(device_rating_info.command)
    if result then
      local data_list = split(data)
      local max_parallel_number = data_list[19]
      if max_parallel_number == '-' then
        return 0
      else
        return tonumber(max_parallel_number)
      end
   end
end

-- function tprint(tbl, indent)
--   if not indent then indent = 0 end

--   local toprint = string.rep(" ", indent) .."{\r\n"
--   indent = indent + 2
--   for k, v in pairs(tbl) do
--     toprint = toprint .. string.rep(" ", indent)
--     if (type(k) == "number") then
--       toprint = toprint .. "[" .. k .. "] = "
--     elseif (type(k) == "string") then
--       toprint = toprint  .. k ..  "= "
--     end
--     if (type(v) == "number") then
--       toprint = toprint .. v .. ",\r\n"
--     elseif (type(v) == "string") then
--       toprint = toprint .. "\"" .. v .. "\",\r\n"
--     elseif (type(v) == "table") then
--       toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
--     else
--       toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
--     end
--   end
--   toprint = toprint .. string.rep(" ", indent-2) .. "}"
--   return toprint
-- end

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

return parser_module
