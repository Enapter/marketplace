-- RS485 serial interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1

-- Default Modbus address of Sfere module
MODBUS_ADDRESS = 254

-- Initiate device firmware. Called at the end of the file.
function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log('RS485 init error: ' .. modbus.err_to_str(result), 'error', true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Sfere', model = 'uCv 4001' })
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local read_error = false
  local status = 'ok'

  local ok, err = pcall(function()
    local data1, result1 = modbus.read_holdings(MODBUS_ADDRESS, 2, 1, 1000)
    local data2, result2 = modbus.read_holdings(MODBUS_ADDRESS, 3, 1, 1000)
    if data1 and data2 then
      telemetry['o2_concentration'] = point_unit_decode(data1, data2)
    else
      enapter.log('Reading register 2: ' .. modbus.err_to_str(result1), 'error')
      enapter.log('Reading register 3: ' .. modbus.err_to_str(result2), 'error')
      read_error = true
    end
  end)
  if not ok then
    enapter.log('o2_concentration calculation failed: ' .. err, 'error')
  end

  local data, result = modbus.read_holdings(MODBUS_ADDRESS, 51, 1, 1000)
  if data then
    if data[1] & 2 ^ 9 ~= 0 then
      table.insert(alerts, 'measure_overload')
    end
    if data[1] & 2 ^ 8 ~= 0 then
      table.insert(alerts, 'sensor_break')
    end
    if data[1] & 2 ^ 6 ~= 0 then
      table.insert(alerts, 'measure_overrange')
    end
    if data[1] & 2 ^ 5 ~= 0 then
      table.insert(alerts, 'cjc_error')
    end
    if data[1] & 2 ^ 2 ~= 0 then
      table.insert(alerts, 'calibration_error')
    end
    if data[1] & 2 ^ 1 ~= 0 then
      table.insert(alerts, 'offset_error')
    end
    if data[1] & 2 ^ 0 ~= 0 then
      table.insert(alerts, 'programming_error')
    end
  else
    enapter.log('Register 51 reading: ' .. modbus.err_to_str(result))
    read_error = true
  end

  local gas_acceptable
  local ok, err = pcall(function()
    local data1, result1 = modbus.read_holdings(MODBUS_ADDRESS, 100, 1, 1000)
    local data2, result2 = modbus.read_holdings(MODBUS_ADDRESS, 101, 1, 1000)
    if data1 and data2 then
      local relay1, relay2 = relay_check(data1)
      local relay3, relay4 = relay_check(data2)

      if relay1 or relay2 or relay3 or relay4 then
        gas_acceptable = false
        telemetry['gas_acceptable'] = false
      else
        gas_acceptable = true
        telemetry['gas_acceptable'] = true
      end

      telemetry['relay1'] = relay1
      telemetry['relay2'] = relay2
      telemetry['relay3'] = relay3
      telemetry['relay4'] = relay4
    else
      enapter.log('register 100 reading: ' .. modbus.err_to_str(result1))
      enapter.log('register 101 reading: ' .. modbus.err_to_str(result2))
    end
  end)
  if not ok then
    enapter.log('Registers 100 and/or 101 reading failed: ' .. err, 'error')
    read_error = true
  end

  if #alerts > 0 then
    status = 'error'
  elseif gas_acceptable == false then
    status = 'warning'
    table.insert(alerts, 'gas_not_acceptable')
  end

  if read_error then
    status = 'read_error'
    table.insert(alerts, 'communication_failed')
  end

  telemetry['alerts'] = alerts
  telemetry['status'] = status
  enapter.send_telemetry(telemetry)
end

function point_unit_decode(register1, register2)
  local raw_str = string.pack('BB', register2[1] >> 8, register2[1] & 0xff)

  local point = string.unpack('>I1', string.sub(raw_str, 1, 1))
  point = math.floor(point / 16)

  return register1[1] / 10 ^ point
end

function relay_check(register)
  local relay1, relay2

  relay1 = (register[1] & 2 ^ 2 ~= 0)
  relay2 = (register[1] & 2 ^ 10 ~= 0)

  return relay1, relay2
end

main()
