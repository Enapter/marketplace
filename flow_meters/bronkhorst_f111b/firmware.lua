VENDOR = "Bronkhorst"
MODEL = "F-111B"

MODBUS_ADDRESS = 1
BAUD_RATE = 19200
DATA_BITS = 8
PARITY = "E"
STOP_BITS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS485 init error: "..rs485.err_to_str(result))
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = VENDOR, model = MODEL })
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = 'ok'

  local registers = {
    measure = {
      name = 'measure',
      addr = 32,
      count = 2
    },
    fluid_name = {
      name = 'fluid_name',
      addr = 33160,
      count = 5
    },
    capacity_unit = {
      name = 'unit',
      addr = 33272,
      count = 4,
    }
  }

  for _, register in pairs(registers) do
    local data, err = modbus.read_holdings(MODBUS_ADDRESS, register.addr, register.count, 1000)
    if err ~= 0 then
      status = "modbus_error"
      enapter.log("Reading register "..register.count.." failed: "..modbus.err_to_str(err), 'error')
    elseif data then
      telemetry[register.name] = data
    end
  end

  if telemetry["measure"] then
    telemetry["measure"] = topercent(telemetry["measure"]) * 30 / 100
  end

  local names = {
    O = 'oxygen',
    H = 'hydrogen'
  }

  if telemetry["fluid_name"] then
    telemetry["fluid_name"] = names[string.match(tostr(telemetry["fluid_name"]), "%a+")]
  end

  if telemetry["unit"] then
    telemetry["unit"] = string.match(tostr(telemetry["unit"]), "%a+/%a+")
  end

  telemetry["status"] = status
  telemetry["alerts"] = alerts

  enapter.send_telemetry(telemetry)
end

function topercent(registers)
  local raw_str = string.pack("BBBB", registers[1] >> 8, registers[1] &0xFF, registers[2] >> 8,registers[2] &0xFF)
  return (string.unpack(">I2", raw_str) * 100) / 32000
end

function tostr(registers)
  local raw_str = string.pack("BBBBBBBB",
  registers[1] >> 8, registers[1] &0xFF,
  registers[2] >> 8, registers[2] &0xFF,
  registers[3] >> 8, registers[3] &0xFF,
  registers[4] >> 8, registers[4] &0xFF)
  return string.unpack(">c8", raw_str)
end

main()
