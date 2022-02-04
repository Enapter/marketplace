-- RS845 communication interface parameters
BAUD_RATE = 19200
DATA_BITS = 8
PARITY = 'E'
STOP_BITS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS485 init error: " .. rs485.err_to_str(result))
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = "CS Instruments", model = "FA 510" })
end

function send_telemetry()
  local ADDRESS = 1
  local telemetry = {}
  local status = "ok"

  local data, result = modbus.read_holdings(ADDRESS, 10, 2, 1000)
  if data then
    telemetry["calibration_due"] = todate(data)
  else
    enapter.log("Reading register 10 failed " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 1000, 2, 1000)
  if data then
    telemetry["temperature"] = tofloat(data)
  else
    enapter.log("Reading register 1000 failed " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 1006, 2, 1000)
  if data then
    telemetry["dew_point"] = tofloat(data)
  else
    enapter.log("Reading register 1006 failed: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 1020, 2, 1000)
  if data then
    telemetry["partial_vapor_pressure"] = tofloat(data)/1000 -- from hPa to bar
  else
    enapter.log("Reading register 1020 failed: " .. modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 1022, 2, 1000)
  if data then
    telemetry["atm_dew_point"] = tofloat(data)

    local gas_status = tofloat(data) < -60.5
    telemetry["gas_acceptable"] = gas_status

    if gas_status then
      telemetry["status"] = "ok"
    else
      telemetry["status"] = "warning"
    end
  else
    enapter.log("Reading register 1022 failed: " .. modbus.err_to_str(result))
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
