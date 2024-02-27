local voltronic = require('voltronic')
local parser = require('parser')

function main()
  local err = rs232.init(voltronic.baudrate, voltronic.data_bits, voltronic.parity, voltronic.stop_bits)
  if err ~= 0 then
    enapter.log('RS232 init failed: ' .. rs232.err_to_str(err), 'error')
    enapter.send_telemetry({ status = 'Error', alerts = { 'init_error' } })
    return
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  local properties = {}
  local result
  local data

  result, data = parser:get_protocol_version()
  if result then
    properties['serial_num'] = data
  end

  result, data = parser:get_serial_number()
  if result then
    properties['protocol_ver'] = data
  end

  result, data = parser:get_firmware_version()
  if result then
    properties['fw_ver'] = data
  end

  enapter.send_properties(properties)
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}

  local data, err = parser:get_device_general_status_params()
  if data then
    merge_tables(telemetry, data)
  else
    enapter.log('Failed to get general status params: ' .. err, 'error')
  end

  local data = parser:get_device_alerts()
  if data then
    alerts = data
  end

  if telemetry['status'] then
    if string.sub(telemetry['status'], 2, 2) == '1' then
      telemetry['status'] = 'Charging'
    else
      telemetry['status'] = 'Not Charging'
    end
  else
    telemetry['status'] = 'Error'
  end

  telemetry['alerts'] = alerts
  enapter.send_telemetry(telemetry)
  collectgarbage()
end

function merge_tables(t1, t2)
  for key, value in pairs(t2) do
    t1[key] = value
  end
end

main()
