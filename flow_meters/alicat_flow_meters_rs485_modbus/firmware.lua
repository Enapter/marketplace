local config = require('enapter.ucm.config')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
ADDRESS = 'address'
BAUDRATE = 'baudrate'
STOP_BITS = 'stop_bits'
PARITY = 'parity'

function main()
  config.init({
    [BAUDRATE] = { type = 'number', required = true, default = 19200 },
    [STOP_BITS] = { type = 'number', required = true, default = 1 },
    [PARITY] = { type = 'string', required = true, default = 'N' },
    [ADDRESS] = { type = 'number', required = true, default = 1 },
  })
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({
    vendor = 'Alicat Scientific',
  })
end

function send_telemetry()
  local values, err = config.read_all()
  if err ~= nil then
    enapter.send_telemetry({
      status = 'warning',
      alerts = { 'config_read_error' },
    })
    return
  end

  local result = rs485.init(values[BAUDRATE], 8, values[PARITY], values[STOP_BITS])
  if result ~= 0 then
    enapter.log('RS485 init failed: ' .. result .. ' ' .. rs485.err_to_str(result), 'error', true)
    enapter.send_telemetry({
      status = 'warning',
      alerts = { 'rs485_error' },
    })
    return
  end

  local address = values[ADDRESS]
  local telemetry = {}
  local status = 'ok'

  local data, result = modbus.read_inputs(address, 1208, 2, 1000)
  if data then
    telemetry['mass_flow'] = tofloat(data)
  else
    enapter.log('Register 1209 reading failed: ' .. modbus.err_to_str(result), 'error')
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(address, 1206, 2, 1000)
  if data then
    telemetry['volumetric_flow'] = tofloat(data)
  else
    enapter.log('Register 1207 reading failed: ' .. modbus.err_to_str(result), 'error')
    status = 'read_error'
  end

  local data, result = modbus.read_inputs(address, 1204, 2, 1000)
  if data then
    telemetry['flow_temp'] = tofloat(data)
  else
    enapter.log('Register 1205 reading failed: ' .. modbus.err_to_str(result), 'error')
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
