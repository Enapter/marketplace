-- RS485 communication interface parameters
BAUD_RATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 2

function main()
  local result_comm = rs485.init(BAUD_RATE, DATA_BITS, PARITY, STOP_BITS)
  if result_comm ~= 0 then
    enapter.log("RS485 init failed: " .. rs485.err_to_str(result_comm), "error")
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({vendor = "Mercury", model = "230"})
end

function send_telemetry()
  local ADDRESS = 0
  local TIMEOUT = 1000
  local TRANSFORMATION_COEFFICIENT = 120

  local telemetry = {}
  local alerts = {}
  local status = "ok"

  -- You have to send login request in order to read data from Mercury 230
  -- 00 00 01 B0 - valid response for login
  local login = {0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01}
  send_and_receive(ADDRESS, login, TIMEOUT)

  local voltage_l1 = {0x08, 0x11, 0x11}
  local voltage_l2 = {0x08, 0x11, 0x12}
  local voltage_l3 = {0x08, 0x11, 0x13}
  local current_l1 = {0x08, 0x11, 0x21}
  local current_l2 = {0x08, 0x11, 0x22}
  local current_l3 = {0x08, 0x11, 0x23}
  local frequency = {0x08, 0x11, 0x40}
  local active_power = {0x08, 0x16, 0x00}
  local total_energy = {0x05, 0x00, 0x00}
  local total_energy_by_phases = {0x05, 0x60, 0x00}

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, voltage_l1, TIMEOUT)
    local bytes = totable(data)
    telemetry["l1n_volt"] = parse_4_bytes(bytes) / 100
  end)
  if not ok then
    enapter.log("Phase 1 voltage reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, voltage_l2, TIMEOUT)
    local bytes = totable(data)
    telemetry["l2n_volt"] = parse_4_bytes(bytes) / 100
  end)
  if not ok then
    enapter.log("Phase 2 voltage reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, voltage_l3, TIMEOUT)
    local bytes = totable(data)
    telemetry["l3n_volt"] = parse_4_bytes(bytes) / 100
  end)
  if not ok then
    enapter.log("Phase 3 voltage reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, current_l1, TIMEOUT)
    local bytes = totable(data)
    telemetry["current_l1"] = parse_4_bytes(bytes) / 1000  * TRANSFORMATION_COEFFICIENT
  end)
  if not ok then
    enapter.log("Phase 1 current reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, current_l2, TIMEOUT)
    local bytes = totable(data)
    telemetry["current_l2"] = parse_4_bytes(bytes) / 1000  * TRANSFORMATION_COEFFICIENT
  end)
  if not ok then
    enapter.log("Phase 2 current reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, current_l3, TIMEOUT)
    local bytes = totable(data)
    telemetry["current_l3"] = parse_4_bytes(bytes) / 1000  * TRANSFORMATION_COEFFICIENT
  end)
  if not ok then
    enapter.log("Phase 3 current reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, frequency, TIMEOUT)
    local bytes = totable(data)
    telemetry["frequency"] = parse_4_bytes(bytes) / 100
  end)
  if not ok then
    enapter.log("Frequency reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, active_power, TIMEOUT)
    local bytes = totable(data)
    local bytes_total = slice(bytes, 2, 4)
    table.insert(bytes_total, 1, 0)
    local bytes_l1 = slice(bytes, 5, 7)
    table.insert(bytes_l1, 1, 0)
    local bytes_l2 = slice(bytes, 8, 10)
    table.insert(bytes_l2, 1, 0)
    local bytes_l3 = slice(bytes, 11, 13)
    table.insert(bytes_l3, 1, 0)

    telemetry["total_power"] = parse_4_bytes(bytes_total) * TRANSFORMATION_COEFFICIENT / 100
    telemetry["power_l1"] = parse_4_bytes(bytes_l1) * TRANSFORMATION_COEFFICIENT / 100
    telemetry["power_l2"] = parse_4_bytes(bytes_l2) * TRANSFORMATION_COEFFICIENT / 100
    telemetry["power_l3"] = parse_4_bytes(bytes_l3) * TRANSFORMATION_COEFFICIENT / 100
  end)
  if not ok then
    enapter.log("Power reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, total_energy, TIMEOUT)
    local bytes = totable(data)
    local bytes_total = slice(bytes, 2, 5)
    telemetry["total_energy_since_reset"] = parse_4_bytes(bytes_total) * TRANSFORMATION_COEFFICIENT
  end)
  if not ok then
    enapter.log("Total energy reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  local ok, err = pcall(function()
    local data = send_and_receive(ADDRESS, total_energy_by_phases, TIMEOUT)
    local bytes = totable(data)
    local bytes_l1 = slice(bytes, 2, 5)
    local bytes_l2 = slice(bytes, 6, 9)
    local bytes_l3 = slice(bytes, 10, 13)
    telemetry["total_energy_l1"] = parse_4_bytes(bytes_l1) * TRANSFORMATION_COEFFICIENT
    telemetry["total_energy_l2"] = parse_4_bytes(bytes_l2) * TRANSFORMATION_COEFFICIENT
    telemetry["total_energy_l3"] = parse_4_bytes(bytes_l3) * TRANSFORMATION_COEFFICIENT
  end)
  if not ok then
    enapter.log("Total energy by phases reading failed: "..err, "error")
    alerts = {"communication_failed"}
    status = "read_error"
  end

  telemetry["alerts"] = alerts
  telemetry["status"] = status

  enapter.send_telemetry(telemetry)
end

function send_and_receive(ADDRESS, command, TIMEOUT)
  -- sample request: string.pack('<BBBBBBBBBBB', 00, 01, 01, 01, 01, 01, 01, 01, 01, 0x77, 0x81)
  local cmd = {}
  table.insert(cmd, ADDRESS)

  for _, query in pairs(command) do
    table.insert(cmd, query)
  end

  local crc = crc16(cmd)

  local request = ''
  for _, byte in pairs(cmd) do
    request = request .. string.pack('B', byte)
  end

  request = request .. string.pack('B', crc & 0x00FF)
  request = request .. string.pack('B', (crc & 0xFF00) >> 8)

  local result = rs485.send(request)
  if result ~= 0 then
    enapter.log("RS485 send command failed: " .. rs485.err_to_str(result), "error")
    return
  end

  local data, result = rs485.receive(TIMEOUT)
  if result ~= 0 then
    enapter.log("RS485 receive command failed: " .. rs485.err_to_str(result), "error")
    return
  end

  if not data then
    enapter.log('No data received: result='..tostring(result), 'error')
    return
  end

  return data
end

function totable(data)
  local bytes = { string.byte(data, 1, -1) }
  return bytes
end

function slice(t, start_i, stop_i)
  local new_table = {}
  for i = start_i, stop_i do
    table.insert(new_table, t[i])
  end
  return new_table
end

function parse_4_bytes(bytes)
  local result = 0x00000000
  result = result | (bytes[2] << 24)
  result = result | ((bytes[1] << 16) & 0x00ff0000)
  result = result | ((bytes[4] << 8) & 0x0000ff00)
  result = result | bytes[3]
  return result
end

function crc16(pck)
  local result = 0xFFFF
  for i = 1, #pck do
    result = result ~ pck[i]
    for _ = 1, 8 do
      if ((result & 0x01) == 1) then
        result = (result >> 1) ~ 0xA001
      else
        result = result >> 1
      end
    end
  end
  return result
end

main()
