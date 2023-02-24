local CHANNELS_NUMBER = 6

local channel_arg_required_errmsg = 'channel arg is required and must be a number'

function main()
  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)

  enapter.register_command_handler('close_channel', command_close_channel)
  enapter.register_command_handler('close_all_channels', command_close_all_channels)
  enapter.register_command_handler('open_channel', command_open_channel)
  enapter.register_command_handler('open_all_channels', command_open_all_channels)
  enapter.register_command_handler('is_channel_closed', command_is_channel_closed)
  enapter.register_command_handler('all_channels_state', command_all_channels_state)
end

function send_telemetry()
  local telemetry = {
    status = 'ok',
    alerts = {},
  }

  for i = 1, CHANNELS_NUMBER, 1 do
    local val, res = rl6.get(i)
    if res and res ~= 0 then
      enapter.log(rl6.err_to_str(res))
      telemetry.status = 'error'
      telemetry.alerts = { 'cannot_read_channel_state' }
    end
    telemetry['channel_' .. tostring(i) .. '_closed'] = val
  end

  enapter.send_telemetry(telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-RL6' })
end

function command_close_channel(ctx, args)
  if not args.channel or type(args.channel) ~= 'number' then
    ctx.error(channel_arg_required_errmsg)
  end
  rl6.close(math.floor(args.channel))
end

function command_close_all_channels(_ctx, _args)
  rl6.close_all()
end

function command_open_channel(ctx, args)
  if not args.channel or type(args.channel) ~= 'number' then
    ctx.error(channel_arg_required_errmsg)
  end
  rl6.open(math.floor(args.channel))
end

function command_open_all_channels(_ctx, _args)
  rl6.open_all()
end

function command_is_channel_closed(ctx, args)
  if not args.channel or type(args.channel) ~= 'number' then
    ctx.error(channel_arg_required_errmsg)
  end
  return { closed = rl6.get(math.floor(args.channel)) }
end

function command_all_channels_state(ctx, _args)
  local state = {}
  for i = 1, CHANNELS_NUMBER, 1 do
    local closed, res = rl6.get(i)
    if res and res ~= 0 then
      ctx.error(rl6.err_to_str(res))
    end
    state[i] = closed
  end
  return { closed = state }
end

main()
