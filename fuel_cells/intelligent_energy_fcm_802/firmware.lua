-- CAN communication inteface parameter
BAUD_RATE = 500 -- kbps

telemetry = {}
alerts = {}
received_alerts_packet = false
flags_ab = false
flags_cd = false

-- Serial number is sent in two chunks.
-- These variables are needed to verify that we got a
-- complete serial number.
is_serial_number_completed = false
serial_number = ""
temp_serial_number = ""

function main()
  local result = can.init(BAUD_RATE, can_handler)
  if result and result ~= 0 then
    enapter.log("CAN failed: "..result.." "..can.err_to_str(result), "error", true)
    scheduler.add(5000, function()
      enapter.send_telemetry({ status = 'error', alerts = {'can_init_failed'} })
    end)
  else
    scheduler.add(30000, send_properties)
    scheduler.add(1000, send_telemetry)
  end
end

function send_properties()
  local info = { vendor = "Intelligent Energy", model = "FCM 802" }

  if is_serial_number_completed then
    info["serial_number"] = serial_number
    is_serial_number_completed = false
  end

  enapter.send_properties(info)
end

function send_telemetry()
  -- Make sure to add alerts only if they were really reported by the FC
  -- to avoid accidental cleaning of alerts in the Cloud
  if received_alerts_packet then
    telemetry.alerts = alerts
    alerts = {}

    received_alerts_packet = false
    flags_ab = false
    flags_cd = false
  end

  enapter.send_telemetry(telemetry)
  telemetry = {}
end

function can_handler(msg_id, data)
  if msg_id == 0x310 then
    system_serial_number(data)
  elseif msg_id == 0x318 then
    telemetry["software_version"] = software_version(data)
  elseif msg_id == 0x320 then
    telemetry["run_hours"] = touint32(string.sub(data, 1, 4))
    telemetry["total_run_energy"] = touint32(string.sub(data, 5, 8))
  elseif msg_id == 0x328 then
    telemetry["fault_flags_a"] = touint32(string.sub(data, 1, 4))
    telemetry["fault_flags_b"] = touint32(string.sub(data, 5, 8))
    local flag_a = flag_a_error(touint32(string.sub(data, 1, 4)))
    local flag_b = flag_b_error(touint32(string.sub(data, 5, 8)))
    alerts = table.move(flag_a, 1, #flag_a, 1, alerts)
    alerts = table.move(flag_b, 1, #flag_b, #alerts + 1, alerts)
    flags_ab = true
  elseif msg_id == 0x338 then
    telemetry["watt"] = toint16(string.sub(data, 1, 2))
    telemetry["volt"] = divide_by(100.0, toint16(string.sub(data, 3, 4)))
    telemetry["amp"] = divide_by(100.0, toint16(string.sub(data, 5, 6)))
    telemetry["anode_pressure"] = divide_by(10.0, toint16(string.sub(data, 7, 8)))
  elseif msg_id == 0x348 then
    telemetry["outlet_temp"] = divide_by(100.0, toint16(string.sub(data, 1, 2)))
    telemetry["inlet_temp"] = divide_by(100.0, toint16(string.sub(data, 3, 4)))
    telemetry["dcdc_volt_setpoint"] = divide_by(100.0, toint16(string.sub(data, 5, 6)))
    telemetry["dcdc_amp_limit"] = divide_by(100.0, toint16(string.sub(data, 7, 8)))
  elseif msg_id == 0x358 then
    telemetry["louver_pos"] = divide_by(100.0, toint16(string.sub(data, 1, 2)))
    telemetry["fan_sp_duty"] = divide_by(100.0, toint16(string.sub(data, 3, 4)))
  elseif msg_id == 0x368 then
    telemetry["state"] = parse_state(string.byte(data, 1))
    telemetry["load_logic"] = string.byte(data, 2)
    telemetry["out_bits"] = string.byte(data, 3)
  elseif msg_id == 0x378 then
    local flag_c = touint32(string.sub(data, 1, 4))
    if flag_c & 0x00200000 ~= 0 then
      table.insert(alerts, "PurgeCheckShutdown")
    end

    telemetry["fault_flags_c"] = flag_c
    telemetry["fault_flags_d"] = touint32(string.sub(data, 5, 8))

    local flag_d = flag_d_error(touint32(string.sub(data, 5, 8)))
    alerts = table.move(flag_d, 1, #flag_d, #alerts + 1, alerts)

    flags_cd = true
  end
    if flags_ab and flags_cd then
      received_alerts_packet = true
    end
end

function divide_by(factor, value)
  if value then
    return value / factor
  else
    return nil
  end
end

function system_serial_number(data)
  if not is_serial_number_completed then
    if string.byte(data, 1) > 127 then
      if #temp_serial_number == 8 then
        temp_serial_number = temp_serial_number .. string.char(string.byte(data, 1, 1) - 128, string.byte(data, 2, 8))
        serial_number = temp_serial_number
        is_serial_number_completed = true
      else
        temp_serial_number = ""
        is_serial_number_completed = false
      end
    else
      temp_serial_number = string.char(string.byte(data, 1, 8))
    end
  end
end

function flag_a_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, "AnodeOverPressure")
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, "AnodeUnderPressure")
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, "StackOverCurrent")
  end
  if flag & 0x10000000 ~= 0 then
    table.insert(errors, "OutletOverTemperature")
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, "MinCellUndervoltage")
  end
  if flag & 0x04000000 ~= 0 then
    table.insert(errors, "InletOverTemperature")
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, "HboWatchdogFault")
  end
  if flag & 0x01000000 ~= 0 then
    table.insert(errors, "BoardOverTemperature")
  end
  if flag & 0x00800000 ~= 0 then
    table.insert(errors, "HboFan1UnderSpeed")
  end
  if flag & 0x00400000 ~= 0 then
    table.insert(errors, "ValveDefeatCheckFault")
  end
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, "StackUnderVoltage")
  end
  if flag & 0x00100000 ~= 0 then
    table.insert(errors, "StackOverVoltage")
  end
  if flag & 0x00080000 ~= 0 then
    table.insert(errors, "SafetyObserverMismatch")
  end
  if flag & 0x00020000 ~= 0 then
    table.insert(errors, "HboAnodeOverPressure")
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, "HboBoardUnderTemperature")
  end
  if flag & 0x00004000 ~= 0 then
    table.insert(errors, "HboAnodeUnderPressure")
  end
  if flag & 0x00002000 ~= 0 then
    table.insert(errors, "HboBoardOverTemperature")
  end
  if flag & 0x00001000 ~= 0 then
    table.insert(errors, "Fan1NoTacho")
  end
  if flag & 0x00000100 ~= 0 then
    table.insert(errors, "Fan1ErrantSpeed")
  end
  if flag & 0x00000010 ~= 0 then
    table.insert(errors, "InletTxSensorFault")
  end
  if flag & 0x00000008 ~= 0 then
    table.insert(errors, "OutletTxSensorFault")
  end
  if flag & 0x00000004 ~= 0 then
    table.insert(errors, "InvalidSerialNumber")
  end
  if flag & 0x00000002 ~= 0 then
    table.insert(errors, "DcdcCurrentWhenDisabled")
  end
  if flag & 0x00000001 ~= 0 then
    table.insert(errors, "DcdcOverCurrent")
  end
  return errors
end

function flag_b_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, "AmbientOverTemperature")
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, "SibCommsFault")
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, "BoardTxSensorFault")
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, "LowLeakTestPressure")
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, "LouverOpenFault")
  end
  if flag & 0x01000000 ~= 0 then
    table.insert(errors, "StateDependentUnexpectedCurrent")
  end
  if flag & 0x00800000 ~= 0 then
    table.insert(errors, "SystemTypeFault")
  end
  if flag & 0x00040000 ~= 0 then
    table.insert(errors, "ReadConfigFault")
  end
  if flag & 0x00020000 ~= 0 then
    table.insert(errors, "CorruptConfigFault")
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, "ConfigValueRangeFault")
  end
  if flag & 0x00008000 ~= 0 then
    table.insert(errors, "StackVoltageMismatch")
  end
  if flag & 0x00002000 ~= 0 then
    table.insert(errors, "UnexpectedPurgeInhibit")
  end
  if flag & 0x00001000 ~= 0 then
    table.insert(errors, "FuelOnNoVolts")
  end
  if flag & 0x00000800 ~= 0 then
    table.insert(errors, "LeakDetected")
  end
  if flag & 0x00000400 ~= 0 then
    table.insert(errors, "AirCheckFault")
  end
  if flag & 0x00000200 ~= 0 then
    table.insert(errors, "AirCheckFaultShadow")
  end
  return errors
end

function flag_d_error(flag)
  local errors = {}
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, "Dcdc1OutputFault")
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, "CalcCoreTxSensorFault")
  end
  if flag & 0x00008000 ~= 0 then
    table.insert(errors, "CalcCoreOverTemperature")
  end
  if flag & 0x00004000 ~= 0 then
    table.insert(errors, "LouverFailedToOpen")
  end
  return errors
end

function parse_state(state)
  if state == 0x10 then
    return 'fault'
  elseif state == 0x20 then
    return 'steady'
  elseif state == 0x40 then
    return 'run'
  elseif state == 0x80 then
    return 'inactive'
  else
    return state
  end
end

function software_version(data)
  local ok, err = pcall(function()
    return string.format(
      "%u.%u.%u",
      string.byte(data, 1),
      string.byte(data, 2),
      string.byte(data, 3)
    )
  end)
  if not ok then
    enapter.log("Software version parsing failed: "..err, "error")
  end
end

function toint16(data)
  local ok, err = pcall(function()
    return string.unpack(">i2", data)
  end)
  if not ok then
    enapter.log("Convertion to int16 failed: "..err, "error")
  end
end

function touint32(data)
  local ok, err = pcall(function()
    return string.unpack(">I4", data)
  end)
  if not ok then
    enapter.log("Convertion to uint32 failed: "..err, "error")
  end
end

main()
