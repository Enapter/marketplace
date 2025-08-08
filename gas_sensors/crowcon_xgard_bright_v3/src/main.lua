local conn = nil
local conn_cfg = nil
local conn_error_msg = nil

function main()
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

  local configured = configuration.is_all_required_set('connection')
  if not configured then
    return
  end

  local cfg, err = configuration.read('connection')
  if err ~= nil then
    conn_error_msg = 'failed to read configuration: ' .. err
    return
  end

  conn_cfg = cfg
  local client, err = modbus.new(conn_cfg.conn_str)
  if not err then
    conn_error_msg = 'failed to connect: ' .. err
    return
  end

  conn = client
  conn_error_msg = nil
end

function send_properties()
  enapter.send_properties({
    vendor = 'Crowcon',
    model = 'Xgard Bright',
  })
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ alerts = { 'not_configured' } })
    return
  end

  if not conn then
    enapter.send_telemetry({
      alerts = { 'conn_error' },
      alert_details = { conn_error = { errmsg = conn_error_msg } },
    })
    enapter.log(conn_error_msg, 'error', true)
    return
  end

  local telemetry = { status = 'ok', alerts = {} }
  local alert = nil

  local data, err = conn:read_holdings(conn_cfg.address, 1000, 2, 1000)
  if err then
    conn_error_msg = 'Failed to read register 1000: ' .. err
    alert = 'conn_error'
    enapter.log(conn_error_msg, 'error', true)
  elseif not data then
    conn_error_msg = 'No data from register 1000'
    alert = 'conn_error'
    enapter.log(conn_error_msg, 'error', true)
  elseif #data ~= 2 then
    conn_error_msg = 'Invalid data length'
    alert = 'conn_error'
    enapter.log(conn_error_msg, 'error', true)
  else
    telemetry.h2_concentration = tofloat(data)
  end

  if alert then
    telemetry.alerts = { alert }
    telemetry.alert_details = { conn_error = { errmsg = conn_error_msg } }
  end

  enapter.send_telemetry(telemetry)
end

function tofloat(registers)
  local raw_str = string.pack('BBBB', registers[1] >> 8, registers[1] & 0xff, registers[2] >> 8, registers[2] & 0xff)
  return string.unpack('>f', raw_str)
end

main()
