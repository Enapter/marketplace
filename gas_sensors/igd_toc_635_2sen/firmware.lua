local config = require('enapter.ucm.config')
local qmodbus = require('enapter.ucm.qmodbus')

ADDRESS = 100
BAUD_RATE = 19200
DATA_BITS = 8
STOP_BITS = 1
PARITY = 'N'
SENSOR1_NUMBER_CONFIG = 'sensor1'
SENSOR2_NUMBER_CONFIG = 'sensor2'

rs485_initialised = true

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log('RS485 init failed: ' .. rs485.err_to_str(result))
    rs485_initialised = false
  end

  config.init({
    [SENSOR1_NUMBER_CONFIG] = { type = 'number', required = true },
    [SENSOR2_NUMBER_CONFIG] = { type = 'number', required = true },
  })

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'IGD', model = 'TOC 635' })
end

function send_telemetry()
  enapter.send_telemetry(build_telemetry())
end

function build_telemetry()
  if not rs485_initialised then
    return { status = 'error', alerts = { 'rs485_init_failed' } }
  end

  local sensor1_number, err = config.read(SENSOR1_NUMBER_CONFIG)
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return { status = 'error', alerts = { 'cannot_read_config' } }
  end

  local sensor2_number, err = config.read(SENSOR2_NUMBER_CONFIG)
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return { status = 'error', alerts = { 'cannot_read_config' } }
  end

  if not sensor1_number or not sensor2_number then
    return { status = 'error', alerts = { 'not_configured' } }
  end

  local telemetry = { status = 'ok', communication_status = 'ok' }
  read_telemetry(telemetry, 1, sensor1_number)
  read_telemetry(telemetry, 2, sensor2_number)

  return telemetry
end

function read_telemetry(telemetry, num, id)
  local qreads = {
    { type = 'inputs', addr = ADDRESS, reg = 30000 + id, count = 1, timeout = 1000 },
    { type = 'inputs', addr = ADDRESS, reg = 31000 + id, count = 1, timeout = 1000 },
    { type = 'inputs', addr = ADDRESS, reg = 33000 + id, count = 1, timeout = 1000 },
  }
  local results, err = qmodbus.read(qreads)

  if err then
    enapter.log('Error reading Modbus: ' .. err, 'error', true)
    return { status = 'error', communication_status = 'error', alerts = { 'communication_failed' } }
  end

  for i, result in ipairs(results) do
    if result.errmsg then
      enapter.log('Error reading Modbus register ' .. tostring(qreads[i].reg) .. ': ' .. result.errmsg, 'error', true)
      telemetry['communication_status'] = 'error'
      telemetry['alerts'] = { 'communication_failed' }
      break
    end
  end

  telemetry['sensor' .. tostring(num) .. '_h2_concentration'] = convert_value(results[1].data, 10, -10)
  telemetry['sensor' .. tostring(num) .. '_volts'] = convert_value(results[2].data, 100, 0)
  telemetry['sensor' .. tostring(num) .. '_status'] = uint16(results[3].data)

  return update_telemetry_base_on_sensor_status(telemetry, num)
end

function update_telemetry_base_on_sensor_status(telemetry, num)
  local sensor_status = telemetry['sensor' .. tostring(num) .. '_status']
  if sensor_status == nil then
    return telemetry
  end

  local alerts = telemetry['alerts']
  if not alerts then
    alerts = {}
  end

  if sensor_status & 0x0001 ~= 0 then
    table.insert(alerts, 'alarm_1')
  end
  if sensor_status & 0x0002 ~= 0 then
    table.insert(alerts, 'alarm_2')
  end
  if sensor_status & 0x0004 ~= 0 then
    table.insert(alerts, 'alarm_3')
  end
  if sensor_status & 0x0008 ~= 0 then
    table.insert(alerts, 'fault')
  end
  if sensor_status & 0x0010 ~= 0 then
    telemetry['status'] = 'disabled'
  end
  if sensor_status & 0x0020 ~= 0 then
    table.insert(alerts, 'sensor_fault')
  end
  if sensor_status & 0x0040 ~= 0 then
    table.insert(alerts, 'under_range_fault')
  end
  if sensor_status & 0x0080 ~= 0 then
    table.insert(alerts, 'over_range_fault')
  end
  if sensor_status & 0x0100 ~= 0 then
    table.insert(alerts, 'communication_fault')
  end

  telemetry['alerts'] = alerts
  return telemetry
end

function convert_value(data, fraction, offset)
  if data == nil or data[1] == nil then
    return nil
  end
  return data[1] / fraction + offset
end

function uint16(data)
  if data == nil or data[1] == nil then
    return nil
  end
  local raw_str = string.pack('BB', data[1] & 0xFF, data[1] >> 8)
  return string.unpack('I2', raw_str)
end

main()
