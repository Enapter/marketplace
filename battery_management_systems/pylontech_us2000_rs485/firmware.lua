local config = require('enapter.ucm.config')

BAUDRATE_CONFIG = 'baudrate'
CELLS_CONFIG = 'cells'
GROUP_CONFIG = 'group'

local BAUDRATE, CELL_COUNT, GROUP_COUNT
local DATA_BITS, PARITY, STOP_BITS = 8, 'N', 1

function main()
  config.init({
    [BAUDRATE_CONFIG] = { type = 'number', required = true, default = 115200 },
    [CELLS_CONFIG] = { type = 'number', required = true, default = 8 },
    [GROUP_CONFIG] = { type = 'number', required = true, default = 0 },
  })

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    BAUDRATE = values[BAUDRATE_CONFIG]
  end

  local result = rs485.init(BAUDRATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS485 init failed: "..rs485.err_to_str(result))
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, telemetry)
end

function properties()
  enapter.send_properties({
    vendor = "Pylontech",
    baudrate = BAUDRATE
  })
end

function telemetry()
  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    CELL_COUNT = values[CELLS_CONFIG]
  end

  local telemetry = {}
  for cell = 0, CELL_COUNT do
    merge_tables(telemetry, get_analog_value(cell))
  end

  enapter.send_telemetry(telemetry)
end

function get_analog_value(addr)
  local message = make_message(addr, 0x42, 2)

  rs485.send(message)

  local data, res = rs485.receive(2000)

  if not data then
    enapter.log("RS485 receiving failed: "..rs485.err_to_str(res))
    return nil
  end

  local binary_data = fromhex(data:sub(14, -6))

  local data = {}
  CELL_COUNT = binary_data:byte(3)
  GROUP_COUNT = binary_data:byte(CELL_COUNT * 2 + 4)
  local data_pos = CELL_COUNT * 2 + GROUP_COUNT * 2 + 9

  data['total_current_'..addr] = get_int2_complement(binary_data:sub(data_pos, data_pos + 1)) / 100.0

  data_pos = data_pos + 2
  data['total_voltage'..addr] = get_int2(binary_data:sub(data_pos, data_pos + 1)) / 100.0

  data['total_power_'..addr] = data['total_voltage'..addr] * data['total_current_'..addr]

  data_pos = data_pos + 2
  data['remaining_capacity_'..addr] = get_int2(binary_data:sub(data_pos, data_pos + 1)) / 100.0

  data_pos = data_pos + 2
  data['total_capacity_'..addr] = get_int2(binary_data:sub(data_pos, data_pos + 1)) / 100.0

  data['battery_level_'..addr] = data['remaining_capacity_'..addr] / data['total_capacity_'..addr]

  -- data_pos = data_pos + 2
  -- data['cycles_'..addr] = get_int2(binary_data:sub(data_pos, data_pos + 1))

  return data
end

function make_message(addr, cid2, command)
  local SOI = "\x7E" -- ~
  local VER = "\x20"
  local EOI = "\x0D" -- carriage return
  local len = 0

  if command then
    len = 2
  end

  local message = VER .. string.char(addr) .. "\x4A" .. string.char(cid2) .. get_length(len)
  if command then
    message = message .. string.char(command)
  end

  local payload = to_ascii(message)
  payload = SOI .. payload .. get_checksum(payload) .. EOI
  return payload
end

function fromhex(str)
  return (str:gsub('..', function(cc)
    return string.char(tonumber(cc, 16))
  end))
end

function get_int2(data)
  local val = data:byte(1) << 8 | data:byte(2)
  return val
end

function get_int2_complement(data)
  local val = data:byte(1) << 8 | data:byte(2)
  if (val & 0x8000) == 0x8000 then
    val = val - 0x10000
  end
  return val
end

function to_ascii(message)
  local hex = ""
  for i = 1, #message do
    local ord = message:byte(i)
    hex = hex .. string.format("%02X", ord)
  end
  return hex
end

function get_checksum(message)
  local sum = 0
  for i = 1, #message do
    sum = sum + message:byte(i)
  end
  sum = sum % 65536
  sum = ~sum
  sum = sum + 1

  return to_ascii(string.pack(">i2", sum))
end

function get_length(value)
  if value > 0xfff or value < 0 then
    error("Invalid length")
  end

  local sum = (value & 0x000F) + ((value >> 4) & 0x000F) + ((value >> 8) & 0x000F)
  sum = sum % 16
  sum = ~sum;
  sum = sum + 1
  local val = (sum << 12) + value

  return string.pack(">i2", val)
end

function merge_tables(t1, t2)
    for key, value in pairs(t2) do
        t1[key] = value
    end
end

main()
