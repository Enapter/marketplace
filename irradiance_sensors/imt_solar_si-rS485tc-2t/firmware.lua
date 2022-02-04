-- RS485 communication interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    error("RS485 init error: "..rs485.err_to_str(result))
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = "IMT Solar", model = "Si-RS485TC-2T" })
end

function send_telemetry()
  local telemetry = {}
  local ADDRESS = 1

  local data, result = modbus.read_inputs(ADDRESS, 0, 1, 1000)
  if data then
    telemetry["solar_irrad"] = uint16(data) / 10
  elseif result ~= 0 then
    enapter.log("Modbus error: "..modbus.err_to_str(result))
  end

  local data, result = modbus.read_inputs(ADDRESS, 7, 1, 1000)
  if data then
    telemetry["module_temp"] = int16(data) / 10
  elseif result ~= 0 then
    enapter.log("Modbus error: "..modbus.err_to_str(result))
  end

  local data, result = modbus.read_inputs(ADDRESS, 8, 1, 1000)
  if data then
    telemetry["ambient_temp"] = int16(data) / 10
  elseif result ~= 0 then
    enapter.log("Modbus error: "..modbus.err_to_str(result))
  end

  if next(telemetry) == nil then
    telemetry.status = "modbus_error"
    telemetry.alerts = {"modbus_read_error"}
  else
    telemetry.status = "ok"
    telemetry.alerts = {}
  end

  enapter.send_telemetry(telemetry)
end

function uint16(register)
  local raw_str = string.pack("BB", register[1]&0xFF, register[1]>>8)
  return string.unpack("I2", raw_str)
end

function int16(register)
  local raw_str = string.pack("BB", register[1]&0xFF, register[1]>>8)
  return string.unpack("i2", raw_str)
end

main()
