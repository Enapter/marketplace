local function is_messages(_, arguments)
  return function(value)
    if #value ~= #arguments[1] then
      return false
    end
    for i in ipairs(value) do
      if #value[i] ~= #arguments[1][i] then
        return false
      end
    end
    return true
  end
end

assert:register('matcher', 'messages', is_messages)

local stubs = require('enapter.ucm.stubs')
local msg_builder = require('msg_builder')
local enapter_stub = {
  register_command_handler = function() end,
  log = function(msg, level)
    print('[', level, ']', msg)
  end,
}

_G.enapter = enapter_stub

describe('app', function()
  local cfg = {
    can_ucm_id = 'test_ucm_id',
    can_index = 1,
    power_rl_ucm_id = 'test_power_ucm_id',
    power_rl_ch = math.tointeger(3),
    start_rl_ucm_id = 'test_start_ucm_id',
    start_rl_ch = math.tointeger(6),
  }

  local app
  local power_relay_stub, start_relay_stub, can_stub

  before_each(function()
    local can_stub_pkg = stubs.setup_generic_can()
    can_stub = stubs.new_dummy_can()
    can_stub_pkg.stubs = { can_stub }

    local rl6_stub = stubs.setup_generic_rl6()
    power_relay_stub = stubs.new_dummy_rl6()
    start_relay_stub = stubs.new_dummy_rl6()
    rl6_stub.stubs = { power_relay_stub, start_relay_stub }

    package.loaded['app'] = false
    app = require('app').new()
  end)

  after_each(function()
    stubs.teardown_generic_rl6()
    stubs.teardown_generic_can()
  end)

  it('should have valid config options', function()
    local config = require('enapter.ucm.config')
    assert.has_no_error(function()
      config.init(app.config)
    end)
  end)

  it('should setup can and two relays', function()
    local messages = msg_builder.build(cfg.can_index)

    can_stub:should_return('get')

    local can_setup_spy = spy.on(can_stub, 'setup')
    local pr_setup_spy = spy.on(power_relay_stub, 'setup')
    local sr_setup_spy = spy.on(start_relay_stub, 'setup')
    app.setup(cfg)
    assert.spy(can_setup_spy).was_called(1)
    assert.spy(can_setup_spy).was_called_with(can_stub, cfg.can_ucm_id, match.messages(messages))
    assert.spy(pr_setup_spy).was_called(1)
    assert.spy(sr_setup_spy).was_called(1)
    assert.spy(pr_setup_spy).was_called_with(power_relay_stub, cfg.power_rl_ucm_id, cfg.power_rl_ch)
    assert.spy(sr_setup_spy).was_called_with(start_relay_stub, cfg.start_rl_ucm_id, cfg.start_rl_ch)
  end)

  it('should send static properites if not configured', function()
    local s = spy.on(enapter_stub, 'send_properties')
    app.get_properties()
    app.send_properties()
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with({ model = 'FCM 804', vendor = 'Intelligent Energy' })
  end)

  it('should send properites from can if configured', function()
    app.setup(cfg)

    can_stub:should_return('get', { can_prop = 12, another_can_prop = 'test can prop' })

    local cgs = spy.on(can_stub, 'get')
    local sps = spy.on(enapter_stub, 'send_properties')

    app.get_properties()
    app.send_properties()

    assert.spy(cgs).was_called(1)
    assert.spy(sps).was_called(1)
    assert.spy(cgs).was_called_with(can_stub, 'properties')
    assert.spy(sps).was_called_with({
      can_prop = 12,
      another_can_prop = 'test can prop',
      model = 'FCM 804',
      vendor = 'Intelligent Energy',
    })
  end)

  it('should send static properites if can returns error', function()
    app.setup(cfg)

    can_stub:should_return('get', nil, 'test error')

    local s = spy.on(enapter_stub, 'send_properties')
    app.get_properties()
    app.send_properties()
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with({ model = 'FCM 804', vendor = 'Intelligent Energy' })
  end)

  it('should not send telemetry if not configured', function()
    local s = spy.on(enapter_stub, 'send_telemetry')

    app.send_telemetry()
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with({ status = 'error', alerts = { 'not_configured' } })
  end)

  it('should not send telemetry if cannot read from can', function()
    app.setup(cfg)

    can_stub:should_return('get', nil, 'test error')

    local s = spy.on(enapter_stub, 'send_telemetry')
    app.send_telemetry()
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with({
      status = 'error',
      alerts = { 'cannot_read_telemetry' },
      alert_details = { cannot_read_telemetry = { errmsg = 'test error' } },
    })
  end)

  it('should send can telemetry', function()
    app.setup(cfg)

    local can_telemetry = { status = 'ok', can_t = 42, can_t_str = 'ok' }
    can_stub:should_return('get', can_telemetry)

    local cgs = spy.on(can_stub, 'get')
    local sts = spy.on(enapter_stub, 'send_telemetry')

    app.send_telemetry()

    assert.spy(cgs).was_called(1)
    assert.spy(sts).was_called(1)
    assert.spy(cgs).was_called_with(can_stub, 'telemetry')
    assert.spy(sts).was_called_with(can_telemetry)
  end)

  it('should fill alerts from can telemetry if all fault flags are set', function()
    app.setup(cfg)

    local can_telemetry = {
      status = 'fault',
      fault_flags_a = 0,
      fault_flags_b = 0x1,
      fault_flags_c = 0x11,
      fault_flags_d = 0x2,
    }
    can_stub:should_return('get', can_telemetry)

    local expected_telemetry = {
      alerts = { 'Stack3OverCurrent', 'PurgeMissedOneIxSolSaver', 'NoisyInputTx68' },
      powered = false,
      started = false,
    }
    for k, v in pairs(can_telemetry) do
      expected_telemetry[k] = v
    end

    local s = spy.on(enapter_stub, 'send_telemetry')
    app.send_telemetry()
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with(expected_telemetry)
  end)

  it('should not fill alerts from can telemetry if any fault flags are missed', function()
    app.setup(cfg)

    local can_telemetry = {
      fault_flags_a = 0,
      fault_flags_b = 0x1,
      fault_flags_c = 0x11,
      fault_flags_d = 0x2,
    }
    local fault_keys = table_keys(can_telemetry)
    can_telemetry[fault_keys[math.random(1, #fault_keys)]] = nil
    can_telemetry['status'] = 'ok'
    can_stub:should_return('get', can_telemetry)

    local s = spy.on(enapter_stub, 'send_telemetry')
    app.send_telemetry()
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with(can_telemetry)
  end)

  it('should send status of power if can telemetry without status', function()
    app.setup(cfg)

    local function check(is_closed, status)
      can_stub:should_return('get', { without_status = 'empty' })
      power_relay_stub:should_return('is_closed', is_closed)

      local pri = spy.on(power_relay_stub, 'is_closed')
      local sts = spy.on(enapter_stub, 'send_telemetry')

      app.send_telemetry()

      assert.spy(pri).was_called(1)
      assert.spy(sts).was_called(1)
      assert.spy(pri).was_called_with(power_relay_stub)
      assert
        .spy(sts)
        .was_called_with({ without_status = 'empty', status = status, powered = is_closed, started = false })
    end

    check(true, 'on')
    check(false, 'off')
  end)

  it('should send telemetry with status of start relay', function()
    app.setup(cfg)

    local function check(is_closed)
      can_stub:should_return('get', { status = 'ok' })
      start_relay_stub:should_return('is_closed', is_closed)

      local sts = spy.on(enapter_stub, 'send_telemetry')

      app.send_telemetry()

      assert.spy(sts).was_called(1)
      assert.spy(sts).was_called_with({ status = 'ok', powered = false, started = is_closed })
    end

    check(true, 'on')
    check(false, 'off')
  end)

  it('should not send status of power if relay returns error', function()
    app.setup(cfg)

    can_stub:should_return('get', { status = 'ok' })
    power_relay_stub:should_return('is_closed', nil, 'power relay error')
    local started = math.random() > 0.5
    start_relay_stub:should_return('is_closed', started)

    local sts = spy.on(enapter_stub, 'send_telemetry')

    app.send_telemetry()

    assert.spy(sts).was_called_with({ status = 'ok', started = started })
  end)

  it('should not send status of start if relay returns error', function()
    app.setup(cfg)

    can_stub:should_return('get', { status = 'ok' })
    start_relay_stub:should_return('is_closed', nil, 'start relay error')
    local powered = math.random() > 0.5
    power_relay_stub:should_return('is_closed', powered)

    local sts = spy.on(enapter_stub, 'send_telemetry')

    app.send_telemetry()

    assert.spy(sts).was_called_with({ status = 'ok', powered = powered })
  end)

  it('should send empty alerts if can telemetry is empty', function()
    app.setup(cfg)

    local s = spy.on(enapter_stub, 'send_telemetry')
    app.send_telemetry()

    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with({ alerts = {}, status = 'off', powered = false, started = false })
  end)

  it('should execute commands on desired relays', function()
    app.setup(cfg)

    local pr_close_spy = spy.on(power_relay_stub, 'close')
    app.cmd_power_on()
    assert.spy(pr_close_spy).was_called(1)

    local pr_open_spy = spy.on(power_relay_stub, 'open')
    app.cmd_power_off()
    assert.spy(pr_open_spy).was_called(1)

    local sr_close_spy = spy.on(start_relay_stub, 'close')
    power_relay_stub:should_return('is_closed', true)
    app.cmd_start()
    assert.spy(sr_close_spy).was_called(1)

    local sr_open_spy = spy.on(start_relay_stub, 'open')
    app.cmd_stop()
    assert.spy(sr_open_spy).was_called(1)
  end)

  it('should not execute command if not configured', function()
    local ctx = {
      error = function(err)
        error(err)
      end,
    }
    assert.has_error(function()
      app.cmd_power_on(ctx)
    end, 'Device is not properly configured. Use "Configure" command to setup.')
  end)

  it('should return relay command errors', function()
    local ctx = {
      error = function(err)
        error(err)
      end,
    }
    app.setup(cfg)

    power_relay_stub:should_return('close', 'power_on error')
    assert.has_error(function()
      app.cmd_power_on(ctx)
    end, 'power_on error')

    power_relay_stub:should_return('open', 'power_off error')
    assert.has_error(function()
      app.cmd_power_off(ctx)
    end, 'power_off error')

    start_relay_stub:should_return('close', 'start error')
    power_relay_stub:should_return('is_closed', true)
    assert.has_error(function()
      app.cmd_start(ctx)
    end, 'start error')

    start_relay_stub:should_return('open', 'stop error')
    assert.has_error(function()
      app.cmd_stop(ctx)
    end, 'stop error')
  end)

  it('should not start if powered off', function()
    local ctx = {
      error = function(err)
        error(err)
      end,
    }
    app.setup(cfg)

    power_relay_stub:should_return('is_closed', false)
    assert.has_error(function()
      app.cmd_start(ctx)
    end, 'cannot start powered off fuel cell, power on it previously')
  end)

  it('should not power off if started', function()
    local ctx = {
      error = function(err)
        error(err)
      end,
    }
    app.setup(cfg)

    start_relay_stub:should_return('is_closed', true)
    assert.has_error(function()
      app.cmd_power_off(ctx)
    end, 'cannot power off started fuel cell, stop it previously')
  end)
end)

function table_keys(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end
