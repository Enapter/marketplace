function main()
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('impulse', impulse)
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

-- The logic below is straight since we are sending single impluse
-- trought the relay (close-wait-open) with press of the button.

-- Impulse Duration in ms
IMPULSE_DURATION = 1000

function impulse(ctx)
  local ret = rl.impulse(IMPULSE_DURATION)
  if ret ~= 0 then
    ctx.error('Cannot impulse for '..IMPULSE_DURATION..' ms relay')
  end
end

function is_load_powered_on()
  local is_closed, ret = rl.is_closed()
  if ret ~= 0 then
    return nil, 'Cannot read relay status'
  end
  return is_closed, nil
end

main()
