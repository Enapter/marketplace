local mpp_solar = require("mpp_solar")
local moving_average = require("moving_average")

MPP = {}
MPP.device_rating_info = 'QPIRI'
MPP.device_general_status_params = 'QPIGS'
MPP.device_mode = 'QMOD'
MPP.default_settings_value_info = 'QDI'
MPP.device_warning_status = 'QPIWS'
MPP.parallel_info = 'QPGS'
MPP.output_mode = 'QOPM'
MPP.device_serial_number = 'QID'
MPP.firmware_version = 'QVFW'
MPP.device_protocol_id = 'QPI'


function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2 
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "   
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end


local parser_module = {}

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

function parser_module:get_data_list(command)
    local data = mpp_solar:run_command(command)
    if data then
      return split(data)
    end
    return nil
end

telemetry = {}
alerts = {}

function parser_module:map_device_general_status_params(data)
    telemetry["grid_volt"] = tonumber(data[1])
    telemetry["grid_freq"] = tonumber(data[2])
    telemetry["ac_out_volt"] = tonumber(data[3])
    telemetry["ac_out_freq"] = tonumber(data[4])
    telemetry["ac_out_apparent_power"] = tonumber(data[5])
    telemetry["ac_out_active_power"] = tonumber(data[6])
    telemetry["ac_out_load_percent"] = tonumber(data[7])
    telemetry["dc_bus_volt"] = tonumber(data[8])
    telemetry["battery_volt"] = parser_module:get_battery_voltage(tonumber(data[9]))
    telemetry["battery_charge_amp"] = tonumber(data[10])
    telemetry["battery_capacity"] = tonumber(data[11])
    telemetry["heat_sink_temperature"] = tonumber(data[12])
    telemetry["pv_input_amp"] = tonumber(data[13])
    telemetry["pv_input_volt"] = tonumber(data[14])
    telemetry["pv_input_power"] = tonumber(data[13]) * tonumber(data[14])
    telemetry["battery_volt_scc"] = tonumber(data[15])
    telemetry["battery_discharge_amp"] = tonumber(data[16])
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

function parser_module:map_device_rating_info(data)
    telemetry["output_source_priority"] = parser_module:output_source_priority(tonumber(data[17]))
    telemetry["charger_source_priority"] = parser_module:charger_source_priority(tonumber(data[18]))
end

function parser_module:output_source_priority(priority)
  if priority == 0 then
    return 'Utility First'
  elseif priority == 1 then
    return 'Solar First'
  elseif priority == 2 then
    return 'SBU'
  end
  return priority
end

function parser_module:charger_source_priority(priority)
  if priority == 0 then
    return 'Utility First'
  elseif priority == 1 then
    return 'Solar First'
  elseif priority == 2 then
    return 'Solar and Utility'
  elseif priority == 3 then
    return 'Only Solar'
  end
  return priority
end

function parser_module:map_device_mode(data)
    local status
    if data == "P" then
      status = "power_on"
    elseif data == "S" then
      status = "standby"
    elseif data == "L" then
      status = "line"
    elseif data == "B" then
      status = "battery"
    elseif data == "F" then
      status = "error"
    elseif data == "H" then
      status = "power_saving"
    else
      status = data
    end
    return status
end

function parser_module:map_device_warning_status(data)
    local errors = {}
    errors[1] = 'inverter_fault'
    errors[2] = 'bus_over'
    errors[3] = 'bus_under'
    errors[4] = 'bus_soft_fail'
    errors[7] = 'inverter_voltage_too_low'
    errors[8] = 'inverter_voltage_too_high'
    errors[18] = 'inverter_over_current'
    errors[19] = 'inverter_soft_fail'
    errors[20] = 'self_test_fail'
    errors[21] = 'op_dc_voltage_over'
    errors[22] = 'bat_open'
    errors[23] = 'current_sensor_fail'
    errors[24] = 'battery_short'
    local warnings = {}
    warnings[5] = 'line_fail'
    warnings[6] = 'opvshort'
    warnings[12] = 'battery_low_alarm'
    warnings[14] = 'battery_under_shutdown'
    warnings[15] = 'reserved'
    warnings[17] = 'eeprom_fault'
    warnings[25] = 'power_limit'
    warnings[26] = 'pv_voltage_high'
    warnings[27] = 'mppt_overload_fault'
    warnings[28] = 'mppt_overload_warning'
    warnings[29] = 'battery_too_low_to_charge'

    if data then
        for i = 1, #data do
          local bit = string.sub(data, i, i)
          if bit == '1' then
            table.insert(alerts, errors[i])
            table.insert(alerts, warnings[i])
          end
        end
    else
      enapter.log("Warning status failure", 'error')
      return nil
    end

    local inverter_fault_depend_alerts = {}
    inverter_fault_depend_alerts[9] = 'over_temperature'
    inverter_fault_depend_alerts[10] = 'fan_locked'
    inverter_fault_depend_alerts[11] = 'battery_voltage_high'
    inverter_fault_depend_alerts[16] = 'over_load'

    local warning_flag = string.sub(data, 1, 1) == '1' and '' or '_w'
    for index, alert in pairs(inverter_fault_depend_alerts) do
      if string.sub(data, index, index) == '1' then
        table.insert(alerts, alert..warning_flag)
      end
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

function parser_module:map_parallel_info(str_data, num)
  -- enapter.log(tprint(str_data),'info')
  -- local data = split(str_data)
  local data = str_data
  telemetry["exists_"..num] = tonumber(data[1])
  telemetry["serial_number_"..num] = data[2]
  telemetry["work_mode_"..num] = data[3]
  telemetry["fault_code_"..num] = parser_module:qpgsn_fault(data[4])
  telemetry["grid_volt_"..num] = tonumber(data[5])
  telemetry["grid_freq_"..num] = tonumber(data[6])
  telemetry["ac_out_volt_"..num] = tonumber(data[7])
  telemetry["ac_out_freq_"..num] = tonumber(data[8])
  telemetry["ac_out_apparent_power_"..num] = tonumber(data[9])
  telemetry["ac_out_active_power_"..num] = tonumber(data[10])
  telemetry["ac_out_load_percent_"..num] = tonumber(data[11])
  telemetry["battery_volt_"..num] = tonumber(data[12])
  telemetry["battery_charge_amp_"..num] = tonumber(data[13])
  telemetry["battery_capacity_"..num] = tonumber(data[14])
  telemetry["pv_input_volt_"..num] = tonumber(data[15])
  telemetry["total_charge_amp_"..num] = tonumber(data[16])
  telemetry["total_ac_out_apparent_power_"..num] = tonumber(data[17])
  telemetry["total_ac_out_active_power_"..num] = tonumber(data[18])
  telemetry["total_ac_out_load_percent_"..num] = tonumber(data[19])
  telemetry["inverter_status_"..num] = tonumber(data[20])
  telemetry["output_mode_"..num] = tonumber(data[21])
  telemetry["charger_source_priority_"..num] = tonumber(data[22])
  telemetry["max_charger_amp_"..num] = tonumber(data[23])
  telemetry["max_charger_range_"..num] = tonumber(data[24])
  telemetry["max_ac_charger_amp_"..num] = tonumber(data[25])
  telemetry["pv_input_amp_"..num] = tonumber(data[26])
  telemetry["battery_discharge_amp_"..num] = tonumber(data[27])
  local pv_voltage = telemetry["pv_input_volt_"..num]
  local pv_amperage = telemetry["pv_input_amp_"..num]
  telemetry["pv_input_power_"..num] = pv_voltage * pv_amperage
end

function parser_module:qpgsn_fault(code)
  if code == '00' then
    return 'no fault'
  elseif code == '01' then
    return 'fan_locked'
  elseif code == '02' then
    return 'over_temperature'
  elseif code == '03' then
    return 'battery_voltage_is_too_high'
  elseif code == '04' then
    return 'battery_voltage_is_too_low'
  elseif code == '05' then
    return 'output_short_circuited_or_over_temperature'
  elseif code == '06' then
    return 'output_voltage_is_too_high'
  elseif code == '07' then
    return 'over_load_time_out'
  elseif code == '08' then
    return 'bus_voltage_is_too_high'
  elseif code == '09' then
    return 'bus_soft_start_failed'
  elseif code == '11' then
    return 'main_relay_failed'
  elseif code == '51' then
    return 'over_current_inverter'
  elseif code == '52' then
    return 'bus_soft_start_failed'
  elseif code == '53' then
    return 'inverter_soft_start_failed'
  elseif code == '54' then
    return 'self_test_failed'
  elseif code == '55' then
    return 'over_dc_voltage_on_output_of_inverter'
  elseif code == '56' then
    return 'battery_connection_is_open'
  elseif code == '57' then
    return 'current_sensor_failed'
  elseif code == '58' then
    return 'output_voltage_is_too_low'
  elseif code == '60' then
    return 'inverter_negative_power'
  elseif code == '71' then
    return 'parallel_version_different'
  elseif code == '72' then
    return 'output_circuit_failed'
  elseif code == '80' then
    return 'can_communication_failed'
  elseif code == '81' then
    return 'parallel_host_line_lost'
  elseif code == '82' then
    return 'parallel_synchronized_signal_lost'
  elseif code == '83' then
    return 'parallel_battery_voltage_detect_different'
  elseif code == '84' then
    return 'parallel_line_voltage_or_frequency_detect_different'
  elseif code == '85' then
    return 'parallel_line_input_current_unbalanced'
  elseif code == '86' then
    return 'parallel_output_setting_different'
  end
  return code
end

function parser_module:get_connection_scheme(max_parallel_number)
    local scheme_table = nil
    if max_parallel_number == 0 then
        local result, data = mpp_solar:run_with_cache(MPP.device_serial_number)
        local serial_num = nil
        if result then serial_num = data end
        local device_table = {sn=serial_num, out_mode="0"}
        scheme_table = {}
        scheme_table["0"] = device_table
        return scheme_table
    else
        scheme_table = {}
        for i = 0, max_parallel_number do
            local command = MPP.parallel_info..i
            
            local result, data = mpp_solar:run_with_cache(command)
            -- enapter.log(command .. " " .. data, 'info')
            
            if result then

                -- if The parallel num whether exist
                if tonumber(string.sub(data, 1, 1)) == 1 then
                    local sn = string.sub(data, 3, 16)
                    local out_mode = string.sub(data, 109, 109)
                    -- enapter.log(sn .. " " .. out_mode, 'info')
                    scheme_table[i] = {sn=sn, out_mode=out_mode}
                end
            end
        end
        -- enapter.log("Scheme Table: " .. tprint(scheme_table),'info')
        return scheme_table
    end
end

function parser_module:get_max_parallel_number()
    local result, data = mpp_solar:run_with_cache(MPP.device_rating_info)
    if result then
      -- enapter.log(data,'info')  
      local qpiri_list = split(data)
      local max_parallel_number = qpiri_list[19]
      local parallel_number = 0
      -- enapter.log("Max Parallel Number: " .. tostring(max_parallel_number),'info')
      if max_parallel_number ~= "-" then
        for i = 0, max_parallel_number do
          local command = MPP.parallel_info..i
          local result, data = mpp_solar:run_with_cache(command)
          if result then
              -- if The parallel num whether exist
            if tonumber(string.sub(data, 1, 1)) == 1 then
              parallel_number = parallel_number + 1
            end
          end
        end  
      end
    parallel_number = parallel_number - 1
    enapter.log("Active Parallel Number: " .. tostring(parallel_number),'info')
    return parallel_number
    end
    return 0
end

return parser_module
