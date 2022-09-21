AUTOSTART_CONFIG = 'autostart'
storage.write(AUTOSTART_CONFIG, 'false')

function main()
  local result = can.init(250, can_handler)
  if result ~= 0 then
    enapter.log("CAN failed: "..can.err_to_str(result), "error", true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
  scheduler.add(500, enable_autostart)

  -- Alerts are sent by FC once per second,
  -- so we use the bigger interval on our side.
  --scheduler.add(2000, send_alerts)

  enapter.register_command_handler("set_start_voltage1", command_set_start_voltage1)
  enapter.register_command_handler("set_start_voltage2", command_set_start_voltage2)
  enapter.register_command_handler("set_stop_voltage1", command_set_stop_voltage1)
  enapter.register_command_handler("set_stop_voltage2", command_set_stop_voltage2)
  enapter.register_command_handler("set_target_voltage1", command_set_target_voltage1)
  enapter.register_command_handler("set_target_voltage2", command_set_target_voltage2)
  enapter.register_command_handler("enable_autostart", command_enable_autostart)
  enapter.register_command_handler("disable_autostart", command_disable_autostart)
end

function send_properties()
  enapter.send_properties({ vendor = "Powercell", model = "PS-5" })
end

telemetry = {}
alerts = {}

function send_telemetry()
  local autostart_enabled = storage.read(AUTOSTART_CONFIG)
  if autostart_enabled == 'true' then
    telemetry.autostart = true
  else
    telemetry.autostart = false
  end

  if #telemetry > 1  then
    telemetry.alerts = alerts
    enapter.send_telemetry(telemetry)
    telemetry = {}
    alerts = {}
  else
    telemetry.status = 'No data'
    telemetry.alerts = {'no_data'}
    enapter.send_telemetry(telemetry)
  end
end

function can_handler(msg_id, data)
  if msg_id == 0x1C800790 then
    local _, state = string.unpack("BB", data)
    state = state >> 4
    telemetry["state"] = state
  end

  if msg_id == 0x1C800B90 then
    local total_power = string.unpack("<I4<I2", data)
    telemetry["total_power"] = total_power / 100.0
  end

  if msg_id == 0x1C800C90 then
    local total_runtime = string.unpack("<I2", data)
    telemetry["total_runtime"] = total_runtime / 10.0
  end

  if msg_id == 0x1C800090 then
    local target_voltage1, stop_voltage1, start_voltage1 = string.unpack("<I2<I2<I2", data)
    telemetry["target_voltage1"] = target_voltage1 / 100.0
    telemetry["stop_voltage1"] = stop_voltage1 / 100.0
    telemetry["start_voltage1"] = start_voltage1 / 100.0
  end

  if msg_id == 0x1C800890 then
    local current, voltage, power = string.unpack("<I2<I2<I2", data)
    telemetry["current1"] = current / 10.0
    telemetry["voltage1"] = voltage / 100.0
    telemetry["power1"] = power
  end

  if msg_id == 0x1C800990 then
    local current, voltage, power = string.unpack("<I2<I2<I2", data)
    telemetry["current2"] = current / 10.0
    telemetry["voltage2"] = voltage / 100.0
    telemetry["power2"] = power
  end

  if msg_id == 0x1C800A90 then
    local _, coolant_temp, coolant_duty = string.unpack("I1I1I1", data)
    telemetry["coolant_temp"] = coolant_temp - 50
    telemetry["coolant_duty"] = coolant_duty
  end

  if msg_id == 0x1C800490 then
    local _, stop_alarm_active = string.unpack("I4I4", data)
    local stop_alarms = parse_stop_alarms(stop_alarm_active)
    alerts = table.move(stop_alarms, 1, #stop_alarms, #alerts + 1, alerts)
  end

  if msg_id == 0x1C800590 then
    local _, shut_alarm_active = string.unpack("I4I4", data)
    local shut_alarms = parse_shutdown_alarms(shut_alarm_active)
    alerts = table.move(shut_alarms, 1, #shut_alarms, #alerts + 1, alerts)
  end

  if msg_id == 0x1C800690 then
    local _, warning_active = string.unpack("I4I4", data)
    local warnings = parse_warnings(warning_active)
    alerts = table.move(warnings, 1, #warnings, #alerts + 1, alerts)
  end
end

function parse_stop_alarms(code)
  local alarms = {}
  if code & 0x1 ~= 0 then
    table.insert(alarms, 'stop_manual_error')
  elseif code & 0x2 ~= 0 then
    table.insert(alarms, 'stop_init_error')
  elseif code & 0x4 ~= 0 then
    table.insert(alarms, 'stop_can_error')
  elseif code & 0x8 ~= 0 then
    table.insert(alarms, 'stop_platform_exception_err')
  elseif code & 0x10 ~= 0 then
    table.insert(alarms, 'stop_platform_over_temp')
  elseif code & 0x20 ~= 0 then
    table.insert(alarms, 'stop_platform_misc_err')
  elseif code & 0x40 ~= 0 then
    table.insert(alarms, 'stop_hmi_error')
  elseif code & 0x80 ~= 0 then
    table.insert(alarms, 'stop_calibration_err')
  elseif code & 0x100 ~= 0 then
    table.insert(alarms, 'stop_pcb_watchdog_err')
  elseif code & 0x200 ~= 0 then
    table.insert(alarms, 'stop_plc_watchdog_err')
  elseif code & 0x400 ~= 0 then
    table.insert(alarms, 'stop_hydrogen_detection')
  elseif code & 0x1000 ~= 0 then
    table.insert(alarms, 'stop_high_anode_pressure')
  elseif code & 0x2000 ~= 0 then
    table.insert(alarms, 'stop_high_cathode_pressure')
  elseif code & 0x4000 ~= 0 then
    table.insert(alarms, 'stop_over_temperature')
  elseif code & 0x8000 ~= 0 then
    table.insert(alarms, 'stop_h2_sensor_error')
  elseif code & 0x20000 ~= 0 then
    table.insert(alarms, 'stop_stack_over_current')
  elseif code & 0x40000 ~= 0 then
    table.insert(alarms, 'stop_stack_high_diff_current')
  elseif code & 0x80000 ~= 0 then
    table.insert(alarms, 'stop_cvm_pin_disconnect')
  else
    table.insert(alarms, 'stop_undefined')
  end
  return alarms
end

function parse_shutdown_alarms(code)
  local alarms = {}
  if code & 0x1 ~= 0 then
    table.insert(alarms, 'shutdown_manual_error')
  elseif code & 0x2 ~= 0 then
    table.insert(alarms, 'shutdown_component_error')
  elseif code & 0x4 ~= 0 then
    table.insert(alarms, 'shutdown_anode_pump_error')
  elseif code & 0x8 ~= 0 then
    table.insert(alarms, 'shutdown_cathode_comp_error')
  elseif code & 0x10 ~= 0 then
    table.insert(alarms, 'shutdown_dcdc_error')
  elseif code & 0x100 ~= 0 then
    table.insert(alarms, 'shutdown_high_anode_pressure')
  elseif code & 0x200 ~= 0 then
    table.insert(alarms, 'shutdown_low_anode_pressure')
  elseif code & 0x400 ~= 0 then
    table.insert(alarms, 'shutdown_high_cathode_pressure')
  elseif code & 0x800 ~= 0 then
    table.insert(alarms, 'shutdown_hydrogen_detection')
  elseif code & 0x1000 ~= 0 then
    table.insert(alarms, 'shutdown_start_up_error')
  elseif code & 0x4000 ~= 0 then
    table.insert(alarms, 'shutdown_low_stack_temperature')
  elseif code & 0x8000 ~= 0 then
    table.insert(alarms, 'shutdown_high_stack_temperature')
  elseif code & 0x10000 ~= 0 then
    table.insert(alarms, 'shutdown_stack_high_diff_temp')
  elseif code & 0x100000 ~= 0 then
    table.insert(alarms, 'shutdown_low_fcm_fan_flowrate')
  elseif code & 0x800000 ~= 0 then
    table.insert(alarms, 'shutdown_low_coolant_flowrate')
  elseif code & 0x2000000 ~= 0 then
    table.insert(alarms, 'shutdown_external_can_signal_lost')
  elseif code & 0x10000000 ~= 0 then
    table.insert(alarms, 'shutdown_low_cell_voltage')
  elseif code & 0x40000000 ~= 0 then
    table.insert(alarms, 'shutdown_dcdc_max_current_flow')
  else
    table.insert(alarms, 'shutdown_undefined')
  end
  return alarms
end

function parse_warnings(code)
  local alarms = {}
  if code & 0x1 ~= 0 then
    table.insert(alarms, 'manual_error')
  elseif code & 0x2 ~= 0 then
    table.insert(alarms, 'warn_high_cathode_pressure')
  elseif code & 0x4 ~= 0 then
    table.insert(alarms, 'warn_internal_clock_error')
  elseif code & 0x8 ~= 0 then
    table.insert(alarms, 'warn_low_cell_voltage')
  elseif code & 0x10 ~= 0 then
    table.insert(alarms, 'warn_low_coolant_level')
  elseif code & 0x20 ~= 0 then
    table.insert(alarms, 'warn_cabinet_temp_sensor_err')
  elseif code & 0x40 ~= 0 then
    table.insert(alarms, 'warn_external_can_signal_lost')
  else
    table.insert(alarms, 'warn_undefined')
  end
  return alarms
end

function command_set_start_voltage1(ctx, args)
    local request = string.pack("I2I2", 0, math.floor(args.voltage * 100))
    local result = can.err_to_str(can.send(0x1C000090, request))
    if result ~= 'Success' then
      ctx.error(result)
    else
      return result
    end
end

function command_set_start_voltage2(ctx, args)
    local request = string.pack("I2I2", 10, math.floor(args.voltage * 100))
    local result = can.err_to_str(can.send(0x1C000090, request))
    if result ~= 'Success' then
      ctx.error(result)
    else
      return result
    end
end

function command_set_stop_voltage1(ctx, args)
    local request = string.pack("I2I2", 1, math.floor(args.voltage * 100))
    local result = can.err_to_str(can.send(0x1C000090, request))
    if result ~= 'Success' then
      ctx.error(result)
    else
      return result
    end
end

function command_set_stop_voltage2(ctx, args)
    local request = string.pack("I2I2", 11, math.floor(args.voltage * 100))
    local result = can.err_to_str(can.send(0x1C000090, request))
    if result ~= 'Success' then
      ctx.error(result)
    else
      return result
    end
end

function command_set_target_voltage1(ctx, args)
    local request = string.pack("I2I2", 3, math.floor(args.voltage * 100))
    local result = can.err_to_str(can.send(0x1C000090, request))
    if result ~= 'Success' then
      ctx.error(result)
    else
      return result
    end
end

function command_set_target_voltage2(ctx, args)
    local request = string.pack("I2I2", 14, math.floor(args.voltage * 100))
    local result = can.err_to_str(can.send(0x1C000090, request))
    if result ~= 'Success' then
      ctx.error(result)
    else
      return result
    end
end

function command_enable_autostart(ctx)
  local result = storage.write(AUTOSTART_CONFIG, 'true')
  if result ~= 0 then
    ctx.error('Storage write failed: '..storage.err_to_str(result))
  end
end

function command_disable_autostart(ctx)
  local result = storage.write(AUTOSTART_CONFIG, 'false')
  if result ~= 0 then
    ctx.error('Storage write failed: '..storage.err_to_str(result))
  end
end

function enable_autostart()
    local autostart, err = storage.read(AUTOSTART_CONFIG)
    if err == 0 then
      if autostart == 'true' then
        local request = string.pack("B", 1)
        local result = can.err_to_str(can.send(0x14000090, request))
        if result ~= 'Success' then
          enapter.log('Autostart failed: '..result, 'error')
          table.insert(alerts, 'autostart_fail')
        end
      end
    else
      enapter.log('Config read failed: '..err, 'error')
    end
end

main()
