local config = require('enapter.ucm.config')

VENDOR = 'InfraSensing'
MODEL = 'ENV-THUM'

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
IP_ADDRESS_CONFIG = 'ip_address'
MODBUS_PORT_CONFIG = 'modbus_port'
UNIT_ID_CONFIG = 'modbus_unit_id'
NODE_CONFIG = 'node'

-- Initiate device firmware. Called at the end of the file.
function main()
  config.init({
    [IP_ADDRESS_CONFIG] = { type = 'string', required = true, default = '192.168.11.160' },
    [UNIT_ID_CONFIG] = { type = 'number', required = true, default = 1 },
    [MODBUS_PORT_CONFIG] = { type = 'number', required = true, default = 502 },
    [NODE_CONFIG] = { type = 'number', required = true, default = 7 },
  })

  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)
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

  local node, err = config.read(NODE_CONFIG)
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    enapter.send_telemetry({ status = 'error', alerts = { 'cannot_read_config' } })
  else
    local telemetry = {}
    local alerts = {}
    local status = 'ok'

    for i = 0, node do
      if i == 1 then
        goto continue
      end

      local data = device:read_inputs(200 + i * 32, 2)
      if data then
        telemetry['value' .. i] = toFloat32(data)
      else
        status = 'no_data'
      end

      local data = device:read_inputs(201 + i * 32, 1)
      if data then
        telemetry['type' .. i] = get_type(data[1])
      else
        status = 'no_data'
      end
      ::continue::
    end

    telemetry.alerts = alerts
    telemetry.status = status
    enapter.send_telemetry(telemetry)
  end
end

function send_properties()
  local properties = {}

  properties.vendor = VENDOR
  properties.model = MODEL

  enapter.send_properties(properties)
end

function get_type(val)
  local types = {
    [1] = 'Temperature',
    [2] = 'Humidity',
    [3] = 'Airflow',
    [4] = 'Shock',
    [5] = 'Dust',
    [7] = 'Sound Pressure',
    [8] = 'Power Failure Sensor',
    [9] = 'Leak',
    [10] = 'CO',
    [11] = 'Air Pressure',
    [12] = 'Security',
    [13] = 'Dewpoint',
    [14] = 'Fuel Level (Fuel Level Sensor)',
    [15] = 'Flow Rate (Fuel Level Sensor)',
    [16] = 'Resistance',
    [17] = 'TVOC',
    [18] = 'CO2',
    [19] = 'Motion (EXP4HUB)',
    [20] = 'O2',
    [21] = 'Light',
    [22] = 'CO',
    [23] = 'HF',
    [24] = 'Volt (AC/DC Power Sensor)',
    [25] = 'Amp (AC/DC Power Sensor)',
    [26] = 'Watt (AC/DC Power Sensor)',
    [27] = 'Watthour (AC/DC Power Sensor)',
    [28] = 'Ping',
    [29] = 'H2',
    [30] = 'Voltage Status',
    [31] = 'THD',
    [32] = 'Frequency',
    [33] = 'Location and Distance',
    [34] = 'Tilt (Inclination)',
    [35] = 'Particle(PM)',
    [36] = 'Radon',
    [37] = 'kW (AC Meter3 Power)',
    [38] = 'kWh (AC Meter 3 energy)',
  }
  return types[val]
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
    local address, unit_id, port = values[IP_ADDRESS_CONFIG], values[UNIT_ID_CONFIG], values[MODBUS_PORT_CONFIG]
    if not address or not unit_id or not port then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      device = SensorGwModbusTcp.new(address .. ':' .. math.floor(port), tonumber(unit_id))
      enapter.log(address .. ':' .. math.floor(port))
      device:connect()
      return device, nil
    end
  end
end

function toFloat32(data)
  local raw_str = string.pack('BBBB', data[1] >> 8, data[1] & 0xff, data[2] >> 8, data[2] & 0xff)
  return string.unpack('>f', raw_str)
end

-----------------------------------------------
-- InfraSensing SensorGateway Modbus TCP API --
-----------------------------------------------

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
    enapter.log('Read input register ' .. tostring(address) .. ' read error: ' .. err, 'error')
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
    enapter.log('Read input status register ' .. tostring(address) .. ' read error: ' .. err, 'error')
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
    enapter.log('Read holding register ' .. tostring(address) .. ' read error: ' .. err, 'error')
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
    enapter.log('Writ holding register ' .. tostring(address) .. ' write error: ' .. err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
  end
  return err
end

main()
