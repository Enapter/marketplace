function main()
    local err = rs232.init(mpp_solar.baudrate, mpp_solar.data_bits, mpp_solar.parity, mpp_solar.stop_bits)
    if err ~= 0 then
        enapter.log('RS232 init failed: '..rs232.err_to_str(err), 'error')
        enapter.send_telemetry({ status = 'error', alerts = {'init_error'}})
        return
    end

    scheduler.add(30000, send_properties)
    scheduler.add(1000, send_telemetry)

    enapter.register_command_handler("set_output_priority", command_set_output_priority)
    enapter.register_command_handler("set_charger_priority", command_set_charger_priority)
end

mpp_solar = {}

mpp_solar.baudrate = 2400
mpp_solar.data_bits = 8
mpp_solar.parity = 'N'
mpp_solar.stop_bits = 1

function mpp_solar:run_command(name)
    if name ~= nil then
        local crc = crc16(name)
        name = name .. string.char((crc & 0xFF00) >> 8)
        name = name .. string.char(crc & 0x00FF)
        name = name .. string.char(0x0D)
        rs232.send(name)

        local raw_data, result = rs232.receive(2000)
        if raw_data and string.byte(raw_data, #raw_data) == 0x0d then
            local data = string.sub(raw_data, 1, -4)
            local r_crc = crc16(data)
            if (r_crc & 0xFF00) >> 8 == string.byte(raw_data, -3) and r_crc & 0x00FF == string.byte(raw_data, -2) then
                local com_response = string.sub(data, 2)
                mpp_solar:add_to_cache(name, com_response, os.time())
                return com_response
            end
        else
            enapter.log(name.." command failed: "..rs232.err_to_str(result), 'error')
        end
    end
    return nil
end

COMMAND_CACHE = {}

function mpp_solar:add_to_cache(command_name, data, updated)
    COMMAND_CACHE[command_name] = {data=data, updated=updated}
end

function mpp_solar:read_cache(command_name)
    if COMMAND_CACHE[command_name] then
        return true, COMMAND_CACHE[command_name].data
    end
    return false
end

function mpp_solar:is_in_cache(command_name)
    local com_data = COMMAND_CACHE[command_name]
    if com_data == nil then
        return true
    end
    if com_data.updated + 60 < os.time() then
        return true
    end
    return false
end

function mpp_solar:run_with_cache(name)
    if mpp_solar:is_in_cache(name) then
        local data = mpp_solar:run_command(name)
        if data then
            mpp_solar:add_to_cache(name, data, os.time())
            return true, data
        end
    else
        local result, data = mpp_solar:read_cache(name)
        if result then
            return true, data
        end
    end
    return false
end

function crc16(pck)
    local index
    local crc = 0
    local da
    local t_da
    local crc_ta = { 0x0000, 0x1021, 0x2042, 0x3063,
         0x4084, 0x50a5, 0x60c6, 0x70e7,
         0x8108, 0x9129, 0xa14a, 0xb16b,
         0xc18c, 0xd1ad, 0xe1ce, 0xf1ef }

    for i = 1, #pck do
        t_da = crc >> 8
        da = t_da >> 4
        crc = (crc << 4) & 0xFFFF
        index = (da ~ (string.byte(pck, i) >> 4)) + 1
        crc = crc ~ crc_ta[index]
        t_da = crc >> 8
        da = t_da >> 4
        crc = (crc << 4) & 0xFFFF
        index = (da ~ (string.byte(pck, i) & 0x0F) & 0xFFFF) + 1
        crc = crc ~ crc_ta[index]
    end

    local b_crc_low = crc & 0xFF
    local b_crc_high = (crc >> 8) & 0xFF

    if b_crc_low == 0x28 or b_crc_low == 0x0D or b_crc_low == 0x0A then
        b_crc_low = b_crc_low + 1
    end
    if b_crc_high == 0x28 or b_crc_high == 0x0D or b_crc_high == 0x0A then
        b_crc_high = b_crc_high + 1
    end

    crc = (b_crc_high & 0xFFFF) << 8
    crc = crc + b_crc_low

    return crc
end
----------------

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

parser = {}

function parser:get_data_list(command)
    local data = mpp_solar:run_command(command)
    if data then
      return split(data, ' ')
    end
    return nil
end

telemetry = {}
alerts = {}

function parser:map_device_general_status_params(data)
    telemetry["grid_volt"] = tonumber(data[1])
    telemetry["grid_freq"] = tonumber(data[2])
    telemetry["ac_out_volt"] = tonumber(data[3])
    telemetry["ac_out_freq"] = tonumber(data[4])
    telemetry["ac_out_apparent_power"] = tonumber(data[5])
    telemetry["ac_out_active_power"] = tonumber(data[6])
    telemetry["ac_out_load_percent"] = tonumber(data[7])
    telemetry["dc_bus_volt"] = tonumber(data[8])
    telemetry["battery_volt"] = get_battery_voltage(tonumber(data[9]))
    telemetry["battery_charge_amp"] = tonumber(data[10])
    telemetry["battery_capacity"] = tonumber(data[11])
    telemetry["heat_sink_temperature"] = tonumber(data[12])
    telemetry["pv_input_amp"] = tonumber(data[13])
    telemetry["pv_input_volt"] = tonumber(data[14])
    telemetry["pv_input_power"] = tonumber(data[13]) * tonumber(data[14])
    telemetry["battery_volt_scc"] = tonumber(data[15])
    telemetry["battery_discharge_amp"] = tonumber(data[16])
end

moving_average = {}
moving_average.period = 10
moving_average.table = {}

function moving_average:add_to_table(voltage)
    if #moving_average.table == moving_average.period then
        table.remove(moving_average.table, 1)
    end
    moving_average.table[#moving_average.table + 1] = voltage
end

function moving_average:get_value()
    local function sum(a, ...)
        if a then return a+sum(...) else return 0 end
    end
    return sum(table.unpack(moving_average.table))/#moving_average.table
end

function get_battery_voltage(voltage)
    if voltage then
        moving_average:add_to_table(tonumber(voltage))
        return moving_average:get_value()
    else
        moving_average.table = {}
        enapter.log("No battery voltage", 'error')
        return nil
    end
end

function parser:map_device_rating_info(data)
    telemetry["output_source_priority"] = output_source_priority(tonumber(data[17]))
    telemetry["charger_source_priority"] = charger_source_priority(tonumber(data[18]))
end

function output_source_priority(value)
  local priority = tonumber(value)
  if priority == 0 then
    return 'utility_first'
  elseif priority == 1 then
    return 'solar_first'
  elseif priority == 2 then
    return 'SBU_first'
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

function parser:map_device_mode(data)
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

function parser:map_device_warning_status(data)
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
function get_output_mode(data)
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

function parser:map_parallel_info(str_data, num)
  local data = split(str_data)
  telemetry["exists_"..num] = tonumber(data[1])
  telemetry["serial_number_"..num] = data[2]
  telemetry["work_mode_"..num] = data[3]
  telemetry["fault_code_"..num] = parser:qpgsn_fault(data[4])
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

function parser:qpgsn_fault(code)
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

function get_connection_scheme(max_parallel_number)
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
        for i = 0, max_parallel_number do
            local command = MPP.parallel_info..i
            local result, data = mpp_solar:run_with_cache(command)
            if result then
            scheme_table = {}
                -- if The parallel num whether exist
                if tonumber(string.sub(data, 1, 1)) == 1 then
                    local sn = string.sub(data, 3, 16)
                    local out_mode = string.sub(data, 109, 109)
                    scheme_table[tostring(i)] = {sn=sn, out_mode=out_mode}
                end
            end
        end
        return scheme_table
    end
end

function get_max_parallel_number()
    local result, data = mpp_solar:run_with_cache(MPP.device_rating_information)
    if result then
        local qpiri_list = split(data, " ")
        local parallel_number = qpiri_list[19]
        if parallel_number ~= "-" then
            return tonumber(parallel_number)
        end
    end

    return 0
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

function set_charger_priority(priority)
    if not (0 <= priority and priority < 4) then
        return false, "Invalid priority value"
    end

    local data = mpp_solar:run_command("PCP0" .. priority)
    if data then
        if data == "ACK" then
            return true
        elseif data == "NAK" then
            return false, "Response: NAK"
        else
            return false, "Response neither ACK or NAK"
        end
    else
        return false, "No response from device"
    end
end

function set_output_priority(priority)
    if not (0 <= priority and priority < 3) then
        return false, "Invalid priority value"
    end

    local data = mpp_solar:run_command("POP0" .. priority)
    if data then
        if data == "ACK" then
            return true
        elseif data == "NAK" then
            return false, "Response: NAK"
        else
            return false, "Response neither ACK or NAK"
        end
    else
        return false, "No response from device"
    end
end

function command_set_output_priority(ctx, args)
    local priorities = {}
    priorities["Utility first"] = 0
    priorities["Solar first"] = 1
    priorities["SBU first"] = 2

    if args["priority"] then
        local result, err = set_output_priority(priorities[args["priority"]])
        if not result then
	          ctx.error(err)
        end
    else
        ctx.error("No arguments")
    end
end

function command_set_charger_priority(ctx, args)
    local priorities = {}
    priorities["Utility first"] = 0
    priorities["Solar first"] = 1
    priorities["Solar and utility"] = 2
    priorities["Only solar"] = 3

    if args["priority"] then
        local result, err = set_charger_priority(priorities[args["priority"]])
        if not result then
	          ctx.error(err)
	      end
    else
        ctx.error("No arguments")
    end
end

local max_parallel_number

function send_properties()
    local telemetry = {}
    max_parallel_number = get_max_parallel_number()

    local result, data = mpp_solar:run_with_cache(MPP.device_rating_info)
    if result then
        telemetry["model"] = string.sub(data, 28, 31) .. "VA"
    else
        enapter.log("Can not get device model", 'error')
    end
    local result, data = mpp_solar:run_with_cache(MPP.firmware_version)
    if result then
        telemetry["fw_ver"] = data
    else
        enapter.log("Can not get device firmware version", 'error')
    end
    local result, data = mpp_solar:run_with_cache(MPP.device_protocol_id)
    if result then
        telemetry["protocol_ver"] = data
    else
        enapter.log("Can not get device protocol version", 'error')
    end

    local scheme = get_connection_scheme(max_parallel_number)
    if max_parallel_number == 0 then
        telemetry["serial_num"] = scheme["0"]["sn"]
        telemetry["output_mode"] = get_output_mode(scheme["0"]["out_mode"])
    elseif max_parallel_number > 0 then
        for num = 0, max_parallel_number do
            telemetry["serial_num"..num] = scheme[tostring(num)]["sn"]
            telemetry["output_mode"..num] = get_output_mode(scheme[tostring(num)]["out_mode"])
        end
    end

    enapter.send_properties(telemetry)
end

function send_telemetry()
    local rules_available = true

    local data = parser:get_data_list(MPP.device_rating_info)
    if data then
      parser:map_device_rating_info(data)
    else
      rules_available = false
    end

    local data = mpp_solar:run_command(MPP.device_mode)
    if data then
      local status = parser:map_device_mode(data)
      telemetry["status"] = status
    else
      rules_available = false
    end

    local data = mpp_solar:run_command(MPP.device_warning_status)
    if data then
      parser:map_device_warning_status(data)
    end

    if max_parallel_number == 0 then
        local data = parser:get_data_list(MPP.device_general_status_params)
        if data then
          parser:map_device_general_status_params(data)
        end
    else
        for num = 0, max_parallel_number - 1 do
            parser:get_data_list(MPP.parallel_info..tostring(num))
            if data then
              parser:map_parallel_info(data, tostring(num))
            end
        end
    end

    if not rules_available then
      table.insert(alerts, "rules_unavailable")
    end

    telemetry["alerts"] = alerts
    enapter.send_telemetry(telemetry)
    telemetry = {}
    alerts = {}

    collectgarbage()
end

main()
