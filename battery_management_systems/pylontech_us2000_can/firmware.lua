--- CAN bus interface baud rate
BAUD_RATE = 500 -- kbps

telemetry = {}

function main()
  local err = can.init(BAUD_RATE, can_handler)
  if err and err ~= 0 then
    enapter.log("CAN failed: "..err.." "..can.err_to_str(err), "error", true)
    scheduler.add(5000, function()
      enapter.send_telemetry({ status = 'error', alerts = {'can_init_failed'} })
    end)
  else
    scheduler.add(30000, send_properties)
    scheduler.add(1000, send_telemetry)
  end
end

function send_properties()
  enapter.send_properties({ vendor = "PylonTech", model = "US2000" })
end

-- Holds the number of `send_telemetry` that had an empty `telemetry`
local missed_telemetry_count = 0

function send_telemetry()
  if telemetry[1] ~= nil then
    enapter.send_telemetry(telemetry)
    -- Cleanup telemetry and let it be refilled by `can_handler`
    telemetry = {}
    missed_telemetry_count = 0
  else
    missed_telemetry_count = missed_telemetry_count + 1
    if missed_telemetry_count > 5 then
      enapter.send_telemetry({
        status = 'read_error',
        alerts = {'can_fail'}
      })
    end
  end
end

function can_handler(msg_id, data)
  local alerts = {}
  local status = "ok"

  if msg_id == 0x351 then
    status, alerts = battery_metrics(data, status, alerts)
  end

  if msg_id == 0x355 then
    status, alerts = soc_and_soh(data, status, alerts)
  end

  if msg_id == 0x356 then
    status, alerts = module_or_system_metrics(data, status, alerts)
  end

  if msg_id == 0x359 then
    status, alerts = alarms(data, status, alerts)
  end

  if msg_id == 0x35C then
    status, alerts = charge_discharge_flags(data, status, alerts)
  end

  telemetry["status"] = status
  telemetry["alerts"] = alerts
end

function battery_metrics(data, status, alerts)
  local ok, err = pcall(function()
    local byte_pair1, byte_pair2, byte_pair3, byte_pair4 = string.unpack("I2i2i2I2", data)
    telemetry["battery_charge_voltage"] = byte_pair1 / 10.0
    telemetry["charge_current_limit"] = byte_pair2 / 10.0
    telemetry["discharge_current_limit"] = byte_pair3 / 10.0
    telemetry["discharge_voltage"] = byte_pair4 / 10.0
  end)
  if not ok then
    enapter.log("Reading message 0x351 failed: "..err, "error")
    table.insert(alerts, "can_fail")
    status = "read_error"
  end
  return status, alerts
end

function soc_and_soh(data, status, alerts)
  local ok, err = pcall(function()
    local soc, soh = string.unpack("I2I2", data)
    telemetry["soh"] = soh
    telemetry["soc"] = soc
  end)
  if not ok then
    enapter.log("Reading message 0x355 failed: "..err, "error")
    table.insert(alerts, "can_fail")
    status = "read_error"
  end
  return status, alerts
end

function module_or_system_metrics(data, status, alerts)
  local ok, err = pcall(function()
    local voltage, current, temp = string.unpack("I2i2i2", data)
    telemetry["voltage"] = voltage / 100.0
    telemetry["total_current"] = current / 10.0
    telemetry["average_cell_temperature"] = temp / 10.0
  end)
  if not ok then
    enapter.log("Reading message 0x356 failed: "..err, "error")
    table.insert(alerts, "can_fail")
    status = "read_error"
  end
  return status, alerts
end

function alarms(data, status, alerts)
  local ok, err = pcall(function()
    local byte0, byte1, byte2, byte3 = string.unpack("<I1<I1<I1<I1", data)

    if byte0 & 2 ~=0 then
      table.insert(alerts, "cell_or_module_over_voltage")
    end
    if byte0 & 4 ~= 0 then
      table.insert(alerts, "cell_or_module_under_voltage")
    end
    if byte0 & 8 ~= 0 then
      table.insert(alerts, "cell_over_temperature")
    end
    if byte0 & 16 ~= 0 then
      table.insert(alerts, "cell_under_temperature")
    end
    if byte0 & 16 ~= 0 then
      table.insert(alerts, "discharge_over_current")
    end
    if byte0 == 0 then
      telemetry["has_protection1"] = false
    else
      telemetry["has_protection1"] = true
      status = "warning"
    end

    if byte1 & 1 ~=0 then
      table.insert(alerts, "charge_over_current")
    end
    if byte1 & 8 ~= 0 then
      table.insert(alerts, "system_error")
    end
    if byte1 == 0 then
      telemetry["has_protection2"] = false
    else
      telemetry["has_protection2"] = true
      status = "warning"
    end

    if byte2 & 2 ~=0 then
      table.insert(alerts, "cell_or_module_high_voltage")
    end
    if byte2 & 4 ~= 0 then
      table.insert(alerts, "cell_or_module_low_voltage")
    end
    if byte2 & 8 ~= 0 then
      table.insert(alerts, "cell_high_temperature")
    end
    if byte2 & 16 ~= 0 then
      table.insert(alerts, "cell_low_temperature")
    end
    if byte2 & 16 ~= 0 then
      table.insert(alerts, "discharge_high_current")
    end
    if byte2 == 0 then
      telemetry["has_alarm1"] = false
    else
      telemetry["has_alarm1"] = true
      status = "warning"
    end

    if byte3 & 1 ~=0 then
      table.insert(alerts, "charge_high_current")
    end
    if byte3 & 8 ~= 0 then
      table.insert(alerts, "internal_communication_fail")
    end
    if byte3 == 0 then
      telemetry["has_alarm2"] = false
    else
      telemetry["has_alarm2"] = true
      status = "warning"
    end
  end)
  if not ok then
    enapter.log("Reading message 0x351 failed: "..err, "error")
    table.insert(alerts, "can_fail")
    status = "read_error"
  end
  return status, alerts
end

function charge_discharge_flags(data, status, alerts)
  local ok, err = pcall(function()
    local byte = string.unpack("<I1", data)
    if byte & 8 ~= 0 then
      telemetry["request_force_charge"] = true
    else
      telemetry["request_force_charge"] = false
    end
    if byte & 16 ~= 0 then
      telemetry["request_force_charge_2"] = true
    else
      telemetry["request_force_charge_2"] = false
    end
    if byte & 32 ~= 0 then
      telemetry["request_force_charge_1"] = true
    else
      telemetry["request_force_charge_1"] = false
    end
    if byte & 64 ~= 0 then
      telemetry["discharge_enable"] = true
    else
      telemetry["discharge_enable"] = false
    end
    if byte & 128 ~= 0 then
      telemetry["charge_enable"] = true
    else
      telemetry["charge_enable"] = false
    end
  end)
  if not ok then
    enapter.log("Reading message 0x35C failed: "..err, "error")
    table.insert(alerts, "can_fail")
    status = "read_error"
  end
  return status, alerts
end

main()
