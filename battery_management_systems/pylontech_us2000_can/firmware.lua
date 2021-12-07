telemetry = {}

function main()
  local err = can.init(500, can_handler)
  if err and err ~= 0 then
    enapter.log("CAN failed: "..err.." "..can.err_to_str(err), "error", true)
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, metrics)
end

function properties()
  enapter.send_properties({ vendor = "PylonTech", model = "US2000" })
end

function metrics()
  if next(telemetry) ~= nil then
    enapter.send_telemetry(telemetry)
  end
end

function can_handler(msg_id, data)
  if msg_id == 0x359 then
    local byte0, byte1, byte2, byte3 = string.unpack("<I1<I1<I1<I1", data)
    local alerts = {}

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
      telemetry["status"] = "warning"
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
      telemetry["status"] = "warning"
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
      telemetry["status"] = "warning"
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
      telemetry["status"] = "warning"
    end

    if #alerts == 0 then
      telemetry["status"] = "ok"
    end

    telemetry["alerts"] = alerts
  end

  if msg_id == 0x351 then
    local byte_pair1, byte_pair2, byte_pair3, byte_pair4 = string.unpack("I2i2i2I2", data)
    telemetry["battery_charge_voltage"] = byte_pair1 / 10.0
    telemetry["charge_current_limit"] = byte_pair2 / 10.0
    telemetry["discharge_current_limit"] = byte_pair3 / 10.0
    telemetry["discharge_voltage"] = byte_pair4 / 10.0
  end
  if msg_id == 0x355 then
    local soc, soh = string.unpack("I2I2", data)
    telemetry["soh"] = soh
    telemetry["soc"] = soc
  end
  if msg_id == 0x356 then
    local voltage, current, temp = string.unpack("I2i2i2", data)
    telemetry["voltage"] = voltage / 100.0
    telemetry["total_current"] = current / 10.0
    telemetry["average_cell_temperature"] = temp / 10.0
  end
  if msg_id == 0x35C then
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
  end
end

main()
