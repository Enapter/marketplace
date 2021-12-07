telemetry = {}

function main()
  local result = can.init(500, can_handler)
  if result ~= 0 then
    enapter.log("CAN failed: "..result.." "..can.err_to_str(result), "error", true)
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, metrics)
end

function properties()
  enapter.send_properties({ vendor = "H2SYS", model = "ACS 1000" })
end

function metrics()
  if next(telemetry) ~= nil then
    enapter.send_telemetry(telemetry)
  else
    enapter.log("No data", error, true)
  end
end

function can_handler(msg_id, data)
  if msg_id == 0x666 then
    local byte0, byte1, byte3 = string.unpack("I1I1I1", data)
    local warning = "ok"
    local errors = {}

    if byte0 & 1 ~=0 then
      table.insert(errors, "low_cell_voltage")
    end
    if byte0 & 2 ~=0 then
      table.insert(errors, "fuel_cell_high_temperature")
    end
    if byte0 & 4 ~= 0 then
      table.insert(errors, "fuel_cell_low_voltage")
    end
    if byte0 & 8 ~= 0 then
      table.insert(errors, "low_h2_pressure")
    end
    if byte0 & 16 ~= 0 then
      table.insert(errors, "auxilary_voltage")
    end
    if byte0 & 32 ~= 0 then
      warning = "fcvm_board"
    end
    if byte0 & 64 ~= 0 then
      warning = "idle_state"
    end
    if byte0 & 128 ~= 0 then
      table.insert(errors, "start_phase_error")
    end

    if byte1 & 1 ~=0 then
      table.insert(errors, "fccc_board")
    end
    if byte1 & 2 ~=0 then
      table.insert(errors, "can_fail")
    end
    if byte1 & 4 ~= 0 then
      table.insert(errors, "fuel_cell_current")
    end
    if byte1 & 16 ~= 0 then
      table.insert(errors, "fan_error")
    end
    if byte1 & 32 ~= 0 then
      table.insert(errors, "h2_leakage")
    end
    if byte1 & 64 ~= 0 then
      table.insert(errors, "low_internal_pressure")
    end
    if byte1 & 128 ~= 0 then
      table.insert(errors, "high_internal_pressure")
    end

    if byte3 & 1 ~= 0 then
      table.insert(errors, "fuel_cell_temperature_variation")
    end
    telemetry["warning"] = warning
    telemetry["alerts"] = errors
  end

  if msg_id == 0x090 then
    local voltage, current = string.unpack(">I2>I2", data)
    telemetry["voltage"] = 0.0216 * voltage
    telemetry["current"] = (current - 2048) * 0.06105
  end

  if msg_id == 0x091 then
    local temperature, _, _, _, internal_h2_pressure, state = string.unpack("I1I1I1I1I1I1", data)
    telemetry["temperature"] = to7bits(temperature)
    telemetry["internal_h2_pressure"] = to7bits(internal_h2_pressure) / 10.0
    if state == 0 then
      telemetry["state"] = "auto_check"
    elseif state == 1 then
      telemetry["state"] = "h2_inlet_pressure"
    elseif state == 10 then
      telemetry["state"] = "waiting"
    elseif state >= 11 and state <= 14  then
      telemetry["state"] = "start-up"
    elseif state == 15  then
      telemetry["state"] = "idle"
    elseif state == 17  then
      telemetry["state"] = "operation"
    elseif state == 21  then
      telemetry["state"] = "switch_off"
    elseif state == 22  then
      telemetry["state"] = "locked_out"
    end
  end

end

function to7bits(data)
  local value = data & 0x7F
  local sign = data >> 7

  if sign == 1 then
    return value * (-1)
  else
    return value
  end
end

function start()
  local command = string.pack("BBBBBBBB",1,0,0,0,0,0,0,0)
  return can.send(0x001, command)
end

function stop()
  local command = string.pack("BBBBBBBB",0,1,0,0,0,0,0,0)
  return can.send(0x001, command)
end

enapter.register_command_handler("start", function(ctx)
  if start() ~= 0 then
    ctx.error("CAN failed")
  end
end)

enapter.register_command_handler("stop", function(ctx)
  if stop() ~= 0 then
    ctx.error("CAN failed")
  end
end)

main()
