local BAUDRATE = 9600
local DATA_BITS = 8
local PARITY = 'N'
local STOP_BITS = 1
local ADDRESS = 1

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

  local data, result = modbus.read_holdings(ADDRESS, 9001, 6, 1000)
  if data then
    telemetry["voltage_a"] = tofloat(data[1], data[2])
    telemetry["voltage_b"] = tofloat(data[3], data[4])
    telemetry["voltage_c"] = tofloat(data[5], data[6])
  else
    enapter.log("Registers 9001-9006 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9007, 6, 1000)
  if data then
    telemetry["current_a"] = tofloat(data[1], data[2])
    telemetry["current_b"] = tofloat(data[3], data[4])
    telemetry["current_c"] = tofloat(data[5], data[6])
  else
    enapter.log("Registers 9007-9012 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9019, 6, 1000)
  if data then
    telemetry["power_a"] = tofloat(data[1], data[2])
    telemetry["power_b"] = tofloat(data[3], data[4])
    telemetry["power_c"] = tofloat(data[5], data[6])
  else
    enapter.log("Registers 9019-9024 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9037, 2, 1000)
  if data then
    telemetry["frequency"] = tofloat(data[1], data[2])
  else
    enapter.log("Registers 9037-9038 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9043, 2, 1000)
  if data then
    telemetry["power_factor"] = tofloat(data[1], data[2])
  else
    enapter.log("Registers 9043-9044 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9049, 2, 1000)
  if data then
    telemetry["tou_delivered"] = tofloat(data[1], data[2])
  else
    enapter.log("Registers 9049-9050 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9053, 2, 1000)
  if data then
    telemetry["tou_received"] = tofloat(data[1], data[2])
  else
    enapter.log("Registers 9053-9054 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9057, 2, 1000)
  if data then
    telemetry["total_power"] = tofloat(data[1], data[2])
  else
    enapter.log("Registers 9057-9058 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 9063, 2, 1000)
  if data then
    telemetry["total_current"] = tofloat(data[1], data[2])
  else
    enapter.log("Registers 9063-9064 reading failed: "..modbus.err_to_str(result), "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  telemetry["alerts"] = alerts
  telemetry["status"] = status

  enapter.send_telemetry(telemetry)
end

function tofloat(register1, register2)
  local ok, err = pcall(function()
    local raw_str = string.pack("BBBB", register1>>8, register1&0xff, register2>>8, register2&0xff)
    return string.unpack(">f", raw_str)
  end)
  if not ok then
    enapter.log("Converting of registers to float value failed: "..err)
  end
end

main()
