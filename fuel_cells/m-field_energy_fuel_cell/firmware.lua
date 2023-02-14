local config = require("enapter.ucm.config")

DEVICE_ID_CONFIG = "device_id"

-- RS485 communication interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS-485 failed: " .. result .. " " .. rs485.err_to_str(result), "error", true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [DEVICE_ID_CONFIG] = { type = 'string', required = true, default = '24' }
  })
end

function send_properties()
  local properties = {
    vendor = "M-Field",
    model = "MF-UEH"
  }

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    properties[DEVICE_ID_CONFIG] = values[DEVICE_ID_CONFIG]
  end

  enapter.send_properties(properties)
end

function send_telemetry()
  local DEVICE_ID = '\x24' -- default

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    DEVICE_ID = string.char(tonumber(values[DEVICE_ID_CONFIG], 16))
  end

  local FUNCTION = "\x03"
  local STARTING_ADDR_MSB = "\x00"
  local STARTING_ADDR_LSB = "\x00"
  local DATA_SIZE = "\x24"

  local telemetry = {}
  local status = "ok"

  local read_command = DEVICE_ID .. FUNCTION .. STARTING_ADDR_MSB .. STARTING_ADDR_LSB .. DATA_SIZE
  local read_request = read_command .. string.char(check_crc(read_command))
  local result = rs485.send(read_request)
  if result ~= 0 then
    enapter.log("RS-485 sending data failed: " .. result .. " " .. rs485.err_to_str(result), "error", true)
  end

  local raw_data, result = read_data()

  if not raw_data then
    enapter.log("RS485 receiving data failed: " .. rs485.err_to_str(result), "error", true)
    enapter.send_telemetry({status = 'no_data'})
    return
  else
    local volt = string.unpack("<I2", raw_data:sub(9, 10)) / 100
    local current = string.unpack("<I2", raw_data:sub(11, 12)) / 100
    telemetry["output_volt"] = volt
    telemetry["output_current"] = current
    telemetry["output_power"] = volt * current
    telemetry["hydrogen_inlet_pressure"] = (string.unpack("<I2", raw_data:sub(13, 14)) - 1000) / 4000 * 10
    telemetry["battery_volt"] = string.unpack("<I2", raw_data:sub(19, 20)) / 100
    telemetry["battery_current"] = string.unpack("<I2", raw_data:sub(21, 22)) / 100
    telemetry["system_temperature1"] = string.unpack("<i2", raw_data:sub(23, 24)) / 100
    telemetry["system_temperature2"] = string.unpack("<i2", raw_data:sub(25, 26)) / 100
  end

  telemetry["status"] = status
  enapter.send_telemetry(telemetry)
end

function read_data()
  local READ_TIMEOUT = 2
  local FULL_LENGTH = 40
  local RS485_RESPONSE_TIMEOUT = 1000

  local full_data = ""
  local timeout = os.time() + READ_TIMEOUT

  while #full_data < FULL_LENGTH do
    if os.time() > timeout then
      return nil, 2
    end
    local raw_data, result = rs485.receive(RS485_RESPONSE_TIMEOUT)

    if raw_data == nil then
      return nil, result
    end
    full_data = full_data .. raw_data
    while #full_data > 2 and full_data:sub(1, 3) ~= "\x25\x03\x24" do
      full_data = full_data:sub(2, -1)
    end
  end
  full_data = full_data:sub(1, 40)

  if full_data:byte(40) == check_crc(full_data:sub(1, 39)) then
    return full_data:sub(1, 39)
  end
  return nil, 2
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

main()
