local config = require('enapter.ucm.config')
local qmodbus = require('enapter.ucm.qmodbus')

local rs485_configured = false
local rs485_not_configured_err = 'rs485 is not properly configured'

BAUD_RATE = 'baud_rate'
DATA_BITS = 'data_bits'
PARITY = 'parity'
STOP_BITS = 'stop_bits'
BUFFER_SIZE = 'buffer_size'

function main()
  config.init({
    [BAUD_RATE] = { type = 'number', required = true },
    [DATA_BITS] = { type = 'number', required = true },
    [PARITY] = { type = 'string', required = true },
    [STOP_BITS] = { type = 'number', required = true },
    [BUFFER_SIZE] = { type = 'number', default = 4096 },
  }, {
    after_write = setup_rs485,
  })

  local args, err = config.read_all()
  if err == nil then
    err = setup_rs485(args)
  end

  if err ~= nil then
    enapter.log(err, 'error', true)
  end

  enapter.register_command_handler('read', cmd_read)
  enapter.register_command_handler('write', cmd_write)

  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)
end

function setup_rs485(args)
  local baud_rate = math.tointeger(args[BAUD_RATE])
  local data_bits = math.tointeger(args[DATA_BITS])
  local parity = args[PARITY]
  local stop_bits = math.tointeger(args[STOP_BITS])
  local buffer_size = math.tointeger(args[BUFFER_SIZE])

  if baud_rate == nil or data_bits == nil or parity == nil or stop_bits == nil then
    rs485_configured = false
    return 'RS-485 is not configured'
  end

  local result = rs485.init(baud_rate, data_bits, parity, stop_bits, buffer_size)
  if result ~= 0 then
    rs485_configured = false
    return 'RS-485 init failed: ' .. result .. ' ' .. rs485.err_to_str(result)
  end
  rs485_configured = true
end

function send_telemetry()
  local status = 'ok'
  local alerts = {}
  if not rs485_configured then
    table.insert(alerts, 'not_configured')
    status = 'error'
  end

  local telemetry = { alerts = alerts, status = status }

  enapter.send_telemetry(telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-RS485' })
end

function cmd_read(ctx, args)
  if not rs485_configured then
    ctx.error(rs485_not_configured_err)
  end

  local results, errmsg = qmodbus.read(args['queries'])
  if errmsg ~= nil then
    ctx.error(errmsg)
  end

  return { results = results }
end

function cmd_write(ctx, args)
  if not rs485_configured then
    ctx.error(rs485_not_configured_err)
  end

  local results, errmsg = qmodbus.write(args['queries'])
  if errmsg ~= nil then
    ctx.error(errmsg)
  end

  return { results = results }
end

main()
