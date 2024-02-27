local rules
local read_stub_fn

_G.storage = {
  read = function(name)
    if read_stub_fn ~= nil then
      return read_stub_fn(name)
    end
  end,
  write = function() end,
}

describe('rules', function()
  before_each(function()
    package.loaded['rules'] = false
    rules = require('rules')
  end)

  after_each(function()
    read_stub_fn = nil
  end)

  it('should serialize rules and tz_offests to save it into storage', function()
    local s = spy.on(storage, 'write')
    rules:set({
      {
        cmd = 'r_full',
        condition = { voltage_min = 5.0, voltage_max = 6, time_min = '12:34', time_max = '15:49' },
      },
      {
        cmd = 'r_without_time',
        condition = { voltage_min = 1, voltage_max = 36 },
      },
      {
        cmd = 'r_without_voltage_min',
        condition = { voltage_max = 4 },
      },
      {
        cmd = 'r_without_voltage_max',
        condition = { voltage_min = 7 },
      },
    }, { { from = 0, offset = 7200 }, { from = 1234567, offset = 3600.0 } })
    assert.spy(s).was_called_with(
      'wp_rules',
      'r_full|5.0|6|12:34|15:49 r_without_time|1|36|| r_without_voltage_min||4|| r_without_voltage_max|7|||;'
        .. '0|7200 1234567|3600.0'
    )
    -- assert.spy(s).was_called_with('wp_tz_offsets', '0|7200 1234567|3600')
  end)

  it('should load rules and tz_offests from storage', function()
    read_stub_fn = function(name)
      if name == 'wp_rules' then
        return 'r1|2.0|3|04:56|07:89 r0|1|2.0|| r10|9||| r01|8|||;1.0|2345 6|789.0'
      end
    end

    local err = rules:load()
    assert.is_nil(err)

    assert.is_same({
      {
        cmd = 'r1',
        condition = {
          time_max = '07:89',
          time_min = '04:56',
          voltage_max = 3,
          voltage_min = 2.0,
        },
      },
      {
        cmd = 'r0',
        condition = {
          voltage_max = 2.0,
          voltage_min = 1,
        },
      },
      {
        cmd = 'r10',
        condition = {
          voltage_min = 9,
        },
      },
      {
        cmd = 'r01',
        condition = {
          voltage_min = 8,
        },
      },
    }, rules.rules)

    assert.is_same({
      {
        from = 1.0,
        offset = 2345,
      },
      {
        from = 6,
        offset = 789.0,
      },
    }, rules.tz_offsets)
  end)
end)
