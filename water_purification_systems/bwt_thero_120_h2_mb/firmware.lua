local config = require('enapter.ucm.config')

VENDOR = 'BWT'
MODEL = 'THERO 120 H2 MB'

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

  enapter.register_command_handler('reset', command_reset)
  enapter.register_command_handler('control_ro', command_control_ro)
end

function send_properties()
  local properties = {}

  local device, _ = connect_device()

  if device then
    local data = device:read_inputs(26, 1)
    if data then
      properties.fw_version = tostring(data[1] >> 8) .. '.' .. tostring(data[1] & 0xff)
    end

    local data = device:read_inputs(27, 1)
    if data then
      properties.hw_version = tostring(data[1] >> 8) .. '.' .. tostring(data[1] & 0xff)
    end
  else
    enapter.log('Modbus TCP connection error', 'error')
  end

  properties.vendor = VENDOR
  properties.model = MODEL
  properties.ip_address = device.addr
  properties.unit_id = device.unit_id

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

  local data = device:read_inputs(25, 1)
  if data then
    table.insert(alerts, get_service_status(data[1]))
  end

  local data = device:read_inputs(0, 1)
  if data then
    local ro_status, alert = get_ro_status(data[1])
    telemetry.ro_status = ro_status
    if ro_status == 'alarm' or ro_status == 'unknown' then
      telemetry.status = 'error'
    elseif ro_status == 'warning' or ro_status == 'dripping_faucet_recovery_attempt' then
      telemetry.status = 'warning'
    else
      telemetry.status = 'ok'
    end
    if alert then
      table.insert(alerts, alert)
    end
  end

  local data = device:read_inputs(2, 1)
  if data then
    local alarms = get_alarms(data[1])
    alerts = table.move(alarms, 1, #alarms, #alerts + 1, alerts)
  end

  local data = device:read_inputs(3, 1)
  if data then
    telemetry.outlet_permeate_temperature = data[1] / 10.0
  end

  local data = device:read_inputs(4, 1)
  if data then
    telemetry.outlet_flow = data[1]
  end

  local data = device:read_inputs(5, 1)
  if data then
    telemetry.inlet_flow = data[1]
  end

  local data = device:read_inputs(7, 1)
  if data then
    telemetry.demin_tank_pressure = data[1] / 10.0
  end

  local data = device:read_inputs(8, 1)
  if data then
    telemetry.demin_out_conducibility = data[1]
  end

  local data = device:read_inputs(9, 1)
  if data then
    telemetry.membrane_out_conducibility = data[1]
  end

  local data = device:read_inputs(10, 2)
  if data then
    telemetry.demin_partial_counter = toint32(data)
  end

  local data = device:read_inputs(12, 2)
  if data then
    telemetry.ro_membrane_partial_counter = toint32(data)
  end

  local data = device:read_inputs(14, 2)
  if data then
    telemetry.demin_total_counter = toint32(data)
  end

  local data = device:read_inputs(16, 2)
  if data then
    telemetry.ro_membrane_total_counter = toint32(data)
  end

  local data = device:read_inputs(18, 1)
  if data then
    telemetry.ro_pump_service_time = data[1]
  end

  local data = device:read_inputs(19, 2)
  if data then
    telemetry.demin_capacity = toint32(data)
  end

  local data = device:read_inputs(21, 2)
  if data then
    telemetry.membrane_capacity = toint32(data)
  end

  local data = device:read_inputs(23, 1)
  if data then
    telemetry.membrane_day_counter_service_limit = data[1]
  end

  local data = device:read_inputs(24, 1)
  if data then
    telemetry.ro_membrane_life_days = data[1]
  end

  local data = device:read_inputs(28, 1)
  if data then
    telemetry.conductivity_unit = data[1]
  end

  telemetry.alerts = alerts
  enapter.send_telemetry(telemetry)
end

function get_ro_status(value)
  if value == 1 then
    return 'ready'
  elseif value == 2 then
    return 'working'
  elseif value >= 3 and value <= 7 or value == 60 then
    return 'alarm'
  elseif value == 9 then
    return 'rinse'
  elseif value == 10 then
    return 'dripping_faucet_recovery_attempt'
  elseif value == 51 then
    return 'pause'
  elseif value == 53 or value == 61 then
    return 'warning'
  elseif value == 54 then
    return 'alarm', 'internal_pressure_sensor_failure'
  else
    return 'unknown'
  end
end

function get_service_status(value)
  local status = {}
  status[0] = nil
  status[1] = 'A'
  status[2] = 'B'
  status[3] = 'C'
  status[4] = 'AB'
  status[5] = 'AC'
  status[6] = 'BC'
  status[7] = 'ABC'
  status[49] = 'D'
  status[50] = 'AD'
  status[51] = 'BD'
  status[52] = 'CD'
  status[53] = 'ABD'
  status[54] = 'ACD'
  status[55] = 'BCD'
  status[56] = 'ABCD'
  return status[value]
end

function get_alarms(value)
  local alerts = {}
  if value & 0x0001 ~= 0 then
    table.insert(alerts, 'RO_pump_error')
  end
  if value & 0x0002 ~= 0 then
    table.insert(alerts, 'RO_pump_thermal_protection')
  end
  if value & 0x0004 ~= 0 then
    table.insert(alerts, 'internal_leak_detected')
  end
  if value & 0x0008 ~= 0 then
    table.insert(alerts, 'wcf_too_low')
  end
  if value & 0x0010 ~= 0 then
    table.insert(alerts, 'outlet_pressure_transducer_failure')
  end
  if value & 0x0040 ~= 0 then
    table.insert(alerts, 'dripping_faucet')
  end
  if value & 0x0080 ~= 0 then
    table.insert(alerts, 'inlet_flow_meter')
  end
  if value & 0x1000 ~= 0 then
    table.insert(alerts, 'membrane_conductivity_too_high')
  end
  if value & 0x2000 ~= 0 then
    table.insert(alerts, 'demin_conductivity_too_high')
  end
  return alerts
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
      device = BwtTheroModbusTcp.new(address, tonumber(unit_id))
      device:connect()
      return device, nil
    end
  end
end

function command_reset(ctx, args)
  local value
  if args.value == 'Dripping facet alarm' then
    value = 0x0040
  elseif args.value == 'Membrane partial counter' then
    value = 0x1000
  elseif args.value == 'Demin partial counter' then
    value = 0x2000
  else
    ctx.error('Unknown counter or alarm is selected')
  end

  if device then
    local err = device:write_holding(0, value)
    if err == 0 then
      return 'Reset command is sent'
    else
      ctx.error('Command failed, Modbus TCP error: ' .. tostring(err))
    end
  else
    ctx.error('Device connection is not configured')
  end
end

function command_control_ro(ctx, args)
  local value
  if args.enable == true then
    value = 0
  elseif args.enable == false then
    value = 1
  else
    ctx.error('Invalid value to write. Must be true or false')
  end

  if device then
    local err = device:write_holding(1, value)
    if err == 0 then
      return 'Reset counter command is sent'
    else
      ctx.error('Command failed, Modbus TCP error: ' .. tostring(err))
    end
  else
    ctx.error('Device connection is not configured')
  end
end

function toint32(data)
  return string.unpack('>I4', string.pack('>I2I2', data[1], data[2]))
end

---------------------------------
-- BWT Thero ModbusTCP API
---------------------------------

BwtTheroModbusTcp = {}

function BwtTheroModbusTcp.new(addr, unit_id)
  assert(type(addr) == 'string', 'addr (arg #1) must be string, given: ' .. inspect(addr))
  assert(type(unit_id) == 'number', 'unit_id (arg #2) must be number, given: ' .. inspect(unit_id))

  local self = setmetatable({}, { __index = BwtTheroModbusTcp })
  self.addr = addr
  self.unit_id = unit_id
  return self
end

function BwtTheroModbusTcp:connect()
  self.modbus = modbustcp.new(self.addr)
end

function BwtTheroModbusTcp:read_inputs(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(type(number) == 'number', 'number (arg #1) must be number, given: ' .. inspect(number))

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

function BwtTheroModbusTcp:write_holding(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(type(number) == 'number', 'number (arg #1) must be number, given: ' .. inspect(number))

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
