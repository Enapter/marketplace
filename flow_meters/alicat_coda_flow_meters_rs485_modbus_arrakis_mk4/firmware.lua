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
    vendor = 'Alicat Scientific',
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
    local data, result = connection:read_holdings(CONNECTION.address, 1119, 2, CONNECTION.read_timeout)
    if data then
      telemetry['proportional_gain'] = tofloat(data)
    else
      enapter.log('Register 1120 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end

    local data, result = connection:read_holdings(CONNECTION.address, 1121, 2, CONNECTION.read_timeout)
    if data then
      telemetry['integral_gain'] = tofloat(data)
    else
      enapter.log('Register 1122 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end

    local data, result = connection:read_holdings(CONNECTION.address, 1123, 2, CONNECTION.read_timeout)
    if data then
      telemetry['derivative_gain'] = tofloat(data)
    else
      enapter.log('Register 1124 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end

    local data, result = connection:read_inputs(CONNECTION.address, 1208, 2, CONNECTION.read_timeout)
    if data then
      telemetry['mass_flow'] = tofloat(data)
    else
      enapter.log('Register 1209 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end

    local data, result = connection:read_inputs(CONNECTION.address, 1206, 2, CONNECTION.read_timeout)
    if data then
      telemetry['volumetric_flow'] = tofloat(data)
    else
      enapter.log('Register 1207 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end

    local data, result = connection:read_inputs(CONNECTION.address, 1204, 2, CONNECTION.read_timeout)
    if data then
      telemetry['flow_temp'] = tofloat(data)
    else
      enapter.log('Register 1205 reading failed: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end
  end

  telemetry['alerts'] = alerts
  telemetry['status'] = status

  enapter.send_telemetry(telemetry)
end

function tofloat(register)
  local raw_str = string.pack('BBBB', register[1] >> 8, register[1] & 0xff, register[2] >> 8, register[2] & 0xff)
  return string.unpack('>f', raw_str)
end

main()
