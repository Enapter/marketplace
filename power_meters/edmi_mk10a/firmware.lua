-- Serial communication parameters
BAUDRATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1
ADDRESS = 1 -- default is the 2 last digits of serial number

function main()
  local result = rs232.init(BAUDRATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS232 failed: "..result.." "..rs232.err_to_str(result), "error", true)
    enapter.send_telemetry({status = "error", alerts = {"init_error"}})
    return
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({
    vendor = "EDMI",
    model = "Mk10A",
    serial_number = 214670933
  })
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = "ok"
  local modbus_error = false

  local data, result = modbus.read_holdings(ADDRESS, 9001, 6, 1000)
  if data then
    telemetry["voltage_a"] = tofloat(slice(data, 1, 2))
    telemetry["voltage_b"] = tofloat(slice(data, 3, 4))
    telemetry["voltage_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Phase voltages reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9007, 6, 1000)
  if data then
    telemetry["current_a"] = tofloat(slice(data, 1, 2))
    telemetry["current_b"] = tofloat(slice(data, 3, 4))
    telemetry["current_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Phase currents reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9013, 6, 1000)
  if data then
    telemetry["phase_angle_a"] = tofloat(slice(data, 1, 2))
    telemetry["phase_angle_b"] = tofloat(slice(data, 3, 4))
    telemetry["phase_angle_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Phase angles reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9019, 6, 1000)
  if data then
    telemetry["power_a"] = tofloat(slice(data, 1, 2))
    telemetry["power_b"] = tofloat(slice(data, 3, 4))
    telemetry["power_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Phase powers reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9025, 6, 1000)
  if data then
    telemetry["react_power_a"] = tofloat(slice(data, 1, 2))
    telemetry["react_power_b"] = tofloat(slice(data, 3, 4))
    telemetry["react_power_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Reactive powers reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9031, 6, 1000)
  if data then
    telemetry["app_power_a"] = tofloat(slice(data, 1, 2))
    telemetry["app_power_b"] = tofloat(slice(data, 3, 4))
    telemetry["app_power_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Apparent powers reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9037, 2, 1000)
  if data then
    telemetry["frequency"] = tofloat(data)
  else
    enapter.log("Frequency reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9039, 4, 1000)
  if data then
    telemetry["angle_between_ab"] = tofloat(slice(data, 1, 2))
    telemetry["angle_between_ac"] = tofloat(slice(data, 3, 4))
  else
    enapter.log("Angles between phases reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9043, 2, 1000)
  if data then
    telemetry["power_factor"] = tofloat(data)
  else
    enapter.log("Power factor reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9045, 4, 1000)
  if data then
    telemetry["date"] = toint32(slice(data, 1, 2))
    telemetry["time"] = toint32(slice(data, 3, 4))
  else
    enapter.log("Date and time reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9049, 8, 1000)
  if data then
    telemetry["tou_delivered_wh"] = tofloat(slice(data, 1, 2))
    telemetry["tou_delivered_varh"] = tofloat(slice(data, 3, 4))
    telemetry["tou_received_wh"] = tofloat(slice(data, 5, 6))
    telemetry["tou_received_varh"] = tofloat(slice(data, 7, 8))
  else
    enapter.log("TOU reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9057, 8, 1000)
  if data then
    telemetry["total_power"] = tofloat(slice(data, 1, 2))
    telemetry["total_react_power"] = tofloat(slice(data, 3, 4))
    telemetry["total_app_power"] = tofloat(slice(data, 5, 6))
    telemetry["total_current"] = tofloat(slice(data, 7, 8))
  else
    enapter.log("Total metrics reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9065, 6, 1000)
  if data then
    telemetry["voltage_ab"] = tofloat(slice(data, 1, 2))
    telemetry["voltage_bc"] = tofloat(slice(data, 3, 4))
    telemetry["voltage_ca"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Line-to-line voltages reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9071, 6, 1000)
  if data then
    telemetry["thd_a"] = tofloat(slice(data, 1, 2))
    telemetry["thd_b"] = tofloat(slice(data, 3, 4))
    telemetry["thd_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("THDs reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9077, 6, 1000)
  if data then
    telemetry["current_thd_a"] = tofloat(slice(data, 1, 2))
    telemetry["current_thd_b"] = tofloat(slice(data, 3, 4))
    telemetry["current_thd_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Current THDs reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  local data, result = modbus.read_holdings(ADDRESS, 9083, 6, 1000)
  if data then
    telemetry["power_factor_a"] = tofloat(slice(data, 1, 2))
    telemetry["power_factor_b"] = tofloat(slice(data, 3, 4))
    telemetry["power_factor_c"] = tofloat(slice(data, 5, 6))
  else
    enapter.log("Power factors reading failed: "..modbus.err_to_str(result), "error")
    modbus_error = true
  end

  if modbus_error then
    alerts = {"communication_failed"}
    status = "read_error"
  end

  telemetry["alerts"] = alerts
  telemetry["status"] = status

  enapter.send_telemetry(telemetry)
end

function slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

function tofloat(registers)
  local raw_str
  local ok, err = pcall(function()
    raw_str = string.pack("BBBB", registers[1]>>8, registers[1]&0xff, registers[2]>>8, registers[2]&0xff)
  end)
  if not ok then
    enapter.log("Converting of registers to float value failed: "..err)
    return nil
  end
  return string.unpack(">f", raw_str)
end

function toint32(registers)
  local raw_str
  local ok, err = pcall(function()
    raw_str = string.pack("BBBB", registers[1]>>8, registers[1]&0xff, registers[2]>>8, registers[2]&0xff)
  end)
  if not ok then
    enapter.log("Converting of registers to float value failed: "..err)
    return nil
  end
  return string.unpack(">I2", raw_str)
end

main()
