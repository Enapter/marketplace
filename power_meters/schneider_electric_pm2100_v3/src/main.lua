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
  if not conn then
    return
  end

  local properties = { vendor = 'Schneider Electric' }
  local data, err = conn:read_holdings(conn_cfg.address, 49, 20, 1000)

  if err then
    enapter.log('failed to get device model: ' .. err, 'error', true)
  elseif not data then
    enapter.log('no data received for device model', 'error', true)
  elseif #data ~= 20 then
    enapter.log('invalid data length of device model', 'error', true)
  else
    properties.model = get_model(data)
  end

  enapter.send_properties(properties)
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
  local alert_error_msg

  local results, err = fetch_phase_metrics(conn)
  if err then
    alert_error_msg = 'error fetching phase metrics: ' .. err
    enapter.log(alert_error_msg, 'error', true)
  else
    if not parse_phase_metrics(telemetry, results) then
      alert_error_msg = 'failed to parse phase metrics. See device logs.'
    end
  end

  results, err = fetch_other_metrics(conn)
  if err then
    alert_error_msg = 'error fetching other metrics: ' .. err
    enapter.log(alert_error_msg, 'error', true)
  else
    if not parse_other_metrics(telemetry, results) then
      alert_error_msg = 'failed to parse other metrics. See device logs.'
    end
  end

  if alert_error_msg then
    telemetry.alerts = { 'conn_error' }
    telemetry.alert_details = { conn_error = { errmsg = alert_error_msg } }
  end
  enapter.send_telemetry(telemetry)
end

function fetch_phase_metrics(client)
  local addr = conn_cfg.address
  local queries = {
    { type = 'holdings', addr = addr, reg = 2999, count = 6, timeout = 1000 },
    { type = 'holdings', addr = addr, reg = 3027, count = 6, timeout = 1000 },
    { type = 'holdings', addr = addr, reg = 3053, count = 6, timeout = 1000 },
  }
  return fetch_metrics(client, queries)
end

function parse_phase_metrics(telemetry, results)
  local is_err = false
  local data, err = get_data(results, 1)
  if err then
    enapter.log('failed to get phase current: ' .. err, 'error', true)
    is_err = true
  else
    extract_data_float(telemetry, data, 1, 'ac_l1_current')
    extract_data_float(telemetry, data, 3, 'ac_l2_current')
    extract_data_float(telemetry, data, 5, 'ac_l3_current')
  end
  local data, err = get_data(results, 2)
  if err then
    enapter.log('failed to get phase voltage: ' .. err, 'error', true)
    is_err = true
  else
    extract_data_float(telemetry, data, 1, 'ac_l1_voltage')
    extract_data_float(telemetry, data, 3, 'ac_l2_voltage')
    extract_data_float(telemetry, data, 5, 'ac_l3_voltage')
  end
  local data, err = get_data(results, 3)
  if err then
    enapter.log('failed to get phase power: ' .. err, 'error', true)
    is_err = true
  else
    extract_data_float(telemetry, data, 1, 'ac_l1_power')
    extract_data_float(telemetry, data, 3, 'ac_l2_power')
    extract_data_float(telemetry, data, 5, 'ac_l3_power')
  end
  return is_err
end

function fetch_other_metrics(client)
  local addr = conn_cfg.address
  local queries = {
    { type = 'holdings', addr = addr, reg = 2699, count = 2, timeout = 1000 },
    { type = 'holdings', addr = addr, reg = 2703, count = 2, timeout = 1000 },
    { type = 'holdings', addr = addr, reg = 3059, count = 2, timeout = 1000 },
    { type = 'holdings', addr = addr, reg = 3109, count = 2, timeout = 1000 },
  }
  return fetch_metrics(client, queries)
end

function parse_other_metrics(telemetry, results)
  local is_err = false
  local data, err = get_data(results, 1)
  if err then
    enapter.log('failed to get energy_total: ' .. err, 'error', true)
    is_err = true
  else
    extract_data_float(telemetry, data, 1, 'energy_total')
  end

  local data, err = get_data(results, 2)
  if err then
    enapter.log('failed to get active_energy_delivered_and_received: ' .. err, 'error', true)
    is_err = true
  else
    extract_data_float(telemetry, data, 1, 'active_energy_delivered_and_received')
  end

  local data, err = get_data(results, 3)
  if err then
    enapter.log('failed to get total_power: ' .. err, 'error', true)
    is_err = true
  else
    extract_data_float(telemetry, data, 1, 'total_power')
  end

  local data, err = get_data(results, 4)
  if err then
    enapter.log('failed to get ac_frequency: ' .. err, 'error', true)
    is_err = true
  else
    extract_data_float(telemetry, data, 1, 'ac_frequency')
  end
  return is_err
end

function fetch_metrics(client, queries)
  local results, err = client:read(queries)
  if err then
    return nil, err
  elseif not results then
    return nil, 'no results received'
  elseif #results ~= #queries then
    return nil, 'invalid response length (expected: ' .. #queries .. ', got: ' .. #results .. ')'
  end
  return results, nil
end

function get_data(results, num)
  local res = results[num]
  if res.errmsg ~= nil then
    return nil, 'error reading query ' .. num .. ': ' .. res.errmsg
  end

  if res.data == nil then
    return nil, 'error reading query ' .. num .. ': data is missing'
  end
  return res.data, nil
end

function extract_data_float(telemetry, registers, start, name)
  local raw_str = string.pack(
    'BBBB',
    registers[start] >> 8,
    registers[start] & 0xff,
    registers[start + 1] >> 8,
    registers[start + 1] & 0xff
  )
  telemetry[name] = string.unpack('>f', raw_str)
end

function get_model(data)
  if #data ~= 20 then
    return
  end

  local model = ''
  for _, register in pairs(data) do
    if register == 0 then
      break
    end
    model = model .. string.char(register >> 8)
    model = model .. string.char(register & 0xFF)
  end
  return model
end

main()
