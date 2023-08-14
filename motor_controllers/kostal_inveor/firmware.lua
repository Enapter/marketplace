-- RS485 communication interface parameters
-- BAUD_RATE = 9600
-- DATA_BITS = 8
-- PARITY = 'N'
-- STOP_BITS = 1

function main()
--  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
--  if result ~= 0 then
--    enapter.log('RS-485 failed: ' .. result .. ' ' .. rs485.err_to_str(result), 'error', true)
--  end

  local inveor, err = connect_inveor()
  if not inveor then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'communication_error', alerts = { 'cannot_read_config' } })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    end
    return
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [ADDRESS_CONFIG] = { type = 'number', required = true, default = 1 },
    [BAUDRATE_CONFIG] = { type = 'number', required = true, default = 9600 },
    [DATA_BITS_CONFIG] = { type = 'number', required = true, default = 8 },
    [STOP_BITS_CONFIG] = { type = 'number', required = true, default = 1 },
    [PARITY_CONFIG] = { type = 'string', required = true, default = 'N' },
  })
end

function send_properties()
  enapter.send_properties({ vendor = 'KOSTAL', model = 'INVEOR' })
end

function send_telemetry()
--  local ADDRESS = 1
  local telemetry = {}
  local status = 'ok'

  local data, result = modbus.read_inputs(ADDRESS_CONFIG, 999, 1, 1000)
  if data then
    telemetry['actual_freq'] = tofloat(data)
  else
    enapter.log('Register 999 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(ADDRESS_CONFIG, 1000, 1, 1000)
  if data then
    telemetry['output_volt'] = tofloat(data)
  else
    enapter.log('Register 1000 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(ADDRESS_CONFIG, 1001, 1, 1000)
  if data then
    telemetry['motor_curr'] = tofloat(data) * telemetry['volt_l1n']
  else
    enapter.log('Register 1001 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(ADDRESS_CONFIG, 1007, 1, 1000)
  if data then
    telemetry['igbt_temp'] = tofloat(data)
  else
    enapter.log('Register 1007 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(ADDRESS_CONFIG, 1004, 1, 1000)
  if data then
    telemetry['target_freq'] = tofloat(data)
  else
    enapter.log('Register 1004 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(ADDRESS_CONFIG, 1002, 1, 1000)
  if data then
    telemetry['inner_temp'] = tofloat(data)
  else
    enapter.log('Register 1002 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  telemetry['status'] = status
  enapter.send_telemetry(telemetry)
end

function tofloat(register)
  local raw_str =
    string.pack('BBBB', register[1] >> 8, register[1] & 0xff, register[2] >> 8, register[2] & 0xff)
  return string.unpack('>f', raw_str)
end

function connect_inveor()
  if inveor then
    return inveor, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    for _, value in pairs(values) do
      if not value then
        return nil, 'not_configured'
      end
    end

    inveor = inveor_modbus.new(
      tonumber(values[ADDRESS_CONFIG]),
      tonumber(values[BAUDRATE_CONFIG]),
      tonumber(values[DATA_BITS_CONFIG]),
      values[PARITY_CONFIG],
      tonumber(values[STOP_BITS_CONFIG])
    )

    -- Declare global variable to reuse connection between function calls
    inveor:connect()
    return inveor, nil
  end
end

main()
