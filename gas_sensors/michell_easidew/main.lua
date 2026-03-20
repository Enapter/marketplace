-- Modbus register addresses
DEW_POINT_REG = 101
MOISTURE_CONTENT_REG = 103

local conn = nil
local conn_cfg = nil

function enapter.main()
  reconnect()
  configuration.after_write('connection', function()
    conn = nil
    conn_cfg = nil
  end)

  scheduler.add(1000, reconnect)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function reconnect()
  if conn then
    return
  end

  if not configuration.is_all_required_set('connection') then
    return
  end

  local cfg, err = configuration.read('connection')
  if err ~= nil then
    enapter.log('read connection configuration: ' .. err, 'error')
    return
  end
  conn_cfg = cfg

  local client, cerr = modbus.new(conn_cfg.conn_str)
  if not client then
    enapter.log('connect: modbus client creation failed: ' .. tostring(cerr), 'error')
    return
  end

  conn = client
end

function send_properties()
  enapter.send_properties({
    vendor = 'Michell',
    model = 'Easidew Online',
  })
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', conn_alerts = { 'not_configured' } })
    return
  end

  if not conn then
    enapter.send_telemetry({ status = 'conn_error', conn_alerts = { 'communication_failed' } })
    return
  end

  local telemetry = { status = 'ok', alerts = {} }

  local data, err = conn:read_holdings(conn_cfg.address, DEW_POINT_REG, 2, 1000)
  if err then
    enapter.log('failed to read dew point register ' .. DEW_POINT_REG .. ': ' .. err, 'error', true)
    telemetry.status = 'conn_error'
    telemetry.conn_alerts = { 'communication_failed' }
    enapter.send_telemetry(telemetry)
    return
  end
  telemetry.dew_point = tofloat(data)

  data, err = conn:read_holdings(conn_cfg.address, MOISTURE_CONTENT_REG, 2, 1000)
  if err then
    enapter.log('failed to read moisture register ' .. MOISTURE_CONTENT_REG .. ': ' .. err, 'error', true)
    telemetry.status = 'conn_error'
    telemetry.conn_alerts = { 'communication_failed' }
    enapter.send_telemetry(telemetry)
    return
  end
  telemetry.moisture_content = tofloat(data)

  enapter.send_telemetry(telemetry)
end

function tofloat(registers)
  local raw_str = string.pack('BBBB', registers[1] >> 8, registers[1] & 0xff, registers[2] >> 8, registers[2] & 0xff)
  return string.unpack('>f', raw_str)
end
