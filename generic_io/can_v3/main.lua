local can_port = 'can'
local can_client = nil
local can_monitors = {}
local can_queues = {}

function main()
  local client, err = can.new('port://' .. can_port)
  if err ~= nil then
    enapter.log('create CAN client: ' .. err, 'error', true)
  else
    can_client = client
  end

  enapter.register_command_handler('send', command_send)
  enapter.register_command_handler('monitor', command_monitor)
  enapter.register_command_handler('monitor_pop', command_monitor_pop)
  enapter.register_command_handler('queue', command_queue)
  enapter.register_command_handler('queue_pop', command_queue_pop)
  enapter.register_command_handler('queue_drops_count', command_queue_drops_count)

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function command_send(ctx, args)
  if args.port ~= can_port then
    ctx.error('unknown port')
  end

  local data = hex_decode(args.data)
  local err = can_client:send(args.msg_id, data)
  if err ~= nil then
    ctx.error('failed to send: ' .. err)
  end
end

function command_monitor(ctx, args)
  if not can_client then
    ctx.error('client is not initialized')
  end
  if args.port ~= can_port then
    ctx.error('unknown port')
  end

  local monitor, err = can_client:monitor(args.msg_ids)
  if err ~= nil then
    ctx.error('create monitor: ' .. err)
  end

  local id = generate_id()
  can_monitors[id] = monitor

  return { monitor_id = id }
end

function command_monitor_pop(ctx, args)
  if not can_client then
    ctx.error('client is not initialized')
  end
  if args.port ~= can_port then
    ctx.error('unknown port')
  end

  local monitor = can_monitors[args.monitor_id]
  if monitor == nil then
    return { errcode = 'monitor_not_found' }
  end

  local values, err = monitor:pop(args.msg_ids)
  if err ~= nil then
    ctx.error('monitor pop failed: ' .. err)
  end

  for k, v in pairs(values) do
    values[k] = hex_encode(v)
  end

  return { values = values }
end

local drop_policies = {
  ['DROP_OLDEST'] = can.DROP_OLDEST,
  ['DROP_NEWEST'] = can.DROP_NEWEST,
}

function command_queue(ctx, args)
  if not can_client then
    ctx.error('client is not initialized')
  end
  if args.port ~= can_port then
    ctx.error('unknown port')
  end

  local drop_policy = drop_policies[args.drop_policy]
  local queue, err = can_client:queue(args.msg_ids, args.size, drop_policy)
  if err ~= nil then
    ctx.error('create monitor: ' .. err)
  end

  local id = generate_id()
  can_queues[id] = queue

  return { queue_id = id }
end

function command_queue_pop(ctx, args)
  if not can_client then
    ctx.error('client is not initialized')
  end
  if args.port ~= can_port then
    ctx.error('unknown port')
  end

  local queue = can_queues[args.queue_id]
  if queue == nil then
    return { errcode = 'queue_not_found' }
  end

  local values, err = queue:pop(args.msg_id)
  if err ~= nil then
    ctx.error('queue pop: ' .. err)
  end

  for k, v in pairs(values) do
    values[k] = hex_encode(v)
  end

  return { values = values }
end

function command_queue_drops_count(ctx, args)
  if not can_client then
    ctx.error('client is not initialized')
  end
  if args.port ~= can_port then
    ctx.error('unknown port')
  end

  local queue = can_queues[args.queue_id]
  if queue == nil then
    return { errcode = 'queue_not_found' }
  end

  local count, err = queue:drops_count(args.msg_id)
  if err ~= nil then
    ctx.error('queue drops count: ' .. err)
  end

  return { drops_count = count }
end

function send_properties()
  enapter.send_properties({
    vendor = 'Enapter',
    model = 'Generic-CAN',
  })
end

function send_telemetry()
  local status = 'ok'
  local alerts = {}
  if not can_client then
    status = 'error'
    table.insert(alerts, 'can_client_not_initialized')
  end

  enapter.send_telemetry({
    status = status,
    alerts = alerts,
  })
end

function generate_id()
  -- os.time() fails if NTP hasn't been initialized yet
  local ok, ts = pcall(os.time)
  if not ok then
    ts = 0
  end
  local rand = math.random(0, 999999)
  return string.format('%d-%06d', ts, rand)
end

function hex_encode(str)
  return (str:gsub('.', function(c)
    return string.format('%02X', string.byte(c))
  end))
end

function hex_decode(hex)
  return (hex:gsub('..', function(cc)
    return string.char(tonumber(cc, 16))
  end))
end

main()
