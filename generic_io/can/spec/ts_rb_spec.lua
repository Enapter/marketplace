local ts_rb = require('ts_rb')

describe('ring buffer', function()
  it('should push and get data', function()
    local count = 5
    local all_data = {}
    local rb = ts_rb.new(count)
    for i = 1, count do
      all_data[i] = 'test ' .. tostring(i)
      rb:push_data(i, all_data[i])
    end

    assert.is.same(all_data, rb:get_all_since(0))
    for i = 1, count do
      assert.is.same(table_splice(all_data, i, 5), rb:get_all_since(i))
    end
    assert.is.same({}, rb:get_all_since(6))
  end)

  it('should clean up duplicates', function()
    local count = 5
    local all_data = {}
    local rb = ts_rb.new(count)
    for i = 1, count do
      all_data[i] = 'test ' .. tostring(i)
      rb:push_data(i, all_data[i])
    end

    rb:push_data(2, all_data[3])
    rb:push_data(4, all_data[5])

    assert.is.same(all_data, rb:get_all_since(0))
    for i = 1, count do
      assert.is.same(table_splice(all_data, i, 5), rb:get_all_since(i))
    end
    assert.is.same({}, rb:get_all_since(6))
  end)

  it('should overrite old values', function()
    local count = 3
    local all_data = {}
    local rb = ts_rb.new(count)
    for i = 1, count do
      all_data[i] = 'test ' .. tostring(i)
      rb:push_data(i, all_data[i])
    end
    rb:push_data(4, 'overwritten')
    assert.is.same({ 'test 2', 'test 3', 'overwritten' }, rb:get_all_since(0))
  end)
end)

function table_splice(t, s, e)
  local tt = {}
  for i = s, e do
    tt[i - s + 1] = t[i]
  end
  return tt
end
