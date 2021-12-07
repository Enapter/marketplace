function main()
  local result = rs485.init(9600, 8, 'N', 2)
  if result ~= 0 then
    enapter.log("RS485 init failed: "..rs485.err_to_str(result))
  end

  scheduler.add(10000, properties)
  scheduler.add(1000, metrics)
end

function properties()
  enapter.send_properties({ vendor = "Crowcon", model = "Xgard Bright" })
end

function metrics()
  local ADDRESS = 1
  local telemetry = {}
  local alerts = {}
  local status = "ok"

  local data, result = modbus.read_holdings(ADDRESS, 1000, 2, 1000)
  if data then
    telemetry["h2_concentration"] = tofloat(data)
  else
    enapter.log("Error reading Modbus: "..modbus.err_to_str(result), "error", true)
    status = "read_error"
    alerts = "communication_failed"
  end

  telemetry["alerts"] = alerts
  telemetry["status"] = status

  enapter.send_telemetry(telemetry)
end

function tofloat(register)
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">f", raw_str)
end

main()
