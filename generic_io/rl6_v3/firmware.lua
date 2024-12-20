local config = require('enapter.ucm.config')

local channels = {}

local CHANNELS_NUMBER = 6

local port_arg_required_errmsg = 'Port arg is required and must be a string.'

function main()
  local err = create_channels()
  if err ~= nil then
    enapter.log('Create relay channels: ' .. err .. '.', 'error', true)
  end

  config.init({
    ['do_1_def'] = { type = 'boolean', required = false, default = false },
    ['do_2_def'] = { type = 'boolean', required = false, default = false },
    ['do_3_def'] = { type = 'boolean', required = false, default = false },
    ['do_4_def'] = { type = 'boolean', required = false, default = false },
    ['do_5_def'] = { type = 'boolean', required = false, default = false },
    ['do_6_def'] = { type = 'boolean', required = false, default = false },
    ['on_disconnect'] = { type = 'string', required = false, default = 'Respect' },
  }, {
  })

  local values, err = config.read_all()
  if err == nil then
    err = setup(values)
  end

  if err ~= nil then
    enapter.log(err, 'error', true)
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

function setup(values)
  local state = {}
  for i = 1, CHANNELS_NUMBER, 1 do
    if values['do_' .. i .. '_def'] ~= nil then
      state['do-' .. tostring(i)] = values['do_' .. i .. '_def']
      enapter.log('Channel ' .. i .. ' set to ' .. tostring(state[i]))
    else
      enapter.log('Channel ' .. i .. ' set to ' .. tostring(false))
      state['do-' .. tostring(i)] = false
    end
  end
  for port, s in pairs(state) do
    local channel = channels[port]
    if channel == nil then
      enapter.log('Channel with port ' .. port .. ' does not exist.', 'error', true)
    else
      if s == true then
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
end

function create_channels()
  for i = 1, CHANNELS_NUMBER, 1 do
    local channel, err = relay.new('port://do-' .. tostring(i))
    if err ~= nil then
      return 'Create relay channel ' .. tostring(i) .. ' failed: ' .. err .. '.'
    end
    channels['do_' .. tostring(i)] = channel
  end
end

function connection_status_handler(status)
  if not status then
    local values, err = config.read_all()
    if err then
      enapter.log(
        'Cannot read config: ' .. tostring(err) .. ' error, respecting current ports state.',
        'error',
        true
      )
    else
      if values['on_disconnect'] == 'Set Default' then
        setup(values)
      end
    end
  end
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-RL6' })
end

function send_telemetry()
  local telemetry = { status = 'ok', alerts = {} }
  local err = check_channels_count()
  if err ~= nil then
    enapter.log(err, 'error', true)
    telemetry.status = 'error'
    telemetry.alerts = { 'cannot_read_channel_state' }
  else
    for k, channel in pairs(channels) do
      local closed, err = channel:is_closed()
      if err ~= nil then
        enapter.log('Get channel ' .. k .. ' state failed: ' .. err .. '.', 'error', true)
        telemetry.status = 'error'
        telemetry.alerts = { 'cannot_read_channel_state' }
      end
      telemetry[k .. '_closed'] = closed
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
  local err = check_channels_count()
  if err ~= nil then
    ctx.error(err)
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
  local err = check_channels_count()
  if err ~= nil then
    ctx.error(err)
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
  local err = check_channels_count()
  if err ~= nil then
    ctx.error(err)
  end
  local state = {}
  for k, channel in pairs(channels) do
    local closed, err = channel:is_closed()
    if err ~= nil then
      ctx.error('Get channel ' .. k .. ' state failed: ' .. err .. '.')
    end
    state[i] = closed
  end
  return { closed = state }
end

function do_channel_cmd(ctx, port, channel_closure)
  local channel = channels[string.gsub(port, '-', '_')]
  if channel == nil then
    ctx.err('Channel with port ' .. port .. ' does not exist.')
  end
  return channel_closure(channel)
end

function check_channels_count()
  local count
  for _ in pairs(channels) do
    count=count+1
  end

  if count ~= CHANNELS_NUMBER then
    return 'Not all channels created, expected ' .. tostring(CHANNELS_NUMBER)
      .. ' actual ' .. tostring(ch_count) .. '.'
  end
end

main()
