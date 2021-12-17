-- CAN bus communication interface paramter
BAUD_RATE = 500 -- kbps

received_alerts_packet = false
telemetry = {}
alerts = {}

function main()
  local result = can.init(BAUD_RATE, can_handler)
  if result ~= 0 then
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
  enapter.send_properties({ vendor = "H2SYS", model = "ACS 1000" })
end

-- Holds the number of `send_telemetry` that had an empty `telemetry`
local missed_telemetry_count = 0

function send_telemetry()
  if telemetry[1] ~= nil then
    if received_alerts_packet then
      telemetry.alerts = alerts
      alerts = {}
      received_alerts_packet = false
    end

    enapter.send_telemetry(telemetry)
    -- Cleanup telemetry and let it be refilled by `can_handler`
    telemetry = {}
    missed_telemetry_count = 0
  else
    missed_telemetry_count = missed_telemetry_count + 1
    if missed_telemetry_count > 5 then
      enapter.send_telemetry({
        status = 'read_error',
        alerts = {'communication_failed'}
      })
    end
  end
end

function can_handler(msg_id, data)
  if msg_id == 0x666 then
    get_faults(data)
    received_alerts_packet = true
  end

  if msg_id == 0x090 then
    local ok, err = pcall(function()
      local voltage, current = string.unpack(">I2>I2", data)
      telemetry["voltage"] = 0.0216 * voltage
      telemetry["current"] = (current - 2048) * 0.06105
    end)
    if not ok then
      table.insert(telemetry["alerts"], "communication_failed")
      enapter.log("Msg_id 0x090 data failed: "..err, "error")
    end
  end

  if msg_id == 0x091 then
    get_system_info(data)
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

function get_faults(data)
  local ok, err = pcall(function()
    local byte0, byte1, byte3 = string.unpack("I1I1I1", data)
    local warning = "ok"
    local alerts = {}

    if byte0 & 1 ~=0 then
      table.insert(alerts, "low_cell_voltage")
    end
    if byte0 & 2 ~=0 then
      table.insert(alerts, "fuel_cell_high_temperature")
    end
    if byte0 & 4 ~= 0 then
      table.insert(alerts, "fuel_cell_low_voltage")
    end
    if byte0 & 8 ~= 0 then
      table.insert(alerts, "low_h2_pressure")
    end
    if byte0 & 16 ~= 0 then
      table.insert(alerts, "auxilary_voltage")
    end
    if byte0 & 32 ~= 0 then
      warning = "fcvm_board"
    end
    if byte0 & 64 ~= 0 then
      warning = "idle_state"
    end
    if byte0 & 128 ~= 0 then
      table.insert(alerts, "start_phase_error")
    end

    if byte1 & 1 ~=0 then
      table.insert(alerts, "fccc_board")
    end
    if byte1 & 2 ~=0 then
      table.insert(alerts, "can_fail")
    end
    if byte1 & 4 ~= 0 then
      table.insert(alerts, "fuel_cell_current")
    end
    if byte1 & 16 ~= 0 then
      table.insert(alerts, "fan_error")
    end
    if byte1 & 32 ~= 0 then
      table.insert(alerts, "h2_leakage")
    end
    if byte1 & 64 ~= 0 then
      table.insert(alerts, "low_internal_pressure")
    end
    if byte1 & 128 ~= 0 then
      table.insert(alerts, "high_internal_pressure")
    end

    if byte3 & 1 ~= 0 then
      table.insert(alerts, "fuel_cell_temperature_variation")
    end

    telemetry["warning"] = warning
    telemetry["alerts"] = alerts
  end)
  if not ok then
    telemetry["alerts"] = {"communication_failed"}
    enapter.log("Msg_id 0x666 data failed: "..err, "error")
  end
end

function get_system_info(data)
  local ok, err = pcall(function()
    local temperature, _, _, _, internal_h2_pressure, state = string.unpack("I1I1I1I1I1I1", data)
    telemetry["temperature"] = to7bits(temperature)
    telemetry["internal_h2_pressure"] = to7bits(internal_h2_pressure) / 10.0
    if state == 0 then
      telemetry["status"] = "auto_check"
    elseif state == 1 then
      telemetry["status"] = "h2_inlet_pressure"
    elseif state == 10 then
      telemetry["status"] = "waiting"
    elseif state >= 11 and state <= 14  then
      telemetry["status"] = "start-up"
    elseif state == 15  then
      telemetry["status"] = "idle"
    elseif state == 17  then
      telemetry["status"] = "operation"
    elseif state == 21  then
      telemetry["status"] = "switch_off"
    elseif state == 22  then
      telemetry["status"] = "locked_out"
    end
  end)
  if not ok then
    table.insert(telemetry["alerts"], "communication_failed")
    enapter.log("Msg_id 0x091 data failed: "..err, "error")
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

main()
