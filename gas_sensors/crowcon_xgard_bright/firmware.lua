-- RS485 communication interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 2

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS485 init failed: "..rs485.err_to_str(result))
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = "Crowcon", model = "Xgard Bright" })
end

function send_telemetry()
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
