local FCPM_ID = 1 -- 2 / 3 / 4 / 5
local telemetry = {}

function main()
  local result = can.init(250, can_handler)
  if result ~= 0 then
    enapter.log("CAN init failed: "..result.." "..can.err_to_str(result), "error", true)
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, metrics)
end

function properties()
  enapter.send_properties({ vendor = "Cummins", model = "HyPM HD FCPM" })
end

function metrics()
  enapter.send_telemetry(telemetry)
end

function can_handler(msg_id, data)
  if msg_id == 0x1D0 + FCPM_ID then
    telemetry["cdr"] = toint16(data[1], "unsign")
  elseif msg_id == 0x240 + FCPM_ID then
    local all_states = {}
    all_states[0x01] = "standby"
    all_states[0x02] = "startup"
    all_states[0x03] = "run"
    all_states[0x04] = "shutdown"
    all_states[0x05] = "fault"
    all_states[0x06] = "cooldown"
    all_states[0x07] = "cooldown_complete"
    all_states[0x08] = "freeze_prep"
    all_states[0x09] = "freeze_prep_complete"
    all_states[0x0A] = "anode_purge"
    all_states[0x0B] = "anode_purge_complete"
    all_states[0x0C] = "leak_check"
    all_states[0x0D] = "leak_check_complete"
    all_states[0x0E] = "prime"
    all_states[0x0F] = "prime_complete"

    telemetry["state"] = all_states[data[1]]
    telemetry["cda"] = toint16(data[3], "unsign")
    telemetry["fc_stack_current"] = toint16(data[4], "sign")
    telemetry["fc_stack_voltage"] = toint16(data[5], "unsign")
  elseif msg_id == 0x2C0 + FCPM_ID then
    telemetry["alerts"] = check_alerts(data)
  elseif msg_id == 0x340 + FCPM_ID then
    telemetry["coolant_temp"] = toint16(data[1], "unsign")
    telemetry["coolant_setpoint"] = toint16(data[2], "unsign")
  end
end

function toint16(data, fmt)
  local perbitfactor = 10.0

  if fmt == "unsign" then
    local raw_str = string.pack("BB", data>>8, data&0xFF)
    return string.unpack(">I2", raw_str) / perbitfactor
  else
    local raw_str = string.pack("bb", data>>8, data&0xFF)
    return string.unpack(">i2", raw_str) / perbitfactor
  end
end

function check_alerts(data)
  local faults = {}
  faults[0x01] = "stack_under_voltage_fault"
  faults[0x02] = "coolant_over_temp_fault"
  faults[0x10] = "comm_heartbeat_fault"
  faults[0x40] = "internal_system_stop_fault"
  faults[0x100] = "leak_check_failed_fault"
  faults[0x200] = "freeze_mode_fault"
  faults[0x400] = "coolant_low_flow_fault"
  faults[0x800] = "idle_fault"
  faults[0x1000] = "anode_purge_fault"
  faults[0x2000] = "stack_current_fault"
  faults[0x4000] = "h2_supply_over_pressure_fault"
  faults[0x4000] = "h2_supply_under_pressure_fault"

  local alarms = {}
  alarms[0x01] = "h2_sensor_out_of_range_alarm"
  alarms[0x02] = "air_flow_out_of_range_alarm"
  alarms[0x04] = "current_sensor_out_of_range_alarm"
  alarms[0x08] = "coolant_temp_high_alarm"
  alarms[0x10] = "system_over_power_alarm"
  alarms[0x20] = "air_flow_in_nonrun_state_alarm"
  alarms[0x40] = "blower_low_flow_alarm"
  alarms[0x80] = "anode_pump_speed_alarm" --
  alarms[0x100] = "coolant_temp_out_of_range_alarm"
  alarms[0x200] = "blower_low_voltage_alarm"
  alarms[0x400] = "recovery_alarm"
  alarms[0x800] = "coolant_low_flow_alarm"
  alarms[0x1000] = "stack_low_current_alarm"
  alarms[0x2000] = "eFCVM_bad_finger_alarm"
  alarms[0x4000] = "EEPROM_Error_alarm"
  alarms[0x8000] = "EMP_pump_alarm"

  local all_alerts = {}
  table.insert(all_alerts, faults[data[1]])
  table.insert(all_alerts, alarms[data[5]])

  return all_alerts
end

COMMAND_MSG_ID = 0x1c0 + FCPM_ID

function standby()
  return can.send(COMMAND_MSG_ID, 0x01)
end

function run()
  return can.send(COMMAND_MSG_ID, 0x02)
end

function cooldown()
  return can.send(COMMAND_MSG_ID, 0x03)
end

function freeze_prep()
  return can.send(COMMAND_MSG_ID, 0x04)
end

function anode_purge()
  return can.send(COMMAND_MSG_ID, 0x05)
end

function leak_check()
  return can.send(COMMAND_MSG_ID, 0x06)
end

function prime()
  return can.send(COMMAND_MSG_ID, 0x07)
end

enapter.register_command_handler("standby", function(ctx)
  if standby() ~= 0 then
    ctx.error("CAN failed")
  end
end)

enapter.register_command_handler("run", function(ctx)
  if run() ~= 0 then
    ctx.error("CAN failed")
  end
end)

enapter.register_command_handler("cooldown", function(ctx)
  if cooldown() ~= 0 then
    ctx.error("CAN failed")
  end
end)

enapter.register_command_handler("freeze_prep", function(ctx)
  if freeze_prep() ~= 0 then
    ctx.error("CAN failed")
  end
end)

enapter.register_command_handler("anode_purge", function(ctx)
  if anode_purge() ~= 0 then
    ctx.error("CAN failed")
  end
end)

enapter.register_command_handler("leak_check", function(ctx)
  if leak_check() ~= 0 then
    ctx.error("CAN failed")
  end
end)

enapter.register_command_handler("prime", function(ctx)
  if prime() ~= 0 then
    ctx.error("CAN failed")
  end
end)

main()
