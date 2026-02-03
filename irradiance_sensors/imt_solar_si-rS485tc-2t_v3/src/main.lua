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

function send_properties()
  enapter.send_properties({ vendor = 'IMT Solar', model = 'Si-RS485TC-2T' })
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
  local alert_msg = nil

  local data, err = conn:read_inputs(conn_cfg.address, 0, 1, 1000)
  if err then
    alert = 'conn_error'
    alert_msg = 'failed to read register 0: ' .. err
    enapter.log(alert_msg, 'error', true)
  else
    telemetry.solar_irradiance = apply_gain(uint16(data[1]))
  end

  local data, err = conn:read_inputs(conn_cfg.address, 7, 2, 1000)
  if err then
    alert = 'conn_error'
    alert_msg = 'failed to read registers 7-8: ' .. err
    enapter.log(alert_msg, 'error', true)
  else
    telemetry.module_temperature = apply_gain(int16(data[1]))
    telemetry.ambient_temperature = apply_gain(uint16(data[2]))
  end

  if alert then
    telemetry.alerts = { alert }
    telemetry.alert_details = { conn_error = { errmsg = alert_msg } }
  end

  enapter.send_telemetry(telemetry)
end

function apply_gain(value)
  if value == nil then
    return
  end
  local gain = 0.1
  return value * gain
end

function uint16(register)
  if #register ~= 1 then
    return
  end
  local raw_str = string.pack('BB', register[1] & 0xFF, register[1] >> 8)
  return string.unpack('I2', raw_str)
end

function int16(register)
  if #register ~= 1 then
    return
  end
  local raw_str = string.pack('BB', register[1] & 0xFF, register[1] >> 8)
  return string.unpack('i2', raw_str)
end

main()
