function main()
  local result = rs485.init(2400, 8, "N", 1)
  if result ~= 0 then
    enapter.log("RS-485 failed: "..result.." "..rs485.err_to_str(result), "error", true)
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, metrics)
end

function properties()
  enapter.send_properties({vendor = "Eastron", model = "SDM120CT"})
end

function metrics()
  local ADDRESS = 1
  local telemetry = {}
  local status = "ok"

  local data, result = modbus.read_inputs(ADDRESS, 70, 2, 1000)
  if data then
    telemetry["freq"] = tofloat(data)
  else
    enapter.log("Register 70 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 0, 2, 1000)
  if data then
    telemetry["volt_l1n"] = tofloat(data)
  else
    enapter.log("Register 0 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 6, 2, 1000)
  if data then
    telemetry["power_l1"] = tofloat(data) * telemetry["volt_l1n"]
  else
    enapter.log("Register 6 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_inputs(ADDRESS, 342, 2, 1000)
  if data then
    telemetry["acc_power_l1"] = tofloat(data)
  else
    enapter.log("Register 342 reading failed: "..modbus.err_to_str(result))
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
