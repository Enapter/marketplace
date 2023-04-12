local config = require('enapter.ucm.config')

POWER_RELAY_CONFIG = 'power_relay'
START_RELAY_CONFIG = 'start_relay'

function main()
  enapter.register_command_handler('power_on', power_on_command)
  enapter.register_command_handler('power_off', power_off_command)
  enapter.register_command_handler('start', start_command)
  enapter.register_command_handler('stop', stop_command)

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [POWER_RELAY_CONFIG] = { type = 'number', default = 4, required = true },
    [START_RELAY_CONFIG] = { type = 'number', default = 1, required = true },
  })
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'ENP-RL6' })
end

function send_telemetry()
  local telemetry = { alerts = {} }

  local powered, err = is_powered()
  if err then
    telemetry.alerts = { 'cannot_read_relay_state' }
    telemetry.alert_details = { cannot_read_relay_state = err }
  else
    telemetry.powered = powered
  end

  local started, err = is_started()
  if err then
    telemetry.alerts = { 'cannot_read_relay_state' }
    telemetry.alert_details = { cannot_read_relay_state = err }
  else
    telemetry.started = started
  end

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
  local channel, err = config.read(POWER_RELAY_CONFIG)
  if err then
    return nil, err
  end
  local closed, err = rl6.get(math.tointeger(channel))
  if err and err ~= 0 then
    return nil, rl6.err_to_str(err)
  end
  return closed, nil
end

function is_started()
  local channel, err = config.read(START_RELAY_CONFIG)
  if err then
    return nil, err
  end
  local closed, err = rl6.get(math.tointeger(channel))
  if err and err ~= 0 then
    return nil, rl6.err_to_str(err)
  end
  return closed, nil
end

function power_on_command(ctx)
  local channel, err = config.read(POWER_RELAY_CONFIG)
  if err then
    ctx.error('Unable to read config: ' .. err)
  end
  local result = rl6.close(math.tointeger(channel))
  if result and result ~= 0 then
    ctx.error(
      'Unable to close relay channel ' .. tostring(channel) .. ': ' .. rl6.err_to_str(result)
    )
  end
end

function power_off_command(ctx)
  local channel, err = config.read(POWER_RELAY_CONFIG)
  if err then
    ctx.error('Unable to read config: ' .. err)
  end
  local result = rl6.open(math.tointeger(channel))
  if result and result ~= 0 then
    ctx.error(
      'Unable to open relay channel ' .. tostring(channel) .. ': ' .. rl6.err_to_str(result)
    )
  end
end

function start_command(ctx)
  if not is_powered() then
    ctx.error("Fuel cell is not powered, use 'Power On' command to power it first.")
  end
  local channel, err = config.read(START_RELAY_CONFIG)
  if err then
    ctx.error('Unable to read config: ' .. err)
  end
  local result = rl6.close(math.tointeger(channel))
  if result and result ~= 0 then
    ctx.error(
      'Unable to close relay channel ' .. tostring(channel) .. ': ' .. rl6.err_to_str(result)
    )
  end
end

function stop_command(ctx)
  if not is_powered() then
    ctx.error("Fuel cell is not powered, use 'Power On' command to power it first.")
  end
  local channel, err = config.read(START_RELAY_CONFIG)
  if err then
    ctx.error('Unable to read config: ' .. err)
  end
  local result = rl6.open(math.tointeger(channel))
  if result and result ~= 0 then
    ctx.error(
      'Unable to open relay channel ' .. tostring(channel) .. ': ' .. rl6.err_to_str(result)
    )
  end
end

main()
