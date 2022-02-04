-- RS485 communication interface parameters
BAUD_RATE = 38400
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 2

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS485 init error: " .. rs485.err_to_str(result))
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = "Crowcon", model = "XgardIQ" })
end

function send_telemetry()
  local ADDRESS = 1
  local telemetry = {}
  local status = "ok"

  local data, result = modbus.read_holdings(ADDRESS, 99, 1, 1000)
  if data then
    if data[1] == 0 then
      telemetry["sensor_ready"] = "undetected"
    elseif data[1] == 1 then
      telemetry["sensor_ready"] = "invalid"
    elseif data[1] == 2 then
      telemetry["sensor_ready"] = "initializing"
    elseif data[1] == 3 then
      telemetry["sensor_ready"] = "ready"
    end
  else
    enapter.log("Modbus register 99 error: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 106, 2, 1000)
  if data then
    telemetry["calibration_due"] = todate(data)
  else
    enapter.log("Modbus register 106 error: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 111, 2, 1000)
  if data then
    telemetry["last_calibration"] = todate(data)
  else
    enapter.log("Modbus register 111 error: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 301, 2, 1000)
  if data then
    telemetry["h2_concentration"] = tofloat(data)
  else
    enapter.log("Modbus register 301 error: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 303, 1, 1000)
  if data then
    if data[1] == 0 then
      telemetry["status"] = "ok"
    elseif data[1] == 1 then
      telemetry["status"] = "reminder"
    elseif data[1] == 2 then
      telemetry["status"] = "warning"
    elseif data[1] == 3 then
      telemetry["status"] = "fault"
    end
  else
    enapter.log("Modbus register 303 error: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 304, 1, 1000)
  if data then
    if data[1] == 0 then
      telemetry["alarm1"] = false
    else
      telemetry["alarm1"] = true
    end
  else
    enapter.log("Modbus register 304 error: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 305, 1, 1000)
  if data then
    if data[1] == 0 then
      telemetry["alarm2"] = false
    else
      telemetry["alarm2"] = true
    end
  else
    enapter.log("Modbus register 305 error: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  telemetry["status"] = status
  enapter.send_telemetry(telemetry)
end

function tofloat(register)
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">f", raw_str)
end

function todate(register)
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">I4", raw_str)
end

main()
