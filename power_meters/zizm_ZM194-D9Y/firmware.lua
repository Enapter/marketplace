local config = require('enapter.ucm.config')

BAUDRATE = 'baudrate'
ADDRESS = 'address'
PARITY = 'parity'

-- Default RS485 communication interface parameters
DATA_BITS = 8
STOP_BITS = 1

function main()
  config.init({
    [BAUDRATE] = { type = 'number', required = true, default = 9600 },
    [ADDRESS] = { type = 'number', required = true, default = 1 },
    [PARITY] = { type = 'string', required = true, default = 'N' },
  })

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local baudrate, parity = values[BAUDRATE], values[PARITY]

    local result = rs485.init(baudrate, DATA_BITS, parity, STOP_BITS)
    if result ~= 0 then
      enapter.log('RS485 init error: ' .. rs485.err_to_str(result), error, true)
    end
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({
    vendor = 'Zizm',
    model = 'ZM194-D9Y',
  })
end

function send_telemetry()
  local telemetry = {}
  local status = 'ok'

  local all_metrics = {
    voltage_a = {
      register_address = 0x0000,
      register_count = 2,
      fn = touint32,
    },
    voltage_b = {
      register_address = 0x0002,
      register_count = 2,
      fn = touint32,
    },
    voltage_c = {
      register_address = 0x0004,
      register_count = 2,
      fn = touint32,
    },
    line_voltage_ab = {
      register_address = 0x0006,
      register_count = 2,
      fn = touint32,
    },
    line_voltage_bc = {
      register_address = 0x0008,
      register_count = 2,
      fn = touint32,
    },
    line_voltage_ca = {
      register_address = 0x000A,
      register_count = 2,
      fn = touint32,
    },
    current_a = {
      register_address = 0x000C,
      register_count = 2,
      fn = touint32,
    },
    current_b = {
      register_address = 0x000E,
      register_count = 2,
      fn = touint32,
    },
    current_c = {
      register_address = 0x0010,
      register_count = 2,
      fn = touint32,
    },
    active_power_a = {
      register_address = 0x0012,
      register_count = 2,
      fn = touint32,
    },
    active_power_b = {
      register_address = 0x0014,
      register_count = 2,
      fn = touint32,
    },
    active_power_c = {
      register_address = 0x0016,
      register_count = 2,
      fn = touint32,
    },
    total_active_power = {
      register_address = 0x0018,
      register_count = 2,
      fn = touint32,
    },
    reactive_power_a = {
      register_address = 0x001A,
      register_count = 2,
      fn = touint32,
    },
    reactive_power_b = {
      register_address = 0x001C,
      register_count = 2,
      fn = touint32,
    },
    reactive_power_c = {
      register_address = 0x001E,
      register_count = 2,
      fn = touint32,
    },
    total_reactive_power = {
      register_address = 0x0020,
      register_count = 2,
      fn = touint32,
    },
    frequency = {
      register_address = 0x0032,
      register_count = 2,
      fn = touint32,
    },
    total_active_electric_energy = {
      register_address = 0x0038,
      register_count = 2,
      fn = touint32,
    },
    forward_active_electric_energy = {
      register_address = 0x003A,
      register_count = 2,
      fn = touint32,
    },
    reverse_active_electric_energy = {
      register_address = 0x003C,
      register_count = 2,
      fn = touint32,
    },
  }

  for name, metric in pairs(all_metrics) do
    if
      not add_to_telemetry(
        name,
        telemetry,
        metric.register_address,
        metric.register_count,
        metric.fn
      )
    then
      status = 'read_error'
    end
  end

  telemetry['status'] = status
  enapter.send_telemetry(telemetry)
end

function add_to_telemetry(metric_name, tbl, register_address, registers_count, fn)
  local address, err = config.read(ADDRESS)
  if err == nil then
    local data, result = modbus.read_holdings(address, register_address, registers_count, 1000)
    if data then
      tbl[metric_name] = fn(data) / 1000.0 -- coefficient 0.001 for all metrics
      return true
    else
      enapter.log(
        'Register ' .. register_address .. ' reading failed: ' .. modbus.err_to_str(result)
      )
    end
  end
  return false
end

function touint32(register)
  local raw_str =
    string.pack('BBBB', register[1] >> 8, register[1] & 0xff, register[2] >> 8, register[2] & 0xff)
  return string.unpack('>I2', raw_str)
end

main()
