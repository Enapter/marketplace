local can_packets

local current_time = os.time()
_G.os = {
  time = function()
    return current_time
  end,
}

describe('can packets', function()
  before_each(function()
    current_time = current_time + 1
    can_packets = require('can_packets')
  end)

  it('should push after first read', function()
    local ts = current_time
    local msg_id = 456
    local data = 'test data'

    assert.is.False(can_packets.push(msg_id, data))
    assert.is.same({ {} }, can_packets.get_since(ts, { msg_id }))

    assert.is.True(can_packets.push(msg_id, data))
    assert.is.same({ { data } }, can_packets.get_since(ts, { msg_id }))
  end)

  it('should cleanup unused data', function()
    local ts = current_time
    local msg_id = 6
    local data = 'test data'

    assert.is.same({ {} }, can_packets.get_since(ts, { msg_id }))
    can_packets.push(msg_id, data)

    can_packets.cleanup_unused_till(ts)
    assert.is.same({ {} }, can_packets.get_since(ts, { msg_id }))
  end)

  it('should update cache bucket size to new count with data drop', function()
    local ts = current_time
    local msg_id = 123
    local data = 'test data'

    assert.is.same({ {} }, can_packets.get_since(ts, { msg_id }))

    can_packets.push(msg_id, data)
    can_packets.update_cache_bucket_size(20)
    assert.is.same({ { data } }, can_packets.get_since(ts, { msg_id }))

    can_packets.update_cache_bucket_size(5)
    assert.is.same({ {} }, can_packets.get_since(ts, { msg_id }))
  end)

  it('should return curtime as cursor', function()
    local _, cursor = can_packets.get_since(0, { 123 })
    assert.is.equal(current_time, cursor)
  end)

  it('should read all with nil cursor', function()
    local msg_id = 123
    local data = 'test data'

    assert.is.same({ {} }, can_packets.get_since(nil, { msg_id }))

    can_packets.push(msg_id, data)
    assert.is.same({ { data } }, can_packets.get_since(nil, { msg_id }))
  end)
end)
