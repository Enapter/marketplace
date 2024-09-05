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
  config.init({
    [PORT_CONFIG] = { type = 'string', required = true },
    [ADDRESS_CONFIG] = { type = 'string', required = true, default = 121 },
    [BAUD_RATE_CONFIG] = { type = 'string', required = true, default = 9600 },
  })

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('set_lower_start_limit', cmd_lower_start_limit)
  enapter.register_command_handler('set_higher_start_limit', cmd_higher_start_limit)
  enapter.register_command_handler('external_stop', cmd_external_stop)
end

function send_properties()
  enapter.send_properties({ vendor = 'EFOY', model = 'H2 Cabinet N-Series' })
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
        parity = 'E',
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

local float_values = {
  inlet_hydrogen_pressure = {
    addr = 2,
    factor = 1000,
  },
  voltage_dc_bus = {
    addr = 4,
    factor = 1000,
  },
  load_current = {
    addr = 6,
    factor = 1000,
  },
  supply_air_temperature = {
    addr = 8,
    factor = 100,
  },
  rating_fuel_cell_module0 = {
    addr = 12,
    factor = 1,
  },
  rating_fuel_cell_module1 = {
    addr = 14,
    factor = 1,
  },
  rating_fuel_cell_module2 = {
    addr = 16,
    factor = 1,
  },
  rating_fuel_cell_module3 = {
    addr = 18,
    factor = 1,
  },
  internal_hydrogen_pressure_rack0 = {
    addr = 62,
    factor = 1000,
  },
  battery_temperature = {
    addr = 72,
    factor = 100,
  },
  rack_temperature0 = {
    addr = 74,
    factor = 100,
  },
  lower_start_limit = {
    addr = 100,
    factor = 1000,
  },
  higher_start_limit = {
    addr = 102,
    factor = 1000,
  },
}

local int_values = {
  emergency_power_off_signal = {
    addr = 53,
    bits_parser = parse_emergency_signals,
  },
  warning_signal = {
    addr = 55,
    bits_parser = parse_warning_signals,
  },
  ready_signal = {
    addr = 57,
    bits_parser = parse_ready_signals,
  },
  fc_controller_telemetry = {
    addr = 59,
    bits_parser = parse_fc_controller_data,
  },
  rack_hvac = {
    addr = 85,
    bits_parser = parse_rack_data,
  },
}

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = 'ok'

  local connection, err = tty_init()

  if connection then
    for name, reg in float_values do
      local data, result = connection:read_holdings(CONNECTION.address, reg.addr, 2, CONNECTION.read_timeout)

      if data then
        telemetry[name] = to_float(data) * reg.factor
      else
        enapter.log('Error reading Modbus: ' .. result, 'error', true)
        status = 'read_error'
        alerts = { 'communication_failed' }
      end
    end

    for _, reg in int_values do
      local data, result = connection:read_holdings(CONNECTION.address, reg.addr, 1, CONNECTION.read_timeout)
      if data then
        local signals = reg.bits_parser(data[1])
        if #signals > 0 then
          alerts = table.move(signals, 1, #signals, #alerts + 1, alerts)
        end
      else
        enapter.log('Error reading Modbus: ' .. result, 'error', true)
        status = 'read_error'
        alerts = { 'communication_failed' }
      end
    end
  else
    status = 'read_error'
    alerts = { err }
  end

  telemetry['alerts'] = alerts
  telemetry['status'] = status

  enapter.send_telemetry(telemetry)
end

function cmd_lower_start_limit(ctx, args)
  local connection, err = tty_init()
  if not connection then
    ctx.error('No connection to device: ' .. err .. '.')
  end

  if args['limit'] == nil then
    ctx.error('Missing argument limit.')
  end

  local values = to_int16_pair(math.floor(args['limit']))

  local err = connection:write_multiple_holdings(CONNECTION.address, 400, values, CONNECTION.read_timeout)
  if err ~= nil then
    ctx.error('Command failed: ' .. connection:err_to_str(err))
  end
  return 'Success'
end

function cmd_higher_start_limit(ctx, args)
  local connection, err = tty_init()
  if not connection then
    ctx.error('No connection to device: ' .. err .. '.')
  end

  if args['limit'] == nil then
    ctx.error('Missing argument limit.')
  end

  local values = to_int16_pair(math.floor(args['limit']))

  local err = connection:write_multiple_holdings(CONNECTION.address, 402, values, CONNECTION.read_timeout)
  if err ~= nil then
    ctx.error('Command failed: ' .. connection:err_to_str(err))
  end
  return 'Success'
end

function cmd_external_stop(ctx, args)
  local connection, err = tty_init()
  if not connection then
    ctx.error('No connection to device: ' .. err .. '.')
  end

  if args['action'] == nil then
    ctx.error('Missing argument action.')
  end

  local modes = {
    auto = 0,
    stop = 1,
  }

  if not modes[args['action']] then
    ctx.error('Unknown mode: ' .. args['action'])
  end

  local err = connection:write_holding(CONNECTION.address, 451, modes[args['action']], CONNECTION.read_timeout)
  if err ~= nil then
    ctx.error('Command failed: ' .. connection:err_to_str(err))
  end
  return 'Success'
end

function to_float(register)
  local raw_str = string.pack('BBBB', register[1] >> 8, register[1] & 0xff, register[2] >> 8, register[2] & 0xff)
  return string.unpack('>f', raw_str)
end

function to_int16_pair(f)
  local packed = string.pack('f', f)
  local high, low = string.unpack('I2I2', packed)
  return { low, high }
end

function parse_emergency_signals(value)
  local signals = {}
  local bits_map = {
    emergency_module0 = math.floor(2 ^ 0),
    emergency_module1 = math.floor(2 ^ 1),
    emergency_module2 = math.floor(2 ^ 2),
    emergency_module3 = math.floor(2 ^ 3),
  }
  for k, v in pairs(bits_map) do
    if value & v ~= 0 then
      table.insert(signals, k)
    end
  end
  return signals
end

function parse_warning_signals(value)
  local signals = {}
  local bits_map = {
    warning_module0 = math.floor(2 ^ 0),
    warning_module1 = math.floor(2 ^ 1),
    warning_module2 = math.floor(2 ^ 2),
    warning_module3 = math.floor(2 ^ 3),
  }
  for k, v in pairs(bits_map) do
    if value & v ~= 0 then
      table.insert(signals, k)
    end
  end
  return signals
end

function parse_ready_signals(value)
  local signals = {}
  local bits_map = {
    ready_module0 = math.floor(2 ^ 0),
    ready_module1 = math.floor(2 ^ 1),
    ready_module2 = math.floor(2 ^ 2),
    ready_module3 = math.floor(2 ^ 3),
  }
  for k, v in pairs(bits_map) do
    if value & v ~= 0 then
      table.insert(signals, k)
    end
  end
  return signals
end

function parse_fc_controller_data(value)
  local signals = {}
  local bits_map = {
    alarm = math.floor(2 ^ 0),
    warning = math.floor(2 ^ 1),
    fc_status = math.floor(2 ^ 2),
    fc_running = math.floor(2 ^ 3),
    filter_change = math.floor(2 ^ 5),
  }
  for k, v in pairs(bits_map) do
    if value & v ~= 0 then
      table.insert(signals, k)
    end
  end
  return signals
end

function parse_rack_data(value)
  local signals = {}
  local bits_map = {
    ventilation0 = math.floor(2 ^ 0),
    heating0 = math.floor(2 ^ 5),
  }
  for k, v in pairs(bits_map) do
    if value & v ~= 0 then
      table.insert(signals, k)
    end
  end
  return signals
end

main()
