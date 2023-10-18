local config = require('enapter.ucm.config')

ADDRESS_CONFIG = 'address'
BAUDRATE_CONFIG = 'baudrate'
DATA_BITS_CONFIG = 'data_bits'
STOP_BITS_CONFIG = 'stop_bits'
PARITY_CONFIG = 'parity_bits'

function main()
  config.init({
    [ADDRESS_CONFIG] = { type = 'number', required = true, default = 1 },
    [BAUDRATE_CONFIG] = { type = 'number', required = true, default = 9600 },
    [DATA_BITS_CONFIG] = { type = 'number', required = true, default = 8 },
    [STOP_BITS_CONFIG] = { type = 'number', required = true, default = 1 },
    [PARITY_CONFIG] = { type = 'string', required = true, default = 'N' },
  })

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
  end

  local baudrate = values[BAUDRATE_CONFIG]
  local data_bits = values[DATA_BITS_CONFIG]
  local parity_bits = values[PARITY_CONFIG]
  local stop_bits = values[STOP_BITS_CONFIG]

  local result = rs485.init(baudrate, data_bits, parity_bits, stop_bits)
  if result ~= 0 then
    enapter.log('RS485 init failed: ' .. result .. ' ' .. rs485.err_to_str(result), 'error', true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'KOSTAL', model = 'INVEOR' })
end

function send_telemetry()
  local telemetry = {}
  local status = 'ok'

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
  end

  local address = values[ADDRESS_CONFIG]

  local data, result = modbus.read_inputs(address, 1999, 2, 1000) -- REAL
  if data then
    telemetry['actual_freq'] = tofloat(data)
  else
    enapter.log('Register 1999 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(address, 2001, 2, 1000) -- REAL
  if data then
    telemetry['output_volt'] = tofloat(data)
  else
    enapter.log('Register 2001 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(address, 2003, 2, 1000) -- REAL
  if data then
    telemetry['motor_curr'] = tofloat(data) * telemetry['volt_l1n']
  else
    enapter.log('Register 2003 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(address, 2009, 2, 1000) -- REAL
  if data then
    telemetry['target_freq'] = tofloat(data)
  else
    enapter.log('Register 2009 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(address, 2015, 2, 1000) -- REAL
  if data then
    telemetry['inner_temp'] = tofloat(data)
  else
    enapter.log('Register 2015 reading failed: ' .. modbus.err_to_str(result))
    status = 'read_error'
  end

  telemetry['status'] = status
  enapter.send_telemetry(telemetry)
end

function tofloat(register)
  local raw_str = string.pack('BBBB', register[1] >> 8, register[1] & 0xff, register[2] >> 8, register[2] & 0xff)
  return string.unpack('>f', raw_str)
end

main()
