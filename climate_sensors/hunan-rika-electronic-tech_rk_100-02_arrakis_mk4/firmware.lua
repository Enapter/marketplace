-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter

local config = require('enapter.ucm.config')

PORT_CONFIG = 'port'
ADDRESS_CONFIG = 'address'
BAUD_RATE_CONFIG = 'baud_rate'

local CONNECTION = {}
local SERIAL_OPTIONS = {}
local TTY

function main()
  -- Init config & register config management commands
  config.init({
    [PORT_CONFIG] = { type = 'string', required = true },
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [BAUD_RATE_CONFIG] = { type = 'string', required = true },
  })

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Rika Sensor', model = 'RK100-02' })
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
    local port, address, baud_rate = values[PORT_CONFIG], values[ADDRESS_CONFIG], values[BAUD_RATE_CONFIG]
    if not port or not address or not baud_rate then
      return nil, 'not_configured'
    else
      CONNECTION = {
        read_timeout = 1000,
        address = tonumber(address),
      }

      SERIAL_OPTIONS = {
        baud_rate = tonumber(baud_rate),
        parity = 'N',
        stop_bits = 1,
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

  if connection then
    local data, result = connection:read_holdings(CONNECTION.address, 0, 1, CONNECTION.read_timeout)

    if data then
      telemetry['wind_speed'] = tonumber(data) / 10
    else
      enapter.log('Error reading Modbus: ' .. result, 'error', true)
      status = 'read_error'
      alerts = { 'communication_failed' }
    end
  else
    status = 'read_error'
    alerts = { err }
  end

  telemetry['alerts'] = alerts
  telemetry['status'] = status

  enapter.send_telemetry(telemetry)
end

main()
