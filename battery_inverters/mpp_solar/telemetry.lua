function preprocess_telemetry(telemetry)
  if telemetry["QPIRI"] then
    local data = split(telemetry["QPIRI"])
    telemetry["output_source_priority"] = output_source_priority(data[16])
    telemetry["charger_source_priority"] = charger_source_priority(data[17])
  end
  if telemetry["QPIGS"] then
    local data = split(telemetry["QPIGS"])
    telemetry["grid_volt"] = tonumber(data[1])
    telemetry["grid_freq"] = tonumber(data[2])
    telemetry["ac_out_volt"] = tonumber(data[3])
    telemetry["ac_out_freq"] = tonumber(data[4])
    telemetry["ac_out_apparent_power"] = tonumber(data[5])
    telemetry["ac_out_active_power"] = tonumber(data[6])
    telemetry["ac_out_load_percent"] = tonumber(data[7])
    telemetry["dc_bus_volt"] = tonumber(data[8])
    telemetry["battery_volt"] = tonumber(data[9])
    telemetry["battery_charge_amp"] = tonumber(data[10])
    telemetry["battery_capacity"] = tonumber(data[11])
    telemetry["heat_sink_temperature"] = tonumber(data[12])
    telemetry["pv_input_amp"] = tonumber(data[13])
    telemetry["pv_input_volt"] = tonumber(data[14])
    telemetry["pv_input_power"] = tonumber(data[13]) * tonumber(data[14])
    telemetry["battery_volt_scc"] = tonumber(data[15])
    telemetry["battery_discharge_amp"] = tonumber(data[16])
  end
  if telemetry["QMOD"] then
    local status = telemetry["QMOD"]
    if status == "P" then
      telemetry["status"] = "power_on"
    elseif status == "S" then
      telemetry["status"] = "standby"
    elseif status == "L" then
      telemetry["status"] = "line"
    elseif status == "B" then
      telemetry["status"] = "battery"
    elseif status == "F" then
      telemetry["status"] = "error"
    elseif status == "H" then
      telemetry["status"] = "power_saving"
    end
  end
  if telemetry["QPIWS"] then
    local alerts = {}
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
    local additional_errors = {}
    additional_errors[9] = 'over_temperature'
    additional_errors[10] = 'fan_locked'
    additional_errors[11] = 'battery_voltage_high'
    additional_errors[16] = 'over_load'
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
    local additional_warnings = {}
    additional_warnings[9] = 'over_temperature_w'
    additional_warnings[10] = 'fan_locked_w'
    additional_warnings[11] = 'battery_voltage_high_w'
    additional_warnings[16] = 'over_load_w'

    local alerts_bit = split_bits(telemetry["QPIWS"])
    for i = 1, #alerts_bit do
      if alerts_bit[i] == '1' then
        table.insert(alerts, errors[i])
        table.insert(alerts, warnings[i])
      end
    end

    local additional_indexes = {9, 10, 11, 16}
    if alerts_bit[1] == '1' then
      for i = 1, #additional_indexes do
        table.insert(alerts, additional_errors[additional_indexes[i]])
      end
    else
      for i = 1, #additional_indexes do
        table.insert(alerts, additional_warnings[additional_indexes[i]])
      end
    end
    --telemetry["alerts"] = alerts
    telemetry["alerts_test"] = alerts
  end
  if telemetry["QPGS0"] then
    local metrics = parse_qpgsn(telemetry["QPGS0"], '0')
    table.move(metrics, 1, #metrics, #telemetry + 1, telemetry)
  end
  if telemetry["QPGS1"] then
    local metrics = parse_qpgsn(telemetry["QPGS1"], '1')
    table.move(metrics, 1, #metrics, #telemetry + 1, telemetry)
  end
  if telemetry["QPGS2"] then
    local metrics = parse_qpgsn(telemetry["QPGS2"], '2')
    table.move(metrics, 1, #metrics, #telemetry + 1, telemetry)
  end
end

function parse_qpgsn(str_data, num)
  local data = split(str_data)
  local result = {}
  result["exists_"..num] = tonumber(data[1])
  result["serial_number_"..num] = data[2]
  result["work_mode_"..num] = data[3]
  result["fault_code_"..num] = qpgsn_fault(data[4])
  result["grid_volt_"..num] = tonumber(data[5])
  result["grid_freq_"..num] = tonumber(data[6])
  result["ac_out_volt_"..num] = tonumber(data[7])
  result["ac_out_freq_"..num] = tonumber(data[8])
  result["ac_out_apparent_power_"..num] = tonumber(data[9])
  result["ac_out_active_power_"..num] = tonumber(data[10])
  result["ac_out_load_percent_"..num] = tonumber(data[11])
  result["battery_volt_"..num] = tonumber(data[12])
  result["battery_charge_amp_"..num] = tonumber(data[13])
  result["battery_capacity_"..num] = tonumber(data[14])
  result["pv_input_volt_"..num] = tonumber(data[15])
  result["total_charge_amp_"..num] = tonumber(data[16])
  result["total_ac_out_apparent_power_"..num] = tonumber(data[17])
  result["total_ac_out_active_power_"..num] = tonumber(data[18])
  result["total_ac_out_load_percent_"..num] = tonumber(data[19])
  result["inverter_status_"..num] = tonumber(data[20])
  result["output_mode_"..num] = tonumber(data[21])
  result["charger_source_priority_"..num] = tonumber(data[22])
  result["max_charger_amp_"..num] = tonumber(data[23])
  result["max_charger_range_"..num] = tonumber(data[24])
  result["max_ac_charger_amp_"..num] = tonumber(data[25])
  result["pv_input_amp_"..num] = tonumber(data[26])
  result["battery_discharge_amp_"..num] = tonumber(data[27])
  local pv_voltage = result["pv_input_volt_"..num]
  local pv_amperage = result["pv_input_amp_"..num]
  result["pv_input_power_"..num] = pv_voltage * pv_amperage
  return result
end

function output_source_priority(value)
  local priority = tonumber(value)
  if priority == 0 then
    return 'utility_first'
  elseif priority == 1 then
    return 'solar_first'
  elseif priority == 2 then
    return 'sbu_first'
  end
  return value
end

function charger_source_priority(value)
  local priority = tonumber(value)
  if priority == 0 then
    return 'utility_first'
  elseif priority == 1 then
    return 'solar_first'
  elseif priority == 2 then
    return 'solar_and_utility'
  elseif priority == 3 then
    return 'only_solar'
  end
  return value
end

function qpgsn_fault(code)
  if code == '01' then
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

function split_bits(str)
    local t = {}
    for i = 1, #str do
      local symbol = string.sub(str, i, i)
        table.insert(t, symbol)
    end

    return t
end
