describe('app', function()
  local app, can_packets_stub
  local cfg = { baud_rate = 1234 }
  local cmd_ctx = {
    error = function(msg)
      error(msg)
    end,
  }

  before_each(function()
    _G.enapter = {
      register_command_handler = function() end,
    }
    _G.can = {
      init = function()
        return 0
      end,
      send = function()
        return 0
      end,
      err_to_str = function(e)
        return 'can error: ' .. tostring(e)
      end,
    }
    can_packets_stub = {
      update_cache_bucket_size = function() end,
      get_since = function() end,
    }
    package.loaded['can_packets'] = false
    package.preload['can_packets'] = function()
      return can_packets_stub
    end
    package.loaded['app'] = false
    app = require('app').new()
  end)

  after_each(function()
    _G.enapter = nil
    _G.can = nil
    package.loaded['can_packets'] = false
    package.preload['can_packets'] = nil
  end)

  it('should have valid config options', function()
    local config = require('enapter.ucm.config')
    assert.has_no_error(function()
      config.init(app.config)
    end)
  end)

  it('should init can on setup', function()
    local s = spy.on(_G.can, 'init')
    assert.is_nil(app.setup(cfg))
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with(cfg.baud_rate, match._)
  end)

  it('should not init can with non integer or missed baud rate', function()
    local s = spy.on(_G.can, 'init')

    assert.is_equals('baud rate is required and must be an integer', app.setup({}))
    assert.is_equals(
      'baud rate is required and must be an integer',
      app.setup({ baud_rate = 'seven' })
    )

    assert.spy(s).was_not_called()
  end)

  describe('read command', function()
    it('should get can packets', function()
      app.setup(cfg)

      local in_cursor = math.random(10000)
      local out_cursor = tostring(math.random())
      local out_results = tostring(math.random())
      local msg_ids = { math.random(100), math.random(100) }
      can_packets_stub.get_since = function()
        return out_results, out_cursor
      end

      local s = spy.on(can_packets_stub, 'get_since')
      local payload =
        app.cmd_read(cmd_ctx, { cursor = in_cursor, msg_ids = table.concat(msg_ids, ',') })

      assert.spy(s).was_called(1)
      assert.spy(s).was_called_with(in_cursor, msg_ids)
      assert.is_same({ cursor = out_cursor, results = out_results }, payload)
    end)

    describe('should not execute', function()
      it('if not configured', function()
        assert.has_error(function()
          app.cmd_read(cmd_ctx)
        end, 'can is not properly configured')
      end)

      it('if msg_ids is missed', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_read(cmd_ctx, {})
        end, 'msg_ids arg is required and must be a string')
      end)

      it('if msg_ids is not a string', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_read(cmd_ctx, { msg_ids = { 1, 2, 3 } })
        end, 'msg_ids arg is required and must be a string')
      end)

      it('if msg_id is not an integer', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_read(cmd_ctx, { msg_ids = '1,two,3' })
        end, 'msg_id must be an integer')
      end)

      it('if cursor is present and not an integer', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_read(cmd_ctx, { msg_ids = '1, 2, 3', cursor = 'cursor' })
        end, 'cursor must be a value from the previous read')
      end)
    end)
  end)

  describe('write command', function()
    it('should convert data before send', function()
      local s = spy.on(_G.can, 'send')

      app.setup(cfg)

      local args = { msg_id = math.random(100), data = '656e617074657221' }
      assert.is_nil(app.cmd_write(cmd_ctx, args))

      assert.spy(s).was_called(1)
      assert.spy(s).was_called_with(args.msg_id, 'enapter!')
    end)

    describe('should not execute', function()
      it('if not configured', function()
        assert.has_error(function()
          app.cmd_write(cmd_ctx)
        end, 'can is not properly configured')
      end)

      it('if msg_id is missed', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_write(cmd_ctx, {})
        end, 'msg_id arg is required and must be an integer')
      end)

      it('if msg_id is not an integer', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_write(cmd_ctx, { msg_id = 'id' })
        end, 'msg_id arg is required and must be an integer')
      end)

      it('if data is missed', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_write(cmd_ctx, { msg_id = 42 })
        end, 'data arg is required and must be a string')
      end)

      it('if data is not a string', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_write(cmd_ctx, { msg_id = 42, data = 42 })
        end, 'data arg is required and must be a string')
      end)

      it('if data is not a 16-char string', function()
        app.setup(cfg)
        assert.has_error(function()
          app.cmd_write(cmd_ctx, { msg_id = 42, data = 'data' })
        end, 'data arg must be a 16-char string')
      end)
    end)
  end)
end)
