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

  scheduler.add(30000, app.send_properties)
  scheduler.add(1000, app.send_telemetry)
  scheduler.add(1000, app.cleanup_unused_can_packets)

  enapter.register_command_handler('read', app.cmd_read)
  enapter.register_command_handler('write', app.cmd_write)
end

main()
