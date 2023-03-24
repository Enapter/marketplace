local rl6 = require('enapter.ucm.generics.rl6')
local can = require('enapter.ucm.generics.can')
local msg_builder = require('msg_builder')
local fault_flag_alerts = require('fault_flag_alerts')

local CAN_INDEX_CONFIG = 'can_index'
local SAVE_0x400_CONFIG = 'save_0x400'
local CAN_UCM_ID_CONFIG = 'can_ucm_id'

local POWER_RELAY_UCM_ID_CONFIG = 'power_rl_ucm_id'
local POWER_RELAY_CHANNEL_CONFIG = 'power_rl_ch'
local START_RELAY_UCM_ID_CONFIG = 'start_rl_ucm_id'
local START_RELAY_CHANNEL_CONFIG = 'start_rl_ch'

return {
  new = function()
    local app = {
      properties = {},
      configured = false,
      config = {
        [CAN_INDEX_CONFIG] = { type = 'number', default = 1 },
        [SAVE_0x400_CONFIG] = { type = 'boolean', default = false },
        [CAN_UCM_ID_CONFIG] = { type = 'string', require = true },
        [POWER_RELAY_UCM_ID_CONFIG] = { type = 'string', require = true },
        [POWER_RELAY_CHANNEL_CONFIG] = { type = 'number', require = true },
        [START_RELAY_UCM_ID_CONFIG] = { type = 'string', require = true },
        [START_RELAY_CHANNEL_CONFIG] = { type = 'number', require = true },
      },
      power_relay = rl6.new(),
      start_relay = rl6.new(),
      can = can.new(),
    }

    function app.setup(args)
      local can_subscribtions = msg_builder.build(args[CAN_INDEX_CONFIG], args[SAVE_0x400_CONFIG])

      local err = app.can:setup(args[CAN_UCM_ID_CONFIG], can_subscribtions)
      if err then
        enapter.log('cannot setup can: ' .. tostring(err))
      end

      app.power_relay:setup(args[POWER_RELAY_UCM_ID_CONFIG], args[POWER_RELAY_CHANNEL_CONFIG])
      app.start_relay:setup(args[START_RELAY_UCM_ID_CONFIG], args[START_RELAY_CHANNEL_CONFIG])
      app.configured = true
    end

    function app.get_properties()
      local info = { vendor = 'Intelligent Energy', model = 'FCM 804' }
      if app.configured then
        local can_props, err = app.can:get('properties')
        if err then
          enapter.log(err, 'info')
        else
          for k, v in pairs(can_props) do
            info[k] = v
          end
        end
      end

      app.properties = info
    end

    function app.send_properties()
      enapter.send_properties(app.properties)
    end

    function app.send_telemetry()
      if not app.configured then
        enapter.send_telemetry({ status = 'error', alerts = { 'not_configured' } })
        return
      end

      local telemetry, err = app.can:get('telemetry')
      if err then
        enapter.send_telemetry({
          status = 'error',
          alerts = { 'cannot_read_telemetry' },
          alert_details = { cannot_read_telemetry = { errmsg = err } },
        })
        return
      end

      local can_telemetry_is_empty = next(telemetry) == nil
      if can_telemetry_is_empty then
        telemetry = { alerts = {} }
      else
        telemetry.alerts = fault_flag_alerts.make_from_telemetry(telemetry)
      end

      local powered, err = app.power_relay:is_closed()
      if powered then
        telemetry['powered'] = true
        if telemetry['status'] == nil then
          telemetry['status'] = 'on'
        end
      elseif not err then
        telemetry['powered'] = false
        if telemetry['status'] == nil then
          telemetry['status'] = 'off'
        end
      end

      local started, err = app.start_relay:is_closed()
      if started then
        telemetry['started'] = true
      elseif not err then
        telemetry['started'] = false
      end

      enapter.send_telemetry(telemetry)
    end

    function app.cmd_power_on(ctx)
      app.do_relay_cmd(ctx, function()
        return app.power_relay:close()
      end)
    end

    function app.cmd_power_off(ctx)
      if app.start_relay:is_closed() then
        ctx.error('cannot power off started fuel cell, stop it previously')
      end
      app.do_relay_cmd(ctx, function()
        return app.power_relay:open()
      end)
    end

    function app.cmd_start(ctx)
      if not app.power_relay:is_closed() then
        ctx.error('cannot start powered off fuel cell, power on it previously')
      end
      app.do_relay_cmd(ctx, function()
        return app.start_relay:close()
      end)
    end

    function app.cmd_stop(ctx)
      app.do_relay_cmd(ctx, function()
        return app.start_relay:open()
      end)
    end

    function app.do_relay_cmd(ctx, relay_cmd)
      if not app.configured then
        ctx.error('Device is not properly configured. Use "Configure" command to setup.')
      end

      local err = relay_cmd()
      if err then
        ctx.error(err)
      end
    end

    return app
  end,
}
