local config = require('enapter.ucm.config')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
PORT_CONFIG = 'port'
ADDRESS_CONFIG = 'address'
BAUD_RATE_CONFIG = 'baud_rate'
STOP_BITS_CONFIG = 'stop_bits'
PARITY_CONFIG = 'parity'

local CONNECTION = {}
local SERIAL_OPTIONS = {}
local TTY

function main()
  config.init({
    [PORT_CONFIG] = { type = 'string', required = true },
    [ADDRESS_CONFIG] = { type = 'string', required = true, default = 1 },
    [BAUD_RATE_CONFIG] = { type = 'number', required = true, default = 19200 },
    [STOP_BITS_CONFIG] = { type = 'number', required = true, default = 1 },
    [PARITY_CONFIG] = { type = 'string', required = true, default = 'N' },
  })
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({
    vendor = 'IMT Solar',
    model = 'Si-RS485TC-2T',
  })
end

function tty_init()
  if TTY then
    return TTY, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local port, address, baud_rate, stop_bits, parity =
      values[PORT_CONFIG],
      values[ADDRESS_CONFIG],
      values[BAUD_RATE_CONFIG],
      values[STOP_BITS_CONFIG],
      values[PARITY_CONFIG]
    if not port or not address or not baud_rate or not stop_bits or not parity then
      return nil, 'not_configured'
    else
      CONNECTION = {
        address = tonumber(address),
        read_timeout = 1000,
      }

      SERIAL_OPTIONS = {
        baud_rate = tonumber(baud_rate),
        parity = tostring(parity),
        stop_bits = tostring(stop_bits),
        data_bits = 8,
        read_timeout = 1000,
      }

      TTY = modbusrtu.new(port, SERIAL_OPTIONS)

      if TTY then
        return TTY, nil
      else
        return nil, 'rs485_init_issue'
      end
    end
  end
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = 'ok'

  local connection, err = tty_init()
  if err ~= nil then
    status = 'read_error'
    alerts = { err }
  else
    local data, result = connection:read_inputs(CONNECTION.address, 0, 1, CONNECTION.read_timeout)
    if data then
      telemetry['solar_irrad'] = uint16(data) / 10
    else
      enapter.log('Register 0 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end

    local data, result = connection:read_inputs(CONNECTION.address, 7, 1, CONNECTION.read_timeout)
    if data then
      telemetry['module_temp'] = int16(data) / 10
    else
      enapter.log('Register 7 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end

    local data, result = connection:read_inputs(CONNECTION.address, 8, 1, CONNECTION.read_timeout)
    if data then
      telemetry['ambient_temp'] = int16(data) / 10
    else
      enapter.log('Register 8 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end
  end

  telemetry['alerts'] = alerts
  telemetry['status'] = status

  enapter.send_telemetry(telemetry)
end

function uint16(register)
  local raw_str = string.pack('BB', register[1] & 0xFF, register[1] >> 8)
  return string.unpack('I2', raw_str)
end

function int16(register)
  local raw_str = string.pack('BB', register[1] & 0xFF, register[1] >> 8)
  return string.unpack('i2', raw_str)
end

main()
