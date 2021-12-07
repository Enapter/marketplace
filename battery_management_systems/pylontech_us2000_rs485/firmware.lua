-- Pylontech US2000 Battery
-- Serial over RS485
-- Baud rate = 9600 bps, 8 data bits, no parity, 1 stop bit

function main()
  local result = rs485.init(9600, 8, "N", 1)
  if result ~= 0 then
    enapter.log("RS485 init failed: "..rs485.err_to_str(result))
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, telemetry)
end

function properties()
  enapter.send_properties({ vendor = "Pylontech", model = "US2000" })
end

function telemetry()
  local b0_TotalCurrent, b0_TotalVoltage, b0_RemainingCapacity, b0_TotalCapacity = get_analog_value(0)
  local b1_TotalCurrent, b1_TotalVoltage, b1_RemainingCapacity, b1_TotalCapacity = get_analog_value(1)
  local b2_TotalCurrent, b2_TotalVoltage, b2_RemainingCapacity, b2_TotalCapacity = get_analog_value(2)
  local b3_TotalCurrent, b3_TotalVoltage, b3_RemainingCapacity, b3_TotalCapacity = get_analog_value(3)

  if b0_TotalCurrent then
    enapter.send_telemetry({
      b0_total_current = b0_TotalCurrent,
      b0_total_voltage = b0_TotalVoltage,
      b0_total_power = b0_TotalCurrent * b0_TotalVoltage,
      b0_battery_level = b0_RemainingCapacity / b0_TotalCapacity * 100,
      b1_total_current = b1_TotalCurrent,
      b1_total_voltage = b1_TotalVoltage,
      b1_total_power = b1_TotalCurrent * b1_TotalVoltage,
      b1_battery_level = b1_RemainingCapacity / b1_TotalCapacity * 100,
      b2_total_current = b2_TotalCurrent,
      b2_total_voltage = b2_TotalVoltage,
      b2_total_power = b2_TotalCurrent * b2_TotalVoltage,
      b2_battery_level = b2_RemainingCapacity / b2_TotalCapacity * 100,
      b3_total_current = b3_TotalCurrent,
      b3_total_voltage = b3_TotalVoltage,
      b3_total_power = b3_TotalCurrent * b3_TotalVoltage,
      b3_battery_level = b3_RemainingCapacity / b3_TotalCapacity * 100
    })
  end
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

  local CellsCount = binary_data:byte(3)
  local TempCount = binary_data:byte(CellsCount * 2 + 4)

  local data_pos = CellsCount * 2 + TempCount * 2 + 9
  local TotalCurrent = get_int2_complement(binary_data:sub(data_pos, data_pos + 1)) / 100.0
  data_pos = data_pos + 2
  local TotalVoltage = get_int2(binary_data:sub(data_pos, data_pos + 1)) / 100.0
  data_pos = data_pos + 2
  local RemainingCapacity = get_int2(binary_data:sub(data_pos, data_pos + 1)) / 100.0
  data_pos = data_pos + 2
  local TotalCapacity = get_int2(binary_data:sub(data_pos, data_pos + 1)) / 100.0
  data_pos = data_pos + 2
  local Cycles = get_int2(binary_data:sub(data_pos, data_pos + 1))

  return TotalCurrent, TotalVoltage, RemainingCapacity, TotalCapacity, Cycles
end

function make_message(addr, cid2, command)
  local len = 0
  if command then
    len = 2
  end
  local message = "\x20" .. string.char(addr) .. "\x4A" .. string.char(cid2) .. get_length(len)
  if command then
    message = message .. string.char(command)
  end
  local payload = to_ascii(message)
  payload = "\x7E" .. payload .. get_checksum(payload) .. "\x0D"
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

--[[function hex_dump(str)
    local len = string.len(str)
    local dump = ""
    local hex = ""
    local asc = ""
    for i = 1, len do
        if 1 == i % 8 then
            dump = dump .. hex .. asc .. "\n"
            hex = string.format("%04x: ", i - 1)
            asc = ""
        end
        local ord = string.byte(str, i)
        hex = hex .. string.format("%02x ", ord)
        if ord >= 32 and ord <= 126 then
            asc = asc .. string.char(ord)
        else
            asc = asc .. "."
        end
    end
    return dump .. hex
            .. string.rep(" ", 8 - len % 8) .. asc
end]]--

main()
