local can_packets = require('can_packets')

local BAUD_RATE_CONFIG = 'baud_rate'
local CACHE_BUCKET_SIZE_CONFIG = 'cache_size'
local CACHE_TTL_CONFIG = 'cache_ttl'

local can_not_configured_err = 'can is not properly configured'

local function convert_data(d)
  local v = { string.unpack('c2c2c2c2c2c2c2c2', d) }
  local vv = {}
  for j = 1, 8 do
    vv[j] = tonumber(v[j], 16)
  end

  return string.pack('BBBBBBBB', table.unpack(vv))
end

return {
  new = function()
    local app = {
      configured = false,
      received_can_packets = 0,
      accepted_can_packets = 0,
      total_reads = 0,
      total_writes = 0,
      cache_ttl = 60,
    }

    app.config = {
      [BAUD_RATE_CONFIG] = { type = 'number', required = true },
      [CACHE_BUCKET_SIZE_CONFIG] = { type = 'number', default = can_packets.bucket_size },
      [CACHE_TTL_CONFIG] = { type = 'number', default = app.cache_ttl },
    }

    function app.setup(args)
      local baud_rate = math.tointeger(args[BAUD_RATE_CONFIG])
      if baud_rate == nil then
        app.configured = false
        return 'baud rate is required and must be an integer'
      end

      local result = can.init(baud_rate, app.can_handler)
      if result ~= 0 then
        app.configured = false
        return 'CAN init failed: ' .. result .. ' ' .. can.err_to_str(result)
      end

      can_packets.update_cache_bucket_size(math.tointeger(args[CACHE_BUCKET_SIZE_CONFIG]))
      app.cache_ttl = math.tointeger(args[CACHE_TTL_CONFIG])

      app.configured = true
    end

    function app.can_handler(msg_id, data)
      app.received_can_packets = app.received_can_packets + 1
      local ok, err = pcall(function()
        if
          can_packets.push(
            msg_id,
            string.format('%02x%02x%02x%02x%02x%02x%02x%02x', string.unpack('BBBBBBBB', data))
          )
        then
          app.accepted_can_packets = app.accepted_can_packets + 1
        end
      end)
      if not ok then
        enapter.log('can packet push failed: ' .. err, 'error')
      end
    end

    function app.send_telemetry()
      local status = 'ok'
      local alerts = {}
      if not app.configured then
        table.insert(alerts, 'not_configured')
        status = 'error'
      end

      local telemetry = {
        alerts = alerts,
        status = status,
        subscribed_ids = can_packets.subscripions_count(),
        received_can_packets = app.received_can_packets,
        accepted_can_packets = app.accepted_can_packets,
        total_reads = app.total_reads,
        total_writes = app.total_writes,
      }

      enapter.send_telemetry(telemetry)
    end

    function app.send_properties()
      enapter.send_properties({ vendor = 'Enapter', model = 'Generic-CAN' })
    end

    function app.cmd_read(ctx, args)
      app.total_reads = app.total_reads + 1

      if not app.configured then
        ctx.error(can_not_configured_err)
      end

      if not args.msg_ids or type(args.msg_ids) ~= 'string' then
        ctx.error('msg_ids arg is required and must be a string')
      end

      local parsed_msg_ids = {}
      for m in args.msg_ids:gmatch('([^,%s]+)') do
        local i = math.tointeger(m)
        if i == nil then
          ctx.error('msg_id must be an integer')
        end
        table.insert(parsed_msg_ids, i)
      end

      local args_cursor = math.tointeger(args.cursor)
      if args.cursor ~= nil and args_cursor == nil then
        ctx.error('cursor must be a value from the previous read')
      end

      local results, cursor = can_packets.get_since(args_cursor, parsed_msg_ids)
      return { cursor = tostring(cursor), results = results }
    end

    function app.cmd_write(ctx, args)
      app.total_writes = app.total_writes + 1

      if not app.configured then
        ctx.error(can_not_configured_err)
      end

      local msg_id = math.tointeger(args.msg_id)
      if not msg_id then
        ctx.error('msg_id arg is required and must be an integer')
      end

      if not args.data or type(args.data) ~= 'string' then
        ctx.error('data arg is required and must be a string')
      end

      if #args.data ~= 16 then
        ctx.error('data arg must be a 16-char string')
      end

      local result = can.send(msg_id, convert_data(args.data))
      if result ~= 0 then
        return { errcode = result, errmsg = can.err_to_str(result) }
      end
    end

    function app.cleanup_unused_can_packets()
      local ok, err = pcall(function()
        can_packets.cleanup_unused_till(os.time() - app.cache_ttl)
      end)
      if not ok then
        enapter.log('cleanup unused can packets failed: ' .. err, 'error')
      end
    end

    return app
  end,
}
