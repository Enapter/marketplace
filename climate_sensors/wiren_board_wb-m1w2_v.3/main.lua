local conn
local conn_cfg

function enapter.main()
  reconnect()
  configuration.after_write('connection', function()
    conn = nil
    conn_cfg = nil
  end)
  scheduler.add(1000, reconnect)
  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)
end

function reconnect()
  if conn then
    return
  end

  local configured = configuration.is_all_required_set('connection')
  if not configured then
    return
  end

  local cfg, err = configuration.read('connection')
  if err ~= nil then
    enapter.log('read configuration: ' .. err, 'error')
    return
  end
  conn_cfg = cfg

  local client, err = modbus.new(conn_cfg.connection_uri)
  if err ~= nil then
    enapter.log('connect: ' .. err, 'error')
    return
  end
  conn = client

  local err = conn:write_multiple_holdings(conn_cfg.unit_id, 275, { 0, 0 }, 1000)
  if err ~= nil then
    enapter.log('set input mode: ' .. err, 'error')
  end
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    return
  end
  if not conn then
    enapter.send_telemetry({ status = 'error', alerts = { 'modbus_error' } })
    return
  end

  local telemetry = {
    status = 'ok',
    alerts = {},
  }

  local connected, err = conn:read_discrete_inputs(conn_cfg.unit_id, 16, 2, conn_cfg.timeout)
  if err ~= nil then
    enapter.log('read connection status: ' .. err, 'error')
    telemetry['status'] = 'error'
    telemetry['alerts'] = { 'modbus_error' }
  elseif connected[conn_cfg.input] == 0 then
    telemetry['status'] = 'error'
    telemetry['alerts'] = { 'sensor_not_connected' }
  end

  local temperature, err = conn:read_inputs(conn_cfg.unit_id, 7, 2, conn_cfg.timeout)
  if err ~= nil then
    enapter.log('read temperature: ' .. err, 'error')
    telemetry['status'] = 'error'
    telemetry['alerts'] = { 'modbus_error' }
  elseif temperature[conn_cfg.input] ~= 0x7FFF then
    telemetry['ambient_temperature'] = temperature[conn_cfg.input] * 0.0625
  end

  enapter.send_telemetry(telemetry)
end

function send_properties()
  if not conn then
    return
  end

  local model, err = conn:read_inputs(conn_cfg.unit_id, 200, 20, conn_cfg.timeout)
  if err ~= nil then
    enapter.log('read model: ' .. err, 'error')
    return
  end

  local serial_num, err = conn:read_inputs(conn_cfg.unit_id, 270, 2, conn_cfg.timeout)
  if err ~= nil then
    enapter.log('read serial number: ' .. err, 'error')
    return
  end

  local version, err = conn:read_inputs(conn_cfg.unit_id, 250, 16, conn_cfg.timeout)
  if err ~= nil then
    enapter.log('read firmware version: ' .. err, 'error')
    return
  end

  enapter.send_properties({
    vendor = 'Wiren Board',
    model = bytes2string(model, 1, 20),
    serial_number = tostring((serial_num[1] << 16) + serial_num[2]),
    firmware_version = bytes2string(version),
  })
end

function bytes2string(t)
  local s = {}
  for i = 1, #t do
    if t[i] == 0 then
      break
    end
    s[#s + 1] = t[i]
  end
  return string.char(table.unpack(s))
end
