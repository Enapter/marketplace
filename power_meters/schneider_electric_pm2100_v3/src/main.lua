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
  local SEE_LOGS_MSG = 'failed to get data. See device logs.'

  local results, err = fetch_phase_metrics(conn)
  if err then
    alert_error_msg = 'error fetching phase metrics: ' .. err
    enapter.log(alert_error_msg, 'error', true)
  else
    if not parse_phase_metrics(telemetry, results) then
      alert_error_msg = SEE_LOGS_MSG
    end
  end

  results, err = fetch_other_metrics(conn)
  if err then
    alert_error_msg = 'error fetching other metrics: ' .. err
    enapter.log(alert_error_msg, 'error', true)
  else
    if not parse_other_metrics(telemetry, results) then
      alert_error_msg = SEE_LOGS_MSG
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
  return read_data(client, queries)
end

function parse_phase_metrics(telemetry, results)
  local is_err = false
  if is_result_ok(results, 1) then
    local data = results[1]
    extract_data_float(telemetry, data, 1, 'ac_l1_current')
    extract_data_float(telemetry, data, 3, 'ac_l2_current')
    extract_data_float(telemetry, data, 5, 'ac_l3_current')
  else
    enapter.log('failed to get phase current', 'error', true)
    is_err = true
  end
  if is_result_ok(results, 2) then
    local data = results[2]
    extract_data_float(telemetry, data, 1, 'ac_l1_voltage')
    extract_data_float(telemetry, data, 3, 'ac_l2_voltage')
    extract_data_float(telemetry, data, 5, 'ac_l3_voltage')
  else
    enapter.log('failed to get phase voltage', 'error', true)
    is_err = true
  end
  if is_result_ok(results, 3) then
    local data = results[3]
    extract_data_float(telemetry, data, 1, 'ac_l1_power')
    extract_data_float(telemetry, data, 3, 'ac_l2_power')
    extract_data_float(telemetry, data, 5, 'ac_l3_power')
  else
    enapter.log('failed to get phase power', 'error', true)
    is_err = true
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
  return read_data(client, queries)
end

function parse_other_metrics(telemetry, results)
  local is_err = false
  if is_result_ok(results, 1) then
    local data = results[1]
    extract_data_float(telemetry, data, 1, 'energy_total')
  else
    enapter.log('failed to get energy_total', 'error', true)
    is_err = true
  end
  if is_result_ok(results, 2) then
    local data = results[2]
    extract_data_float(telemetry, data, 1, 'active_energy_delivered_and_received')
  else
    enapter.log('failed to get active_energy_delivered_and_received', 'error', true)
    is_err = true
  end
  if is_result_ok(results, 3) then
    local data = results[3]
    extract_data_float(telemetry, data, 1, 'total_power')
  else
    enapter.log('failed to get total_power', 'error', true)
    is_err = true
  end
  if is_result_ok(results, 4) then
    local data = results[4]
    extract_data_float(telemetry, data, 1, 'ac_frequency')
  else
    enapter.log('failed to get ac_frequency', 'error', true)
    is_err = true
  end
  return is_err
end

function read_data(client, queries)
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

function is_result_ok(results, num)
  local res = results[num]
  if res.errmsg ~= nil then
    enapter.log('error reading query ' .. num .. ': ' .. res.errmsg, 'error', true)
    return false
  end

  if res.data == nil then
    enapter.log('error reading query ' .. num .. ': data is missing')
    return false
  end
  return true
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
