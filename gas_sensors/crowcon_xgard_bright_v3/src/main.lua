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
  if err ~= nil then
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
  local read_err_msg = nil

  local data, err = conn:read_holdings(conn_cfg.address, 1000, 2, 1000)
  if err then
    read_err_msg = 'Failed to read register 1000: ' .. err
  elseif not data then
    read_err_msg = 'No data from register 1000'
  elseif #data ~= 2 then
    read_err_msg = 'Invalid data length'
  else
    telemetry.h2_concentration = tofloat(data)
  end

  if read_err_msg then
    telemetry.alerts = { 'conn_error' }
    telemetry.alert_details = { conn_error = { errmsg = read_err_msg } }
    enapter.log(read_err_msg, 'error', true)
  end

  enapter.send_telemetry(telemetry)
end

function tofloat(registers)
  local raw_str = string.pack('BBBB', registers[1] >> 8, registers[1] & 0xff, registers[2] >> 8, registers[2] & 0xff)
  return string.unpack('>f', raw_str)
end

main()
