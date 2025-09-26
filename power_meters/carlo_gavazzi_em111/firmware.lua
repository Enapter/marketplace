local config = require('enapter.ucm.config')

-- Configuration constants
local DEVICE_ADDRESS = 'device_address'
local BAUD_RATE = 'baud_rate'
local DATA_BITS = 'data_bits'
local PARITY = 'parity'
local STOP_BITS = 'stop_bits'

-- Modbus constants
local READ_TIMEOUT = 1000
local MODBUS_MASTER_ID = 1

local rs485_configured = false

function main()
  config.init({
    [DEVICE_ADDRESS] = { type = 'number', required = true, default = 1 },
    [BAUD_RATE] = { type = 'number', required = true, default = 9600 },
    [DATA_BITS] = { type = 'number', required = true, default = 8 },
    [PARITY] = { type = 'string', required = true, default = 'N' },
    [STOP_BITS] = { type = 'number', required = true, default = 1 },
  }, {
    after_write = setup_rs485,
  })

  -- Setup RS485 connection on startup
  local config_values, err = config.read_all()
  if err == nil then
    err = setup_rs485(config_values)
  end

  if err ~= nil then
    enapter.log(err, 'error', true)
  end

  -- Schedule periodic tasks
  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)
end

function setup_rs485(config_values)
  local baud_rate = config_values[BAUD_RATE]
  local data_bits = config_values[DATA_BITS]
  local parity = config_values[PARITY]
  local stop_bits = config_values[STOP_BITS]
  MODBUS_MASTER_ID = config_values[DEVICE_ADDRESS]

  local result = rs485.init(baud_rate, data_bits, parity, stop_bits)
  if result ~= 0 then
    rs485_configured = false
    return 'RS485 init failed: ' .. rs485.err_to_str(result)
  end

  rs485_configured = true
  enapter.log('RS485 configured: ' .. baud_rate .. ',' .. data_bits .. ',' .. parity .. ',' .. stop_bits, 'info')
  return nil
end

function send_properties()
  enapter.send_properties({
    vendor = 'Carlo Gavazzi',
    model = 'EM111',
  })
end


function read_register(register, length, scale)
  -- Use MODBUS function 04 (Read Input Registers)
  local data, result = modbus.read_inputs(MODBUS_MASTER_ID, register, length, READ_TIMEOUT)

  if not data then
    enapter.log('Failed to read register ' .. register .. ': ' .. modbus.err_to_str(result), 'error')
    return nil
  end

  if length == 1 then
    -- Single 16-bit register - convert to signed int16
    local packed = string.pack('>I2', data[1])
    return string.unpack('>i2', packed) * scale
  elseif length == 2 then
    -- Two 16-bit registers forming a 32-bit integer (LSW first)
    local lsw = data[1]
    local msw = data[2]
    local packed = string.pack('>I2I2', msw, lsw)
    return string.unpack('>i4', packed) * scale
  else
    enapter.log('Unsupported register length: ' .. length, 'error')
    return nil
  end
end

function send_telemetry()
  if not rs485_configured then
    enapter.send_telemetry({
      status = 'read_error',
      alerts = { 'rs485_not_configured' }
    })
    return
  end

  enapter.send_telemetry({
    status = 'ok',
    volt_l1n = read_register(0, 2, 0.1),
    current_l1 = read_register(2, 2, 0.001),
    power_l1 = read_register(4, 2, 0.1),
    acc_power_l1 = read_register(16, 2, 0.1),
    freq = read_register(15, 1, 0.1),
  })
end

main()