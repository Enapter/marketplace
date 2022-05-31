VENDOR = "Acme Energy"
MODEL = "FC 42"
SERIAL = "AE-421256"

alert = false
started = false
production_rate = 100

function main()
  scheduler.add(10000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('start', start_command)
  enapter.register_command_handler('stop', stop_command)
  enapter.register_command_handler('configure', configure_command)
  enapter.register_command_handler('read_configuration', read_configuration_command)
  enapter.register_command_handler('enable_alert', enable_alert_command)
  enapter.register_command_handler('disable_alert', disable_alert_command)
end

function send_properties()
  enapter.send_properties({
    vendor = VENDOR,
    model = MODEL,
    serial_number = SERIAL
  })
end

function send_telemetry()
  local telemetry = {
    alerts = {},
    voltage = 53.2,
    amperage = 0,
    anode_pressure = 621,
    production_rate = 0,
    run_hours = 1736,
    total_run_energy = 2604
  }
  if alert then
    telemetry.status = 'error'
    telemetry.alerts = {'anode_over_pressure'}
  elseif started then
    telemetry.status = 'running'
    telemetry.amperage = 38 / 100 * production_rate
    telemetry.production_rate = production_rate
  else
    telemetry.status = 'idle'
  end
  telemetry.power = telemetry.voltage * telemetry.amperage
  enapter.send_telemetry(telemetry)
end

function start_command()
  started = true
end

function stop_command()
  started = false
end

function configure_command(_ctx, args)
  production_rate = args.production_rate
end

function read_configuration_command()
  return { production_rate = production_rate }
end

function enable_alert_command()
  alert = true
  started = false
end

function disable_alert_command()
  alert = false
end

main()
