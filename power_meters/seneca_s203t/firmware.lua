ADDRESS = 1

result = rs485.init(38400, 8, "N", 1)
if result ~= 0 then
  enapter.log("RS485 init error: " .. rs485.err_to_str(result), error, true)
end

function tofloat(register)
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">f", raw_str)
end

function to2int16(float)
  local raw_str = string.pack(">f", float)
  local b3, b2, b1, b0 = string.unpack("BBBB", raw_str)
  local raw_str1 = string.pack("BB", b3, b2)
  local raw_str2 = string.pack("BB", b1, b0)
  local MSW = string.unpack(">I2", raw_str1)
  local LSW = string.unpack(">I2", raw_str2)
  return MSW, LSW
end

function properties()
  enapter.send_properties({ vendor = "Seneca", model = "S203T" })
end

function write_config()
  local RATIO_MSW, RATIO_LSW = to2int16(1000)
  local MIN_CURR_IN_MSW,  MIN_CURR_IN_LSW = 0, 0
  local MAX_CURR_IN_MSW, MAX_CURR_IN_LSW = to2int16(600)

  -- Set RATIOs and current limits every 10 s to make it robust to reboot
  modbus.write_multiple_holdings(ADDRESS, 25, {RATIO_MSW}, 1000) --40026
  modbus.write_multiple_holdings(ADDRESS, 26, {RATIO_LSW}, 1000) --40027
  modbus.write_multiple_holdings(ADDRESS, 27, {MIN_CURR_IN_MSW}, 1000) --40028
  modbus.write_multiple_holdings(ADDRESS, 28, {MIN_CURR_IN_LSW}, 1000) --40029
  modbus.write_multiple_holdings(ADDRESS, 29, {MAX_CURR_IN_MSW}, 1000) --40030
  modbus.write_multiple_holdings(ADDRESS, 30, {MAX_CURR_IN_LSW}, 1000) --40031
end

function metrics()
  local telemetry = {}
  local status = "ok"

  local data, result = modbus.read_holdings(ADDRESS, 134, 2, 1000) --40135
  if data then
    telemetry["volt_l1n"] = tofloat(data)
  else
    enapter.log("Register 134 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 142, 2, 1000) --40143
  if data then
    telemetry["current_l1"] =  tofloat(data) / 1000.0
  else
    enapter.log("Register 142 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 150, 2, 1000) --40151
  if data then
    telemetry["active_power_l1"] = tofloat(data)
  else
    enapter.log("Register 150 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 158, 2, 1000) --40159
  if data then
    telemetry["reactive_power_l1"] = tofloat(data)
  else
    enapter.log("Register 158 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 166, 2, 1000) --40167
  if data then
    telemetry["apparent_power_l1"] = tofloat(data)
  else
    enapter.log("Register 166 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 174, 2, 1000) --40175
  if data then
    telemetry["cos_phi_l1"] = tofloat(data)
  else
    enapter.log("Register 174 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  local data, result = modbus.read_holdings(ADDRESS, 182, 2, 1000) --40183
  if data then
    telemetry["freq"] = tofloat(data)
  else
    enapter.log("Register 182 reading failed: "..modbus.err_to_str(result))
    status = "read_error"
  end

  telemetry["status"] = status
  enapter.send_telemetry(telemetry)
end

scheduler.add(30000, properties)
scheduler.add(10000, write_config)
scheduler.add(1000, metrics)
