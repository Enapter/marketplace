local config = require('enapter.ucm.config')
local can_packets = require('can_packets')

local can_configured = false
local can_not_configured_err = 'can is not properly configured'

local cache_ttl = 60

BAUD_RATE = 'baud_rate'
CACHE_BUCKET_SIZE = 'cache_bucket_size'
CACHE_TTL = 'cache_ttl_seconds'

function main()
  config.init({
    [BAUD_RATE] = { type = 'number', required = true },
    [CACHE_BUCKET_SIZE] = { type = 'number', default = can_packets.bucket_size },
    [CACHE_TTL] = { type = 'number', default = cache_ttl },
  }, {
    after_write = setup_can,
  })

  local args, err = config.read_all()
  if err == nil then
    err = setup_can(args)
  end

  if err ~= nil then
    enapter.log(err, 'error', true)
  end

  enapter.register_command_handler('read', cmd_read)
  enapter.register_command_handler('write', cmd_write)

  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, cleanup_unused_can_packets)
end

function setup_can(args)
  local baud_rate = math.tointeger(args[BAUD_RATE])
  if baud_rate == nil then
    can_configured = false
    return 'CAN is not configured'
  end

  local result = can.init(baud_rate, can_handler)
  if result ~= 0 then
    can_configured = false
    return 'CAN init failed: ' .. result .. ' ' .. can.err_to_str(result)
  end

  can_packets.update_cache_bucket_size(math.tointeger(args[CACHE_BUCKET_SIZE]))
  cache_ttl = math.tointeger(args[CACHE_TTL])

  can_configured = true
end

function send_telemetry()
  local status = 'ok'
  local alerts = {}
  if not can_configured then
    table.insert(alerts, 'not_configured')
    status = 'error'
  end

  local telemetry =
    { alerts = alerts, status = status, subscribed_ids = can_packets.subscripions_count() }

  enapter.send_telemetry(telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-CAN' })
end

function can_handler(msg_id, data)
  local ok, err = pcall(function()
    can_packets.push(msg_id, data)
  end)
  if not ok then
    enapter.log('can packet push failed: ' .. err, 'error')
  end
end

function cmd_read(ctx, args)
  if not can_configured then
    ctx.error(can_not_configured_err)
  end

  if not args.msg_ids or type(args.msg_ids) ~= 'table' then
    ctx.error('msg_ids arg is required and must be a table')
  end

  local results, cursor = can_packets.get_since(args.cursor, args.msg_ids)
  return { cursor = cursor, results = results }
end

function cmd_write(ctx, args)
  if not can_configured then
    ctx.error(can_not_configured_err)
  end

  if not args.packets or type(args.packets) ~= 'table' then
    ctx.error('packets arg is required and must be a table')
  end

  local results = {}
  for i, p in ipairs(args.packets) do
    local result = can.send(p.msg_id, p.data)
    if result == 0 then
      results[i] = {}
    else
      results[i] = { errcode = result, errmsg = can.err_to_str(result) }
    end
  end

  return results
end

function cleanup_unused_can_packets()
  local ok, err = pcall(function()
    can_packets.cleanup_unused_till(os.time() - cache_ttl)
  end)
  if not ok then
    enapter.log('cleanup unused can packets failed: ' .. err, 'error')
  end
end

main()
