function main()
  local result = rs485.init(9600, 8, "N", 1)
  if result ~= 0 then
    enapter.log("RS-485 failed: "..result.." "..rs485.err_to_str(result), "error", true)
  end

  scheduler.add(30000, properties)
  scheduler.add(1000, telemetry)
end

function properties()
  enapter.send_properties({
    vendor = "M-Field",
    model = "MF-UEH"
  })
end

function telemetry()
  local telemetry = {}
  local status = "ok"

  local DEVICE_ID = "\x25"
  local FUNCTION = "\x03"
  local STARTING_ADDR_MSB = "\x00"
  local STARTING_ADDR_LSB = "\x00"
  local DATA_SIZE = "\x24"
  -- commant to read all registers from p. 6.1 (QW-RD-09)
  local read_command = DEVICE_ID..FUNCTION..STARTING_ADDR_MSB..STARTING_ADDR_LSB..DATA_SIZE
  local read_request = read_command .. string.char(check_crc(read_command)) -- add checksum
  local result = rs485.send(read_request) -- send the data to RS-485 network
  if result ~= 0 then
    enapter.log("RS-485 sending data failed: "..result.." "..rs485.err_to_str(result), "error", true)
  else
    enapter.log("Data sent: " .. hex_dump(read_request))
  end

  local raw_data, result = rs485.receive(1000) --[[ receive with 1 second timeout.
  The answer is in format described in p. 6.5.3 (QW-RD-09) --]]

  if not raw_data then
    enapter.log("RS485 receiving data failed: "..result.." "..rs485.err_to_str(result), "error", true)
    status = "read_error"
  else
    enapter.log("Data received: " .. hex_dump(raw_data) .. " Sting length: " .. string.len(raw_data))
    -- How to convert received values - p. 6.1.2 (QW-RD-08)
    local volt = string.unpack("<I2", raw_data:sub(9, 10)) / 100
    local current = string.unpack("<I2", raw_data:sub(11, 12)) / 100
    telemetry["output_volt"] = volt
    telemetry["output_current"] = current
    telemetry["output_power"] = volt * current
    telemetry["hydrogen_inlet_pressure"] = (string.unpack("<I2", raw_data:sub(13, 14))-1000) / 4000 * 10
    telemetry["battery_volt"] = string.unpack("<I2", raw_data:sub(19, 20)) / 100
    telemetry["battery_current"] = string.unpack("<I2", raw_data:sub(21, 22)) / 100
    telemetry["system_temperature1"] = string.unpack("<i2", raw_data:sub(23, 24)) / 100
    telemetry["system_temperature2"] = string.unpack("<i2", raw_data:sub(25, 26)) / 100
  end

  telemetry["status"] = status
  enapter.send_telemetry(telemetry)
end

function check_crc(newdata)
  local CRC8_TABLE = { 0x00, 0x83, 0x85, 0x06, 0x89, 0x0A, 0x0C, 0x8F,
  0x91, 0x12, 0x14, 0x97, 0x18, 0x9B, 0x9D, 0x1E };
  local crc = 0
  for i = 1, #newdata do
    crc = (((crc << 4) & 0xFF) ~ (CRC8_TABLE[((crc >> 4) ~ (newdata:byte(i) >> 4)) + 1])) & 0xFF
    crc = (((crc << 4) & 0xFF) ~ (CRC8_TABLE[((crc >> 4) ~ (newdata:byte(i) & 0x0F)) + 1])) & 0xFF
  end
  return crc
end

function hex_dump (str)
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
  .. string.rep("   ", 8 - len % 8) .. asc
end

main()
