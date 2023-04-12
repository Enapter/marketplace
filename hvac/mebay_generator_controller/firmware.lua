-- Default values of serial communication parameters
BAUD_RATE = 19200
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1
MODBUS_ADDRESS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log('RS485 failed: ' .. result .. ' ' .. rs485.err_to_str(result), 'error', true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  local data = modbus.read_holdings(MODBUS_ADDRESS, 0x1048, 1, 1000)
  local model = 'DC6xD'

  if data then
    model = 'DC6' .. tostring(data[1]) .. 'D'
  end

  enapter.send_properties({
    vendor = 'Mebay',
    model = model,
  })
end

function send_telemetry()
  local telemetry = {}
  local status = 'ok'

  local REGISTERS = {
    frequency = {
      address = 0x1009,
      count = 1,
      factor = 10,
    },
    voltage_1 = {
      address = 0x100A,
      count = 1,
      factor = 1,
    },
    voltage_2 = {
      address = 0x100B,
      count = 1,
    },
    voltage_3 = {
      address = 0x100C,
      count = 1,
    },
    current_1 = {
      address = 0x1010,
      count = 1,
    },
    current_2 = {
      address = 0x1011,
      count = 1,
    },
    current_3 = {
      address = 0x1012,
      count = 1,
    },
    active_power_1 = {
      address = 0x1018,
      count = 1,
    },
    active_power_2 = {
      address = 0x1019,
      count = 1,
    },
    active_power_3 = {
      address = 0x101A,
      count = 1,
    },
    total_active_power = {
      address = 0x101B,
      count = 1,
    },
    mains_frequency = {
      address = 0x1024,
      count = 1,
    },
    mains_voltage_1 = {
      address = 0x1025,
      count = 1,
    },
    mains_voltage_2 = {
      address = 0x1026,
      count = 1,
    },
    mains_voltage_3 = {
      address = 0x1027,
      count = 1,
    },
    total_runtime = {
      address = 0x1036,
      count = 2,
      fn = touint32,
    },
    fuel_level = {
      address = 0x1058,
      count = 1,
    },
  }

  for name, register in pairs(REGISTERS) do
    local data, result =
      modbus.read_holdings(MODBUS_ADDRESS, register.address, register.count, 1000)
    if data and register.fn then
      telemetry[name] = register.factor and register.fn(data) / register.factor or register.fn(data)
    elseif data then
      telemetry[name] = register.factor and data[1] / register.factor or data[1]
    else
      enapter.log(
        'Register ' .. register.address .. ' reading failed: ' .. modbus.err_to_str(result),
        'error'
      )
    end
  end

  if not next(telemetry) then
    status = 'no_data'
  end

  telemetry['status'] = status
  enapter.send_telemetry(telemetry)
end

function touint32(register)
  local raw_str =
    string.pack('BBBB', register[1] >> 8, register[1] & 0xff, register[2] >> 8, register[2] & 0xff)
  return string.unpack('>I2', raw_str)
end

main()
