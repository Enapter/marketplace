-- Default RS485 communication interface parameters
BAUD_RATE = 19200
DATA_BITS = 8
PARITY = 'E'
STOP_BITS = 1
ADDRESS = 1

function main()
  local result = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS485 init error: " .. rs485.err_to_str(result), error, true)
  end
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  local data, result = modbus.read_holdings(ADDRESS, 49, 20, 1000)
  if data then
    enapter.send_properties({
      vendor = "Schneider Electric",
      model = get_model(data) })
  else
    enapter.log("Register 50 reading failed: "..modbus.err_to_str(result))
  end
end

function send_telemetry()
  local telemetry = {}
  local status = "ok"

  local all_metrics = {
    current_a = {
      register_address = 2999,
      register_count = 2,
      fn = tofloat
    },
    current_b = {
      register_address = 3001,
      register_count = 2,
      fn = tofloat
    },
    current_c = {
      register_address = 3003,
      register_count = 2,
      fn = tofloat
    },
    voltage_a = {
      register_address = 3027,
      register_count = 2,
      fn = tofloat
    },
    voltage_b = {
      register_address = 3029,
      register_count = 2,
      fn = tofloat
    },
    voltage_c = {
      register_address = 3031,
      register_count = 2,
      fn = tofloat
    },
    active_power_a = {
      register_address = 3053,
      register_count = 2,
      fn = tofloat
    },
    active_power_b = {
      register_address = 3055,
      register_count = 2,
      fn = tofloat
    },
    active_power_c = {
      register_address = 3057,
      register_count = 2,
      fn = tofloat
    },
    total_active_power = {
      register_address = 3059,
      register_count = 2,
      fn = tofloat
    },
    frequency = {
      register_address = 3109,
      register_count = 2,
      fn = tofloat
    },
    active_energy_delivered_and_received = {
      register_address = 2703,
      register_count = 2,
      fn = tofloat
    },
  }

  for name, metric in pairs(all_metrics) do
    if not add_to_telemetry(
      name, telemetry, metric.register_address,
      metric.register_count, metric.fn
    ) then
      status = 'read_error'
    end
  end

  telemetry["status"] = status
  enapter.send_telemetry(telemetry)
end

function add_to_telemetry(metric_name, tbl, register_address, registers_count, fn)
  local data, result = modbus.read_holdings(ADDRESS, register_address, registers_count, 1000)
  if data then
    tbl[metric_name] = fn(data)
  else
    enapter.log("Register "..register_address.." reading failed: "..modbus.err_to_str(result))
    return false
  end
  return true
end

function get_model(data)
  local model = ''
  for _, register in pairs(data) do
    if register ~= 0 then
      model = model..string.char(register >> 8)
      model = model..string.char(register & 0xFF)
    else
      break
    end
  end
  return model
end

function tofloat(register)
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">f", raw_str)
end


main()
