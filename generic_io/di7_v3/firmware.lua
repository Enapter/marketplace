local channels

function main()
  local err = create_channels()
  if err ~= nil then
    enapter.log('Create DI channels: ' .. err .. '.', 'error', true)
  end

  enapter.register_command_handler('get_state', command_get_state)
  enapter.register_command_handler('read_counter', command_read_counter)
  enapter.register_command_handler('reset_counter', command_reset_counter)

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function create_channels()
  local _channels = {}
  for i = 1, 7 do
    local channel, err = digitalin.new('port://di-' .. tostring(i))
    if err ~= nil then
      return 'Create DI channel ' .. tostring(i) .. ' failed: ' .. err .. '.'
    end
    _channels['di_' .. tostring(i)] = channel
  end
  channels = _channels
end

local states = {
  [digitalin.LOW] = 'LOW',
  [digitalin.HIGH] = 'HIGH',
}

function command_get_state(ctx, args)
  return do_channel_cmd(ctx, args.port, function(channel)
    local state, err = channel:get_state()
    if err ~= nil then
      ctx.error('Get channel state failed: ' .. err .. '.')
    end
    return { state = states[state] }
  end)
end

function command_read_counter(ctx, args)
  return do_channel_cmd(ctx, args.port, function(channel)
    local counter, err = channel:read_counter()
    if err ~= nil then
      ctx.error('Read channel counter failed: ' .. err .. '.')
    end
    return { counter = counter }
  end)
end

function command_reset_counter(ctx, args)
  do_channel_cmd(ctx, args.port, function(channel)
    local err = channel:reset_counter()
    if err ~= nil then
      ctx.error('Reset channel counter failed: ' .. err .. '.')
    end
  end)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-DI7' })
end

function send_telemetry()
  local telemetry = {
    status = 'ok',
    alerts = {},
  }

  if not channels then
    telemetry.status = 'error'
    telemetry.alerts = { 'cannot_read_channel_state' }
  else
    for port, channel in pairs(channels) do
      local state, err = channel:get_state()
      if err ~= nil then
        enapter.log('Get channel ' .. port .. ' state failed: ' .. err .. '.', 'error', true)
        telemetry.status = 'error'
        telemetry.alerts = { 'cannot_read_channel_state' }
      end
      local counter, err = channel:read_counter()
      if err ~= nil then
        enapter.log('Get channel ' .. port .. ' counter failed: ' .. err .. '.', 'error', true)
        telemetry.status = 'error'
        telemetry.alerts = { 'cannot_read_channel_state' }
      end
      local closed = state == digitalin.HIGH
      telemetry[port .. '_closed'] = closed
      telemetry[port .. '_counter'] = counter
    end
  end

  enapter.send_telemetry(telemetry)
end

local port_arg_required_errmsg = 'Port arg is required and must be a string.'
local channels_are_not_created_errmsg = 'Channels are not created. See device logs.'

function do_channel_cmd(ctx, port, channel_closure)
  if not port or type(port) ~= 'string' then
    ctx.error(port_arg_required_errmsg)
  end
  if channels == nil then
    ctx.error(channels_are_not_created_errmsg)
  end
  local channel = channels[string.gsub(port, '-', '_')]
  if channel == nil then
    ctx.error('Channel with port ' .. port .. ' does not exist.')
  end
  return channel_closure(channel)
end

main()
