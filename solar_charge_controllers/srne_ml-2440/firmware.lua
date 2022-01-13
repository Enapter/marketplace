-- RS232 communication interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1

-- Device Modbus address
ADDRESS = 1

function main()
  local result = rs232.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS-232 failed: "..result.." "..rs232.err_to_str(result), "error", true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  local properties = {}

  properties["vendor"] = "SRNE"
  properties["model"] = "ML-2440"

  local data, result = modbus.read_holdings(ADDRESS, 10, 1, 1000)
  if data then
    properties["max_voltage"] = data[1] >> 8
    properties["max_current"] = data[1] & 0xFF
  else
    enapter.log("Register 10 reading failed: "..modbus.err_to_str(result), "error")
  end

  enapter.send_properties(properties)
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = "ok"

  local data, result = modbus.read_holdings(ADDRESS, 11, 1, 1000)
  if data then
    telemetry["rated_disc_current"] = data[1] >> 8
    telemetry["device_type"] = data[1] & 0xFF
  else
    enapter.log("Register 11 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  -- Controller dynamic information
  local data, result = modbus.read_holdings(ADDRESS, 256, 1, 1000)
  if data then
    telemetry["battery_soc"] = data[1] & 0xFF
  else
    enapter.log("Register 256 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 257, 1, 1000)
  if data then
    telemetry["battery_voltage"] = data[1] / 10.0
  else
    enapter.log("Register 256 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 258, 1, 1000)
  if data then
    telemetry["charging_current"] = data[1] / 100.0
  else
    enapter.log("Register 258 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 259, 1, 1000)
  if data then
    telemetry["controller_temp"] = tosignedint(data[1] >> 8)
    telemetry["battery_temp"] = tosignedint(data[1] >> 0xFF)
  else
    enapter.log("Register 259 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 260, 1, 1000)
  if data then
    telemetry["load_dc_voltage"] = data[1] / 10.0
  else
    enapter.log("Register 260 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 261, 1, 1000)
  if data then
    telemetry["load_dc_current"] = data[1] / 100.0
  else
    enapter.log("Register 261 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 262, 1, 1000)
  if data then
    telemetry["load_dc_power"] = data[1]
  else
    enapter.log("Register 262 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  -- Solar panel information
  local data, result = modbus.read_holdings(ADDRESS, 263, 1, 1000)
  if data then
    telemetry["solar_panel_voltage"] = data[1] / 10.0
  else
    enapter.log("Register 263 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 264, 1, 1000)
  if data then
    telemetry["solar_panel_current"] = data[1] / 100.0
  else
    enapter.log("Register 264 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 265, 1, 1000)
  if data then
    telemetry["charging_power"] = data[1]
  else
    enapter.log("Register 265 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  -- Battery information
  local data, result = modbus.read_holdings(ADDRESS, 267, 1, 1000)
  if data then
    telemetry["today_min_battery_volt"] = data[1] / 10.0
  else
    enapter.log("Register 267 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 268, 1, 1000)
  if data then
    telemetry["today_max_battery_volt"] = data[1] / 10.0
  else
    enapter.log("Register 268 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 269, 1, 1000)
  if data then
    telemetry["today_max_charging_curr"] = data[1] / 100.0
  else
    enapter.log("Register 269 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 270, 1, 1000)
  if data then
    telemetry["today_max_discharging_curr"] = data[1] / 100.0
  else
    enapter.log("Register 270 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x10F, 1, 1000)
  if data then
    telemetry["today_max_charging_power"] = data[1]
  else
    enapter.log("Register 0x10F reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x110, 1, 1000)
  if data then
    telemetry["today_max_discharging_power"] = data[1]
  else
    enapter.log("Register 0x110 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x111, 1, 1000)
  if data then
    telemetry["today_charging_amp_hrs"] = data[1]
  else
    enapter.log("Register 0x111 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x112, 1, 1000)
  if data then
    telemetry["today_discharging_amp_hrs"] = data[1]
  else
    enapter.log("Register 0x112 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x113, 1, 1000)
  if data then
    telemetry["today_power_generation"] = data[1]
  else
    enapter.log("Register 0x113 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x114, 1, 1000)
  if data then
    telemetry["today_power_consumption"] = data[1]
  else
    enapter.log("Register 0x114 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  -- Historical data information
  local data, result = modbus.read_holdings(ADDRESS, 0x115, 1, 1000)
  if data then
    telemetry["operating_days"] = data[1]
  else
    enapter.log("Register 0x115 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x116, 1, 1000)
  if data then
    telemetry["battery_over_discharges"] = data[1]
  else
    enapter.log("Register 0x116 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x117, 1, 1000)
  if data then
    telemetry["battery_full_charges"] = data[1]
  else
    enapter.log("Register 0x117 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x118, 2, 1000)
  if data then
    telemetry["charging_amp_hrs"] = toint(data)
  else
    enapter.log("Register 0x118 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x11A, 2, 1000)
  if data then
    telemetry["discharging_amp_hrs"] = toint(data)
  else
    enapter.log("Register 0x11A reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x11C, 2, 1000)
  if data then
    telemetry["cumulative_power_gen"] = toint(data)
  else
    enapter.log("Register 0x11C reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x11E, 2, 1000)
  if data then
    telemetry["cumulative_power_consum"] = toint(data)
  else
    enapter.log("Register 0x11E reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 0x120, 1, 1000)
  if data then
    telemetry["load_status"] = is_on(data[1] >> 15)
    telemetry["load_brightness"] = (data[1] >> 8) & 0x7F
    telemetry["charging_state"] = get_charging_state(data[1] >> 0xFF)
  else
    enapter.log("Register 0x120 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  --- TEST ---
  local data, result = modbus.read_holdings(ADDRESS, 0xE01D, 1, 1000)
  if data then
    telemetry["load_working_mode"] = get_load_working_mode(data[1])
  else
    enapter.log("Register 0xE01D reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  -- Controller fault information
  local data, result = modbus.read_holdings(ADDRESS, 0x121, 2, 1000)
  if data then
    if (data[1] << 1) >> 15 == 1 then
      table.insert(alerts, "charge_mos_short_circuit")
    elseif (data[1] << 2) >> 15 == 1 then
      table.insert(alerts, "anti_reverse_mos_short")
    elseif (data[1] << 3) >> 15 == 1 then
      table.insert(alerts, "solar_panel_reverse_connect")
    elseif (data[1] << 4) >> 15 == 1 then
      table.insert(alerts, "solar_panel_over_voltage")
    elseif (data[1] << 5) >> 15 == 1 then
      table.insert(alerts, "solar_panel_ctr_current")
    elseif (data[1] << 6) >> 15 == 1 then
      table.insert(alerts, "pv_input_over_voltage")
    elseif (data[1] << 7) >> 15 == 1 then
      table.insert(alerts, "pv_input_short_circuit")
    elseif (data[1] << 8) >> 15 == 1 then
      table.insert(alerts, "pv_input_overpower")
    elseif (data[1] << 9) >> 15 == 1 then
      table.insert(alerts, "high_ambient_temp")
    elseif (data[1] << 10) >> 15 == 1 then
      table.insert(alerts, "high_controller_temp")
    elseif (data[1] << 11) >> 15 == 1 then
      table.insert(alerts, "load_overpower")
    elseif (data[1] << 12) >> 15 == 1 then
      table.insert(alerts, "load_short_circuit")
    elseif (data[1] << 13) >> 15 == 1 then
      table.insert(alerts, "battery_under_voltage")
    elseif (data[1] << 14) >> 15 == 1 then
      table.insert(alerts, "battery_over_voltage")
    elseif (data[1] << 15) >> 15 == 1 then
      table.insert(alerts, "battery_over_discharge")
    end
  else
    enapter.log("Register 0x120 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  telemetry["alerts"] = alerts
  telemetry["status"] = status

  enapter.send_telemetry(telemetry)
end

function read_configuration(ctx)
  local parameters = {}

  local data, result = modbus.read_holdings(ADDRESS, 0xE002, 13, 1000)
  if data then
    parameters["nominal_battery_capacity"] = data[1]
    parameters["battery_type"] = data[2]
    parameters["overvoltage_threshold"] = data[3] / 10.0
    parameters["charging_voltage_limit"] = data[4] / 10.0
    parameters["equalizing_charging_voltage"] = data[5] / 10.0
    parameters["boost_charging_voltage"] = data[6] / 10.0
    parameters["floating_charging_voltage"] = data[7] / 10.0
    parameters["boost_charging_recovery_voltage"] = data[8] / 10.0
    parameters["overdischarge_recovery_voltage"] = data[9] / 10.0
    parameters["undervoltage_warning_level"] = data[10] / 10.0
    parameters["overdischarge_voltage"] = data[1] / 10.0
    parameters["discharging_voltage_limit"] = data[1] / 10.0
  else
    ctx.error("Registers 0xE002-0xE00E reading failed: "..modbus.err_to_str(result), "error")
  end

  local data, result = modbus.read_holdings(ADDRESS, 0xE010, 5, 1000)
  if data then
    parameters["overdischarge_time_delay_s"] = data[1]
    parameters["equalizing_charging_time_min"] = data[2]
    parameters["boost_charging_time_min"] = data[3]
    parameters["equalizing_charging_interval_days"] = data[4]
    parameters["temp_compensation_factor"] = data[5]
  else
    ctx.error("Registers 0xE010-0xE014 reading failed: "..modbus.err_to_str(result), "error")
  end

  return parameters
end

function write_configuration(ctx, args)
  local nominal_battery_capacity = {args["nominal_battery_capacity"]}
  local result = modbus.write_multiple_holdings(ADDRESS, 0xE014, nominal_battery_capacity, 1000)
  if result ~= 0 then
    ctx.error("Register 0xE014 writing failed: "..modbus.err_to_str(result), "error")
  end
end

enapter.register_command_handler("read_configuration", read_configuration)
enapter.register_command_handler("write_configuration", write_configuration)

function is_on(value)
  if value == 1 then
    return true
  elseif value == 0 then
    return false
  else
    enapter.log("Unknown load status", "error")
    return nil
  end
end

function get_charging_state(value)
  if value then
    if value == 0x00 then
      return "charging_deactivated"
    elseif value == 0x01 then
      return "charging_activated"
    elseif value == 0x02 then
      return "mppt_charging_mode"
    elseif value == 0x03 then
      return "equalizing_charging_mode"
    elseif value == 0x04 then
      return "boost_charging_mode"
    elseif value == 0x05 then
      return "floating_charging_mode"
    elseif value == 0x06 then
      return "current_limiting"
    else
      return "unknown"
    end
  end
end

function get_load_working_mode(value)
  if value then
    if value == 0x00 then
      return "sole_light_control"
    elseif value == 0x01 then
      return "light_control_off_after_1h"
    elseif value == 0x02 then
      return "light_control_off_after_2h"
    elseif value == 0x03 then
      return "light_control_off_after_3h"
    elseif value == 0x04 then
      return "light_control_off_after_4h"
    elseif value == 0x05 then
      return "light_control_off_after_5h"
    elseif value == 0x06 then
      return "light_control_off_after_6h"
    elseif value == 0x07 then
      return "light_control_off_after_7h"
    elseif value == 0x08 then
      return "light_control_off_after_8h"
    elseif value == 0x09 then
      return "light_control_off_after_9h"
    elseif value == 0x0A then
      return "light_control_off_after_10h"
    elseif value == 0x0B then
      return "light_control_off_after_11h"
    elseif value == 0x0C then
      return "light_control_off_after_12h"
    elseif value == 0x0D then
      return "light_control_off_after_13h"
    elseif value == 0x0E then
      return "light_control_off_after_14h"
    elseif value == 0x0F then
      return "manual_mode"
    elseif value == 0x10 then
      return "debugging_mode"
    elseif value == 0x11 then
      return "normal_on_mode"
    else
      return "unknown"
    end
  end
end

function toint(register)
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">I4", raw_str)
end

function tosignedint(value)
  local byte7 = value >> 7
  local result = value & 0x7F
  if byte7 == 1 then
    return result * (-1)
  else
    return result
  end
end

main()
