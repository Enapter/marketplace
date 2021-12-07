function main()
  local result = rs485.init(2400, 8, "N", 1)
  if result ~= 0 then
    enapter.log("RS485 init error: " .. rs485.err_to_str(result), error, true)
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, metrics)
end

function properties()
  enapter.send_properties({ vendor = "Kilowatt Labs", model = "Centauri Energy Server" })
end

function metrics()
  local ADDRESS = 1
  local telemetry = {}
  local status = "ok"

  local data, result = modbus.read_holdings(ADDRESS, 1, 2, 1000)
  if data then
    telemetry["ac_input_voltage"] = tofloat(data)
  else
    enapter.log("Register 1 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 2, 2, 1000)
  if data then
    telemetry["ac_output_voltage"] = tofloat(data)
  else
    enapter.log("Register 2 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 3, 2, 1000)
  if data then
    telemetry["ac_output_freq"] = tofloat(data) * 0.1
  else
    enapter.log("Register 3 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 4, 1, 1000)
  if data then
    telemetry["load_percentage"] = data
  else
    enapter.log("Register 4 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 5, 2, 1000)
  if data then
    telemetry["ambient_temp"] = tofloat(data)
  else
    enapter.log("Register 5 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 6, 2, 1000)
  if data then
    telemetry["pv_input_voltage"] = tofloat(data)
  else
    enapter.log("Register 6 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 7, 2, 1000)
  if data then
    telemetry["charge_current"] = tofloat(data) * 0.1
  else
    enapter.log("Register 7 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 8, 2, 1000)
  if data then
    telemetry["battery_voltage"] = tofloat(data) * 0.1
  else
    enapter.log("Register 8 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9, 1, 1000)
  if data then
    telemetry["battery_percentage"] = data
  else
    enapter.log("Register 9 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 10, 2, 1000)
  if data then
    telemetry["pv_power"] = tofloat(data)
  else
    enapter.log("Register 10 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 26, 2, 1000)
  if data then
    telemetry["rated_battery_voltage"] = tofloat(data)
  else
    enapter.log("Register 26 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 27, 2, 1000)
  if data then
    telemetry["rated_voltage"] = tofloat(data)
  else
    enapter.log("Register 27 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 28, 2, 1000)
  if data then
    telemetry["charge_current_grade"] = tofloat(data)
  else
    enapter.log("Register 28 reading failed: "..modbus.err_to_str(result))
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
