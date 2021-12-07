POWER_FCM_RELAY_ID = 4
START_FCM_RELAY_ID = 1

function main()
  enapter.register_command_handler('power_on', power_on_command)
  enapter.register_command_handler('power_off', power_off_command)
  enapter.register_command_handler('start', start_command)
  enapter.register_command_handler('stop', stop_command)

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'ENP-RL6' })
end

function send_telemetry()
  local telemetry = {}

  telemetry.powered = is_powered()
  telemetry.started = is_started()

  if telemetry.started then
    telemetry.status = 'started'
  elseif telemetry.powered then
    telemetry.status = 'powered'
  else
    telemetry.status = 'off'
  end

  enapter.send_telemetry(telemetry)
end

function is_powered()
  return rl6.get(POWER_FCM_RELAY_ID)
end

function is_started()
  return rl6.get(START_FCM_RELAY_ID)
end

function power_on_command(ctx)
  local result = rl6.close(POWER_FCM_RELAY_ID)
  if result and result ~= 0 then
    ctx.error('Unable to close relay channel '..POWER_FCM_RELAY_ID..': '..rl6.err_to_str(result))
  end
end

function power_off_command(ctx)
  local result = rl6.open(POWER_FCM_RELAY_ID)
  if result and result ~= 0 then
    ctx.error('Unable to open relay channel '..POWER_FCM_RELAY_ID..': '..rl6.err_to_str(result))
  end
end

function start_command(ctx)
  if not is_powered() then
    ctx.error("Fuel cell is not powered, use 'Power On' command to power it first.")
  end
  local result = rl6.close(START_FCM_RELAY_ID)
  if result and result ~= 0 then
    ctx.error('Unable to close relay channel '..START_FCM_RELAY_ID..': '..rl6.err_to_str(result))
  end
end

function stop_command(ctx)
  if not is_powered() then
    ctx.error("Fuel cell is not powered, use 'Power On' command to power it first.")
  end
  local result = rl6.open(START_FCM_RELAY_ID)
  if result and result ~= 0 then
    ctx.error('Unable to open relay channel '..START_FCM_RELAY_ID..': '..rl6.err_to_str(result))
  end
end

main()
