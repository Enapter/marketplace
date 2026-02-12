local config = require('enapter.ucm.config')

local channels

local channels_are_not_created_errmsg = 'Channels are not created. See device logs.'
local port_arg_required_errmsg = 'Port arg is required and must be a string.'

function main()
  local err = create_channels()
  if err ~= nil then
    enapter.log('Create relay channels: ' .. err .. '.', 'error', true)
  else
    config.init({
      ['do_1_def'] = { type = 'boolean', required = false, default = false },
      ['do_2_def'] = { type = 'boolean', required = false, default = false },
      ['do_3_def'] = { type = 'boolean', required = false, default = false },
      ['do_4_def'] = { type = 'boolean', required = false, default = false },
      ['do_5_def'] = { type = 'boolean', required = false, default = false },
      ['do_6_def'] = { type = 'boolean', required = false, default = false },
      ['on_disconnect'] = { type = 'string', required = false, default = 'Respect' },
    })

    local values, err = config.read_all()
    if err == nil then
      err = set_channel_default_states(values)
    end

    if err ~= nil then
      enapter.log(err, 'error', true)
    end
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('close_channel', command_close_channel)
  enapter.register_command_handler('close_all_channels', command_close_all_channels)
  enapter.register_command_handler('open_channel', command_open_channel)
  enapter.register_command_handler('open_all_channels', command_open_all_channels)
  enapter.register_command_handler('impulse_on_channel', command_impulse_on_channel)
  enapter.register_command_handler('is_channel_closed', command_is_channel_closed)
  enapter.register_command_handler('all_channels_state', command_all_channels_state)

  enapter.on_connection_status_changed(connection_status_handler)
end

function set_channel_default_states(values)
  for port, channel in pairs(channels) do
    local closed = values[port .. '_def']
    if closed == nil then
      closed = false
    end

    if closed then
      local err = channel:close()
      if err ~= nil then
        enapter.log('Close channel' .. port .. ' ' .. err, 'error', true)
      else
        enapter.log('Channel ' .. port .. ' closed successfully.')
      end
    else
      local err = channel:open()
      if err ~= nil then
        enapter.log('Open channel ' .. port .. ' ' .. err .. '.', 'error', true)
      else
        enapter.log('Channel ' .. port .. ' opened successfully.')
      end
    end
  end
end

function create_channels()
  local _channels = {}
  for i = 1, 6 do
    local channel, err = relay.new('port://do-' .. tostring(i))
    if err ~= nil then
      return 'Create relay channel ' .. tostring(i) .. ' failed: ' .. err .. '.'
    end
    _channels['do_' .. tostring(i)] = channel
  end
  channels = _channels
end

function connection_status_handler(connected)
  if not connected then
    local values, err = config.read_all()
    if err then
      enapter.log('Cannot read config: ' .. tostring(err) .. ' error, respecting current ports state.', 'error', true)
    else
      if values['on_disconnect'] == 'Set Default' then
        set_channel_default_states(values)
      end
    end
  end
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-RL6' })
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
      local closed, err = channel:is_closed()
      if err ~= nil then
        enapter.log('Get channel ' .. port .. ' state failed: ' .. err .. '.', 'error', true)
        telemetry.status = 'error'
        telemetry.alerts = { 'cannot_read_channel_state' }
      end
      telemetry[port .. '_closed'] = closed
    end
  end
  enapter.send_telemetry(telemetry)
end

function command_close_channel(ctx, args)
  if not args.port or type(args.port) ~= 'string' then
    ctx.error(port_arg_required_errmsg)
  end
  do_channel_cmd(ctx, args.port, function(channel)
    local err = channel:close()
    if err ~= nil then
      ctx.error('Open channel failed: ' .. err .. '.')
    end
  end)
end

function command_close_all_channels(ctx, _args)
  if not channels then
    ctx.error(channels_are_not_created_errmsg)
  end
  for k, channel in pairs(channels) do
    local err = channel:close()
    if err ~= nil then
      ctx.error('Close channel ' .. k .. ' failed: ' .. err .. '.')
    end
  end
end

function command_open_channel(ctx, args)
  if not args.port or type(args.port) ~= 'string' then
    ctx.error(port_arg_required_errmsg)
  end
  do_channel_cmd(ctx, args.port, function(channel)
    local err = channel:open()
    if err ~= nil then
      ctx.error('Open failed: ' .. err .. '.')
    end
  end)
end

function command_open_all_channels(ctx, _args)
  if not channels then
    ctx.error(channels_are_not_created_errmsg)
  end
  for k, channel in pairs(channels) do
    local err = channel:open()
    if err ~= nil then
      ctx.error('Open channel ' .. k .. ' failed: ' .. err .. '.')
    end
  end
end

function command_impulse_on_channel(ctx, args)
  if not args.port or type(args.port) ~= 'string' then
    ctx.error(port_arg_required_errmsg)
  end
  if not args.duration or type(args.duration) ~= 'number' then
    ctx.error(port_arg_required_errmsg)
  end
  do_channel_cmd(ctx, args.port, function(channel)
    local err = channel:impulse(math.floor(args.duration))
    if err ~= nil then
      ctx.error('Impulse failed: ' .. err .. '.')
    end
  end)
end

function command_is_channel_closed(ctx, args)
  if not args.port or type(args.port) ~= 'string' then
    ctx.error(port_arg_required_errmsg)
  end
  return do_channel_cmd(ctx, args.port, function(channel)
    local closed, err = channel:is_closed()
    if err ~= nil then
      ctx.error('Get state failed: ' .. err .. '.')
    end
    return { closed = closed }
  end)
end

function command_all_channels_state(ctx, _args)
  if not channels then
    ctx.error(channels_are_not_created_errmsg)
  end
  local state = {}
  for port, channel in pairs(channels) do
    local closed, err = channel:is_closed()
    if err ~= nil then
      ctx.error('Get channel ' .. port .. ' state failed: ' .. err .. '.')
    end
    state[port] = closed
  end
  return { closed = state }
end

function do_channel_cmd(ctx, port, channel_closure)
  local channel = channels[string.gsub(port, '-', '_')]
  if channel == nil then
    ctx.error('Channel with port ' .. port .. ' does not exist.')
  end
  return channel_closure(channel)
end

main()
