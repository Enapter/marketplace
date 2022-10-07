-- Default values of serial communication parameters
BAUD_RATE = 19200
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1
MODBUS_ADDRESS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS485 failed: "..result.." "..rs485.err_to_str(result), "error", true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({
    vendor = "Alicat Scientific",
    model = "M-10SLPM-D-485"})
end

function send_telemetry()
  local telemetry = {}
  local status = "ok"

  local data, result = modbus.read_inputs(MODBUS_ADDRESS, 1208, 2, 1000)
  if data then
    telemetry["mass_flow"] = tofloat(data)
  else
    enapter.log("Register 1209 reading failed: "..modbus.err_to_str(result), 'error')
    status = "read_error"
  end

  local data, result = modbus.read_inputs(MODBUS_ADDRESS, 1206, 2, 1000)
  if data then
    telemetry["volumetric_flow"] = tofloat(data)
  else
    enapter.log("Register 1207 reading failed: "..modbus.err_to_str(result), 'error')
    status = "read_error"
  end

  local data, result = modbus.read_inputs(MODBUS_ADDRESS, 1204, 2, 1000)
  if data then
    telemetry["flow_temp"] = tofloat(data)
  else
    enapter.log("Register 1205 reading failed: "..modbus.err_to_str(result), 'error')
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
