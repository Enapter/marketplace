local CHANNELS_NUMBER = 6

local channel_arg_required_errmsg = 'channel arg is required and must be a number'

function set_default_state()
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err) .. '. Opening all channels.', 'error')
    rl6.open_all()
  else
    local state = {}
    for i = 1, CHANNELS_NUMBER, 1 do
      if values['ch' .. i .. '_def'] ~= nil then
        state[i] = values['ch' .. i .. '_def']
        enapter.log('Channel ' .. i .. ' set to ' .. tostring(state[i]))
      else
        enapter.log('Channel ' .. i .. ' set to ' .. tostring(false))
        state[i] = false
      end
    end
    local result = rl6.set_all(state[1], state[2], state[3], state[4], state[5], state[6])
    if result ~= 0 then
      enapter.log(
        'Changing relay statuses failed: ' .. result .. ' ' .. rl6.err_to_str(result),
        'error',
        true
      )
    else
      enapter.log('Changing default relay status successfully')
    end
  end
end

function connection_status_handler(status)
  if not status then
    local values, err = config.read_all()
    if err then
      enapter.log(
        'cannot read config: ' .. tostring(err),
        'error. Respecting current channels state'
      )
    else
      if values['on_disconnect'] == 'Set Default' then
        set_default_state()
      end
    end
  end
end

function main()
  -- Init config & register config management commands
  config.init({
    ['ch1_def'] = { type = 'boolean', required = false, default = false },
    ['ch2_def'] = { type = 'boolean', required = false, default = false },
    ['ch3_def'] = { type = 'boolean', required = false, default = false },
    ['ch4_def'] = { type = 'boolean', required = false, default = false },
    ['ch5_def'] = { type = 'boolean', required = false, default = false },
    ['ch6_def'] = { type = 'boolean', required = false, default = false },
    ['on_disconnect'] = { type = 'string', required = false, default = 'Respect' },
  })

  set_default_state()

  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)

  enapter.register_command_handler('close_channel', command_close_channel)
  enapter.register_command_handler('close_all_channels', command_close_all_channels)
  enapter.register_command_handler('open_channel', command_open_channel)
  enapter.register_command_handler('open_all_channels', command_open_all_channels)
  enapter.register_command_handler('impulse_on_channel', command_impulse_on_channel)
  enapter.register_command_handler('is_channel_closed', command_is_channel_closed)
  enapter.register_command_handler('all_channels_state', command_all_channels_state)

  enapter.on_connection_status_changed(connection_status_handler)
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

function command_impulse_on_channel(ctx, args)
  if not args.channel or type(args.channel) ~= 'number' then
    ctx.error(channel_arg_required_errmsg)
  end
  if not args.duration or type(args.duration) ~= 'number' then
    ctx.error(channel_arg_required_errmsg)
  end
  rl6.impulse(math.floor(args.channel), math.floor(args.duration))
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

---------------------------------
-- Stored Configuration API
---------------------------------

config = {}

-- Initializes config options. Registers required UCM commands.
-- @param options: key-value pairs with option name and option params
-- @example
--   config.init({
--     address = { type = 'string', required = true },
--     unit_id = { type = 'number', default = 1 },
--     reconnect = { type = 'boolean', required = true }
--   })
function config.init(options)
  assert(next(options) ~= nil, 'at least one config option should be provided')
  assert(not config.initialized, 'config can be initialized only once')
  for name, params in pairs(options) do
    local type_ok = params.type == 'string' or params.type == 'number' or params.type == 'boolean'
    assert(type_ok, 'type of `' .. name .. '` option should be either string or number or boolean')
  end

  enapter.register_command_handler(
    'write_configuration',
    config.build_write_configuration_command(options)
  )
  enapter.register_command_handler(
    'read_configuration',
    config.build_read_configuration_command(options)
  )

  config.options = options
  config.initialized = true
end

-- Reads all initialized config options
-- @return table: key-value pairs
-- @return nil|error
function config.read_all()
  local result = {}

  for name, _ in pairs(config.options) do
    local value, err = config.read(name)
    if err then
      return nil, 'cannot read `' .. name .. '`: ' .. err
    else
      result[name] = value
    end
  end

  return result, nil
end

-- @param name string: option name to read
-- @return string
-- @return nil|error
function config.read(name)
  local params = config.options[name]
  assert(params, 'undeclared config option: `' .. name .. '`, declare with config.init')

  local ok, value, ret = pcall(function()
    return storage.read(name)
  end)

  if not ok then
    return nil, 'error reading from storage: ' .. tostring(value)
  elseif ret and ret ~= 0 then
    return nil, 'error reading from storage: ' .. storage.err_to_str(ret)
  elseif value then
    return config.deserialize(name, value), nil
  else
    return params.default, nil
  end
end

-- @param name string: option name to write
-- @param val string: value to write
-- @return nil|error
function config.write(name, val)
  local ok, ret = pcall(function()
    return storage.write(name, config.serialize(name, val))
  end)

  if not ok then
    return 'error writing to storage: ' .. tostring(ret)
  elseif ret and ret ~= 0 then
    return 'error writing to storage: ' .. storage.err_to_str(ret)
  end
end

-- Serializes value into string for storage
function config.serialize(_, value)
  if value then
    return tostring(value)
  else
    return ''
  end
end

-- Deserializes value from stored string
function config.deserialize(name, value)
  local params = config.options[name]
  assert(params, 'undeclared config option: `' .. name .. '`, declare with config.init')

  if params.type == 'number' then
    return tonumber(value)
  elseif params.type == 'string' then
    return value
  elseif params.type == 'boolean' then
    if value == 'true' then
      return true
    elseif value == 'false' then
      return false
    else
      return nil
    end
  end
end

function config.build_write_configuration_command(options)
  return function(ctx, args)
    for name, params in pairs(options) do
      if params.required then
        assert(args[name], '`' .. name .. '` argument required')
      end

      local err = config.write(name, args[name])
      if err then
        ctx.error('cannot write `' .. name .. '`: ' .. err)
      end
    end
  end
end

function config.build_read_configuration_command(_config_options)
  return function(ctx)
    local result, err = config.read_all()
    if err then
      ctx.error(err)
    else
      return result
    end
  end
end

main()
