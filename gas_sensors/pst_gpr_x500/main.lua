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

  local client, cerr = analogin.new(conn_cfg.conn_str)
  if not client then
    enapter.log('connect: analog input creation failed: ' .. tostring(cerr), 'error')
    return
  end

  conn = client
end

function send_properties()
  enapter.send_properties({
    vendor = 'PST',
    model = 'GPR-x500',
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

  local current, err = conn:get_amps()
  if err then
    enapter.log('failed to read current: ' .. err, 'error', true)
    telemetry.status = 'conn_error'
    telemetry.conn_alerts = { 'communication_failed' }
    enapter.send_telemetry(telemetry)
    return
  end

  local current_ma = current * 1000
  telemetry.adc_current = current_ma
  telemetry.oxygen_concentration = calculate_oxygen_concentration(current_ma)

  enapter.send_telemetry(telemetry)
end

function calculate_oxygen_concentration(current_ma)
  return current_ma
end
