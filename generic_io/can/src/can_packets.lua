local ts_rb = require('ts_rb')

local can_packets = {
  bucket_size = 20,
  packets = {},
}

function can_packets.subscripions_count()
  local count = 0
  for _, _ in pairs(can_packets.packets) do
    count = count + 1
  end
  return count
end

function can_packets.update_cache_bucket_size(bucket_size)
  if can_packets.bucket_size == bucket_size then
    return
  end

  can_packets.bucket_size = bucket_size
  for _, v in pairs(can_packets.packets) do
    v.rb = ts_rb.new(can_packets.bucket_size)
  end
end

function can_packets.push(msg_id, data)
  local msg_id_key = tostring(math.tointeger(msg_id))
  local subscribed = (can_packets.packets[msg_id_key] ~= nil)
  if subscribed then
    can_packets.packets[msg_id_key].rb:push_data(os.time(), data)
  end
  return subscribed
end

function can_packets.get_since(ts, msg_ids)
  local results = {}
  local curtime = os.time()

  if ts == nil then
    ts = 0
  end

  for i, msg_id in ipairs(msg_ids) do
    local msg_id_key = tostring(math.tointeger(msg_id))
    local packets = can_packets.packets[msg_id_key]
    if packets then
      packets.last_use_ts = curtime
      results[i] = packets.rb:get_all_since(ts)
    else
      results[i] = {}
      can_packets.packets[msg_id_key] =
        { last_use_ts = curtime, rb = ts_rb.new(can_packets.bucket_size) }
    end
  end

  return results, curtime
end

function can_packets.cleanup_unused_till(ts)
  for msg_id_key, v in pairs(can_packets.packets) do
    if v.last_use_ts <= ts then
      can_packets.packets[msg_id_key] = nil
    end
  end
end

return can_packets
