_G.inspect = require('inspect')

local msg_builder = require('msg_builder')

describe('message builder', function()
  it('should respect can_index', function()
    local can_index_1, can_index_2 = 3, 7
    local m1, m2 = msg_builder.build(can_index_1), msg_builder.build(can_index_2)
    for i, _ in ipairs(m1.properties) do
      assert.is.equals(m1.properties[i].msg_id - can_index_1, m2.properties[i].msg_id - can_index_2)
    end
    for i, _ in ipairs(m1.telemetry) do
      assert.is.equals(m1.telemetry[i].msg_id - can_index_1, m2.telemetry[i].msg_id - can_index_2)
    end
  end)

  it('should add messages_0x400 if requested', function()
    local m1 = msg_builder.build(1)
    local m2 = msg_builder.build(2, true)

    assert.is_false(messages_has_name(m1.telemetry, 'messages_0x400'))
    assert.is_true(messages_has_name(m2.telemetry, 'messages_0x400'))
  end)

  describe('should process property', function()
    local messages = msg_builder.build(1, true)
    local tests = {
      { name = 'fw_ver', msg_id = 0x318, data = '01c3ff0000000000', ret = '1.195.255' },
      {
        name = 'serial_number',
        msg_id = 0x310,
        data = { '4945313231323741', 'b830353030303100' },
        ret = 'IE12127A8050001',
      },
      {
        name = 'serial_number (reverse message order)',
        msg_id = 0x310,
        data = { 'b830353030303100', '4945313231323741' },
        ret = nil,
      },
    }

    test_parsers(messages.properties, tests)
  end)

  describe('should process telemetry', function()
    local messages = msg_builder.build(1, true)
    local tests = {
      {
        name = 'run_hours, total_run_energy',
        msg_id = 0x320,
        data = '002cb46d0cf9102d',
        ret = { 2929773, 217649197 },
      },
      {
        name = 'fault_flags a & b',
        msg_id = 0x328,
        data = '0012003456007800',
        ret = { 1179700, 1442871296 },
      },
      {
        name = 'fault_flags c & d',
        msg_id = 0x378,
        data = '1200340000560078',
        ret = { 302003200, 5636216 },
      },
      {
        name = 'watt, volt, amp, anode_pressure',
        msg_id = 0x338,
        data = 'fff713b8ffee184f',
        ret = { -9, 50.48, -0.18, 622.3 },
      },
      {
        name = 'outlet_temp, inlet_temp, dcdc_volt_setpoint, dcdc_amp_limit',
        msg_id = 0x348,
        data = '0d550d1027000578',
        ret = { 34.13, 33.44, 99.84, 14 },
      },
      {
        name = 'louver_pos, fan_sp_duty',
        msg_id = 0x358,
        data = 'fceb070000000000',
        ret = { -7.89, 17.92 },
      },
      {
        name = 'status (fault)',
        msg_id = 0x368,
        data = '1000000000000000',
        ret = 'fault',
      },
      {
        name = 'status (steady)',
        msg_id = 0x368,
        data = '2000000000000000',
        ret = 'steady',
      },
      {
        name = 'status (run)',
        msg_id = 0x368,
        data = '4000000000000000',
        ret = 'run',
      },
      {
        name = 'status (inactive)',
        msg_id = 0x368,
        data = '8000000000000000',
        ret = 'inactive',
      },
      {
        name = 'status (no status)',
        msg_id = 0x368,
        data = '0100000000000000',
        ret = nil,
      },
      {
        name = '0x400',
        msg_id = 0x400,
        data = { '12345678abcdefgh', 'hgfedcba12345678' },
        ret = ' 12345678abcdefgh hgfedcba12345678',
      },
    }

    test_parsers(messages.telemetry, tests)
  end)
end)

function test_parsers(messages, tests)
  for _, tc in ipairs(tests) do
    it(tc.name, function()
      local m = get_from_messages(messages, tc.msg_id)
      local d = m.parser(tc.data)
      assert.is.same(tc.ret, d)
    end)
  end
end

function messages_has_name(messages, name)
  for _, m in ipairs(messages) do
    if m.name == name then
      return true
    end
  end
  return false
end

function get_from_messages(messages, msg_id)
  for _, m in ipairs(messages) do
    if m.msg_id == msg_id then
      return m
    end
  end
  return nil
end
