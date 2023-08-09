local config = require('enapter.ucm.config')
local App = require('app')

function main()
  local app = App.new()
  config.init(app.config, {
    after_write = app.setup,
  })

  local args, err = config.read_all()
  if err == nil then
    if config.is_all_options_set(args) then
      err = app.setup(args)
    else
      err = 'some required config options are missed'
    end

    if err then
      enapter.log('failed to setup: ' .. err, 'error', true)
    end
  else
    enapter.log('failed to read config: ' .. err, 'error', true)
  end

  scheduler.add(1000, app.get_properties)
  scheduler.add(5000, app.send_properties)
  scheduler.add(1000, app.send_telemetry)

  enapter.register_command_handler('start', app.cmd_start)
  enapter.register_command_handler('stop', app.cmd_stop)
  enapter.register_command_handler('power_on', app.cmd_power_on)
  enapter.register_command_handler('power_off', app.cmd_power_off)
end

main()
