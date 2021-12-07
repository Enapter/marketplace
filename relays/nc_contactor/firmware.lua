function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('power_on', power_on_command)
  enapter.register_command_handler('power_off', power_off_command)
end

function send_properties()
  enapter.send_properties({ contactor_type = 'NC' })
end

function send_telemetry()
  local telemetry = { alerts = {} }

  local is_powered, err = is_load_powered_on()
  if err then
    enapter.log(err, 'error')
    telemetry['status'] = 'error'
    telemetry['alerts'] = {'cannot_read_relay'}
  elseif is_powered then
    telemetry['status'] = 'on'
  else
    telemetry['status'] = 'off'
  end

  enapter.send_telemetry(telemetry)
end

-- The logic below is inverted since we are managing the load
-- trought the NC contactor.

-- RL6 channel where contactor is connected to
RELAY_CHANNEL_ID = 1

function power_on_command(ctx)
  local ret = rl6.open(RELAY_CHANNEL_ID)
  if ret ~= 0 then
    ctx.error('Cannot open relay channel #'..RELAY_CHANNEL_ID..': '..rl6.err_to_str(ret))
  end
end
function power_off_command(ctx)
  local ret = rl6.close(RELAY_CHANNEL_ID)
  if ret ~= 0 then
    ctx.error('Cannot close relay channel #'..RELAY_CHANNEL_ID..': '..rl6.err_to_str(ret))
  end
end

function is_load_powered_on()
  local is_closed, ret = rl6.get(RELAY_CHANNEL_ID)
  if ret ~= 0 then
    return nil, 'Cannot read relay channel #'..RELAY_CHANNEL_ID..': '..rl6.err_to_str(ret)
  end
  return not is_closed, nil
end

main()
