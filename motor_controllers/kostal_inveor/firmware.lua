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

  local result = rs485.init(BAUDRATE_CONFIG, DATA_BITS_CONFIG, PARITY_CONFIG, STOP_BITS_CONFIG)
    if result ~= 0 then
      enapter.log('RS-485 failed: ' .. result .. ' ' .. rs485.err_to_str(result), 'error', true)
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

main()
