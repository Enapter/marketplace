local config = require('enapter.ucm.config')

VENDOR = 'InfraSensing'
MODEL = 'ENV-THUM'

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS_CONFIG = 'ip_address'
UNIT_ID_CONFIG = 'modbus_unit_id'

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [IP_ADDRESS_CONFIG] = { type = 'string', required = true },
    [UNIT_ID_CONFIG] = { type = 'number', required = true },
  })

  enapter.register_command_handler('set_threshold', command_set_threshold)
end

function send_properties()
  local properties = {}

  properties.vendor = VENDOR
  properties.model = MODEL

  enapter.send_properties(properties)
end

function send_telemetry()
  local device, err = connect_device()
  if not device then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = { 'cannot_read_config' } })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    end
    return
  end

  local telemetry = {}
  local alerts = {}
  local status = 'ok'

  for i = 0, 2 do
    local data = device:read_inputs(30200 + i * 32, 2)
    if data then
      telemetry['value' .. i] = toFloat32(data)
    end

    local data = device:read_input_status(10201 + i * 32, 1)
    if data then
      telemetry['alarm_down' .. i] = data[1]
      table.insert(alerts, 'alarm_down' .. i)
      status = 'down'
    end

    local data = device:read_input_status(10202 + i * 32, 1)
    if data then
      telemetry['alarm_warn' .. i] = data[1]
      table.insert(alerts, 'alarm_warn' .. i)
      status = 'warning'
    end

    local data = device:read_holdings(40200 + i * 32, 2)
    if data then
      telemetry['thr_high_down' .. i] = toFloat32(data)
    end

    local data = device:read_holdings(40202 + i * 32, 2)
    if data then
      telemetry['thr_high_warn' .. i] = toFloat32(data)
    end

    local data = device:read_holdings(40204 + i * 32, 2)
    if data then
      telemetry['thr_low_high' .. i] = toFloat32(data)
    end

    local data = device:read_holdings(40206 + i * 32, 2)
    if data then
      telemetry['thr_low_warn' .. i] = toFloat32(data)
    end
  end

  telemetry.alerts = alerts
  telemetry.status = status
  enapter.send_telemetry(telemetry)
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
    local address, unit_id = values[IP_ADDRESS_CONFIG], values[UNIT_ID_CONFIG]
    if not address or not unit_id then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      device = SensorGwModbusTcp.new(address, tonumber(unit_id))
      device:connect()
      return device, nil
    end
  end
end

function command_set_threshold(ctx, args)
  local thresholds = {
    ['High Down'] = 0,
    ['High Warn'] = 2,
    ['Low Down'] = 4,
    ['Low Warn'] = 6,
  }

  if device then
    local err = device:write_holdings(args.node * 32 + 40200 + thresholds[args.threshold], args.value)
    if err == 0 then
      return 'Reset command is sent'
    else
      ctx.error('Command failed, Modbus TCP error: ' .. tostring(err))
    end
  else
    ctx.error('Device connection is not configured')
  end
end

function toFloat32(data)
  local raw_str = string.pack('BBBB', data[1] >> 8, data[1] & 0xff, data[2] >> 8, data[2] & 0xff)
  return string.unpack('>f', raw_str)
end

-------------------------------------------
-- InfraSensing SensorGateway ModbusTCP API
-------------------------------------------

SensorGwModbusTcp = {}

function SensorGwModbusTcp.new(addr, unit_id)
  assert(type(addr) == 'string', 'addr (arg #1) must be string, given: ' .. inspect(addr))
  assert(type(unit_id) == 'number', 'unit_id (arg #2) must be number, given: ' .. inspect(unit_id))

  local self = setmetatable({}, { __index = SensorGwModbusTcp })
  self.addr = addr
  self.unit_id = unit_id
  return self
end

function SensorGwModbusTcp:connect()
  self.modbus = modbustcp.new(self.addr)
end

function SensorGwModbusTcp:read_inputs(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(type(number) == 'number', 'number (arg #2) must be number, given: ' .. inspect(number))

  local registers, err = self.modbus:read_inputs(self.unit_id, address, number, 1000)
  if err and err ~= 0 then
    enapter.log('Register ' .. tostring(address) .. ' read error: ' .. err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
    return nil
  end

  return registers
end

function SensorGwModbusTcp:read_input_status(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(type(number) == 'number', 'number (arg #2) must be number, given: ' .. inspect(number))

  local registers, err = self.modbus:read_discrete_inputs(self.unit_id, address, number, 1000)
  if err and err ~= 0 then
    enapter.log('Register ' .. tostring(address) .. ' read error: ' .. err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
    return nil
  end

  return registers
end

function SensorGwModbusTcp:read_holdings(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(type(number) == 'number', 'number (arg #2) must be number, given: ' .. inspect(number))

  local registers, err = self.modbus:read_inputs(self.unit_id, address, number, 1000)
  if err and err ~= 0 then
    enapter.log('Register ' .. tostring(address) .. ' read error: ' .. err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
    return nil
  end

  return registers
end

function SensorGwModbusTcp:write_holdings(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(type(number) == 'number', 'number (arg #2) must be number, given: ' .. inspect(number))

  local err = self.modbus:write_holding(self.unit_id, address, number, 1000)
  if err ~= 0 then
    enapter.log('Register ' .. tostring(address) .. ' write error: ' .. err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
  end
  return err
end

main()
