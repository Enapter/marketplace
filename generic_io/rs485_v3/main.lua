local rs485_port = 'rs485'
local rs485_client

function main()
  local client, err = modbus.new('port://' .. rs485_port)
  if err ~= nil then
    enapter.log('Failed to create Modbus client: ' .. err)
  else
    rs485_client = client
  end

  enapter.register_command_handler('read', cmd_read)
  enapter.register_command_handler('write', cmd_write)

  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)
end

function send_telemetry()
  local status = 'ok'
  local alerts = {}
  if not rs485_client then
    table.insert(alerts, 'modbus_client_not_initialized')
    status = 'error'
  end

  local telemetry = { alerts = alerts, status = status }

  enapter.send_telemetry(telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-RS485' })
end

function cmd_read(ctx, args)
  if not rs485_client then
    ctx.error('modbus client is not initialized')
  end

  if args.port ~= rs485_port then
    ctx.error('unknown port ' .. args.port)
  end

  local results, err = rs485_client:read(args['queries'])
  if err ~= nil then
    ctx.error(err)
  end

  return { results = results }
end

function cmd_write(ctx, args)
  if not rs485_client then
    ctx.error('modbus client is not initialized')
  end

  if args.port ~= rs485_port then
    ctx.error('unknown port ' .. args.port)
  end

  local results, err = rs485_client:write(args['queries'])
  if err ~= nil then
    ctx.error(err)
  end

  return { results = results }
end

main()
