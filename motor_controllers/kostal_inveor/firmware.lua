-- RS485 communication interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS-485 failed: "..result.." "..rs485.err_to_str(result), "error", true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({vendor = "KOSTAL", model = "INVEOR"})
end

function send_telemetry()
  local ADDRESS = 1
  local telemetry = {}
  local status = "ok"

  local data, result = modbus.read_inputs(ADDRESS, 999, 1, 1000)
  if data then
    telemetry["actual_freq"] = tofloat(data)
  else
    enapter.log("Register 999 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 1000, 1, 1000)
  if data then
    telemetry["output_volt"] = tofloat(data)
  else
    enapter.log("Register 1000 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 1001, 1, 1000)
  if data then
    telemetry["motor_curr"] = tofloat(data) * telemetry["volt_l1n"]
  else
    enapter.log("Register 1001 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 1007, 1, 1000)
  if data then
    telemetry["igbt_temp"] = tofloat(data)
  else
    enapter.log("Register 1007 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 1004, 1, 1000)
  if data then
    telemetry["target_freq"] = tofloat(data)
  else
    enapter.log("Register 1004 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 1002, 1, 1000)
  if data then
    telemetry["inner_temp"] = tofloat(data)
  else
    enapter.log("Register 1002 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  telemetry["status"] = status
  enapter.send_telemetry(telemetry)
end

function tofloat(register)
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">f", raw_str)
end

main()
