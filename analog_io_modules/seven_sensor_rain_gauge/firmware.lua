local config = require('enapter.ucm.config')

VENDOR = 'Seven Sensor Solutions'

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml

ADDRESS = 'address'
BAUDRATE = 'baudrate'
STOP_BITS = 'stop_bits'
PARITY = 'parity'
SERIAL_PORT = 'serial_port'

-- Initiate device firmware. Called at the end of the file.

function main()
  config.init({
    [BAUDRATE] = { type = 'number', required = true, default = 9600 },
    [STOP_BITS] = { type = 'number', required = true, default = 1 },
    [PARITY] = { type = 'string', required = true, default = 'N' },
    [ADDRESS] = { type = 'number', required = true, default = 1 },
    [SERIAL_PORT] = { type = 'string', required = true, default = '/dev/ttyS0' },
  })
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  local properties = {}

  properties.vendor = VENDOR

  local device, err = connect_device()
  if not device then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = { 'cannot_read_config' } })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    end
    return
  end

  local data = device:read_holdings(40020, 16)
  if data then
    properties['model'] = toSunSpecStr(data)
  end

  local data = device:read_holdings(40052, 16)
  if data then
    properties['serial_number'] = toSunSpecStr(data)
  end

  enapter.send_properties(properties)
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = 'ok'

  local device, err = connect_device()
  if not device then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = { 'cannot_read_config' } })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    end
    return
  end

  local data = device:read_inputs(30022, 1)
  if data then
    telemetry['rain_gauge_h'] = table.unpack(data) / 10.0
  end

  local data = device:read_inputs(30028, 1)
  if data then
    telemetry['rain_gauge_m'] = table.unpack(data) / 10.0
  end

  local data = device:read_inputs(30029, 1)
  if data then
    telemetry['rain_gauge_s'] = table.unpack(data) / 10.0
  end

  telemetry.alerts = alerts
  telemetry.status = status
  enapter.send_telemetry(telemetry)
end

function toSunSpecStr(registers)
  local str = ''
  local ok, err = pcall(function()
    for _, reg in pairs(registers) do
      local msb = reg >> 8
      local lsb = reg & 0xFF
      str = str .. string.char(lsb) .. string.char(msb)
    end
  end)
  if not ok then
    enapter.log('cannot read registers: ' .. tostring(err), 'error')
    return nil
  end
  return str
end

-- Holds global device connection
local device

function connect_device()
  if device then
    return device, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local address, baudrate, parity, stop_bits, serial_port =
      values[ADDRESS], values[BAUDRATE], values[PARITY], values[STOP_BITS], values[SERIAL_PORT]
    if not address or not baudrate or not parity or not stop_bits or not serial_port then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      local conn = {
        baudrate = tonumber(baudrate),
        parity = parity,
        stop_bits = tonumber(stop_bits),
        data_bits = 8,
        read_timeout = 1000,
      }
      device = RainGaugeModbusRtu.new(serial_port, conn, address)
      device:connect()
      return device, nil
    end
  end
end

-------------------------------------------
-- Seven Sensor Solutions Rain Gauge Modbus RTU API
-------------------------------------------

RainGaugeModbusRtu = {}

function RainGaugeModbusRtu.new(serial_port, conn, address)
  assert(type(serial_port) == 'string', 'serial_port (arg #1) must be string, given: ' .. inspect(serial_port))
  assert(type(conn.baudrate) == 'number', 'baudrate must be number, given: ' .. inspect(conn.baudrate))
  assert(type(conn.parity) == 'string', 'parity must be string, given: ' .. inspect(conn.parity))
  assert(type(conn.data_bits) == 'number', 'data_bits must be number, given: ' .. inspect(conn.data_bits))
  assert(type(conn.stop_bits) == 'number', 'stop_bits must be number, given: ' .. inspect(conn.stop_bits))
  assert(type(conn.read_timeout) == 'number', 'read_timeout must be number, given: ' .. inspect(conn.read_timeout))
  assert(type(address) == 'number', 'address must be number, given: ' .. inspect(address))

  local self = setmetatable({}, { __index = RainGaugeModbusRtu })
  self.serial_port = serial_port
  self.conn = conn
  self.address = address
  return self
end

function RainGaugeModbusRtu:connect()
  self.modbus = modbusrtu.new(self.serial_port, self.connection)
end

function RainGaugeModbusRtu:read_inputs(start, count)
  assert(type(start) == 'number', 'start (arg #1) must be number, given: ' .. inspect(start))
  assert(type(count) == 'number', 'count (arg #2) must be number, given: ' .. inspect(count))
  local registers, err = self.modbus:read_inputs(self.address, start, count, self.conn.read_timeout)
  if err then
    enapter.log('Register ' .. tostring(start) .. ' read error:  ' .. err, 'error')
    return nil
  end
  return registers
end

function RainGaugeModbusRtu:read_holdings(start, count)
  assert(type(start) == 'number', 'start (arg #1) must be number, given: ' .. inspect(start))
  assert(type(count) == 'number', 'count (arg #2) must be number, given: ' .. inspect(count))
  local registers, err = self.modbus:read_holdings(self.address, start, count, self.conn.read_timeout)
  if err then
    enapter.log('Register ' .. tostring(start) .. ' read error:  ' .. err, 'error')
    return nil
  end
  return registers
end

main()
