local mpp_solar = require('mpp_solar')
local parser = require('parser')

function main()
  local err =
    rs232.init(mpp_solar.baudrate, mpp_solar.data_bits, mpp_solar.parity, mpp_solar.stop_bits)
  if err ~= 0 then
    enapter.log('RS232 init failed: ' .. rs232.err_to_str(err), 'error')
    enapter.send_telemetry({ status = 'error', alerts = { 'init_error' } })
    return
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('get_parallel_info', command_get_parallel_device_info)
end

local max_parallel_number = nil

function send_properties()
  local properties = {}

  max_parallel_number = parser:get_max_parallel_number()

  if not max_parallel_number then
    enapter.send_properties(properties)
    return
  else
    properties['max_parallel_num'] = max_parallel_number

    local data, err = parser:get_device_model()
    if data then
      properties['model'] = data
    else
      enapter.log('Can not get device model: ' .. err, 'error')
    end

    local data, err = parser:get_firmware_version()
    if data then
      properties['fw_ver'] = data
    else
      enapter.log('Can not get device firmware version: ' .. err, 'error')
    end

    local data, err = parser:get_protocol_version()
    if data then
      properties['protocol_ver'] = data
    else
      enapter.log('Can not get device protocol version: ' .. err, 'error')
    end

    enapter.send_properties(properties)
  end
end

function send_telemetry()
  local telemetry = {}

  if not max_parallel_number then
    enapter.send_telemetry({ status = 'no_data', alerts = { 'no_data' } })
    return
    -- check output mode instead
  elseif max_parallel_number == 0 then
    enapter.send_telemetry({ status = 'no_data', alerts = { 'single_mode' } })
    return
  else
    local data, err = parser:get_all_parallel_info(max_parallel_number)
    if data then
      merge_tables(telemetry, data)
      telemetry['status'] = parser:get_device_mode()
    else
      enapter.log('Failed to get parallel info: ' .. err, 'error')
      enapter.send_telemetry({ status = 'no_data', alerts = { 'no_data' } })
      return
    end
    enapter.send_telemetry(telemetry)
  end
end

function command_get_parallel_device_info(ctx, args)
  if args['device'] then
    return parser:get_parallel_info(math.floor(args['device']))
  else
    ctx.error("No device's number in arguments")
  end
end

function merge_tables(t1, t2)
  for key, value in pairs(t2) do
    t1[key] = value
  end
end

main()
