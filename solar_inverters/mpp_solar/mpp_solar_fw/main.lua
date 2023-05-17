local mpp_solar = require('mpp_solar')
local parser = require('parser')
local commands = require('commands')

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

  enapter.register_command_handler('set_output_priority', command_set_output_priority)
  enapter.register_command_handler('set_charger_priority', command_set_charger_priority)
end

local max_parallel_number = nil

function send_properties()
  local properties = {}

  max_parallel_number = parser:get_max_parallel_number()

  if not max_parallel_number then
    enapter.send_properties(properties)
    return
  else
    local scheme = parser:get_connection_scheme(max_parallel_number)
    if max_parallel_number == 0 then
      properties['serial_num'] = scheme['0']['sn']
      properties['output_mode'] = parser:get_output_mode(scheme['0']['out_mode'])
    else
      properties['output_mode'] = parser:get_output_mode(scheme['0']['out_mode'])
      enapter.send_properties(properties)
      return
    end

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
  local rules_available = true
  local telemetry = {}
  local alerts = {}

  if not max_parallel_number then
    enapter.send_telemetry({ status = 'no_data', alerts = { 'no_data' } })
    return
  elseif max_parallel_number > 2 then
    enapter.send_telemetry({ status = 'no_data', alerts = { 'parallel_mode' } })
    return
  else
    local data, err = parser:get_device_general_status_params()
    if data then
      merge_tables(telemetry, data)
    else
      enapter.log('Failed to get general status params: ' .. err, 'error')
    end
  end

  local data, err = parser:get_device_rating_info()
  if data then
    merge_tables(telemetry, data)
  else
    enapter.log('Failed to get device rating info: ' .. err, 'error')
    rules_available = false
  end

  local status = parser:get_device_mode()
  telemetry['status'] = status
  if status == 'unknown' then
    rules_available = false
  end

  local data = parser:get_device_alerts()
  if data then
    alerts = table.move(data, 1, #data, #alerts + 1, alerts)
  end

  if not rules_available then
    table.insert(alerts, 'rules_unavailable')
  end

  telemetry['alerts'] = alerts
  enapter.send_telemetry(telemetry)
  collectgarbage()
end

local priorities = commands.set_priorities

function command_set_charger_priority(ctx, args)
  local values = priorities.charger.values

  if args['priority'] then
    local result, err = set_charger_priority(values[args['priority']])
    if not result then
      ctx.error(err)
    end
  else
    ctx.error('No arguments')
  end
end

function command_set_output_priority(ctx, args)
  local values = priorities.output.values

  if args['priority'] then
    local result, err = set_output_priority(values[args['priority']])
    if not result then
      ctx.error(err)
    end
  else
    ctx.error('No arguments')
  end
end

function set_charger_priority(priority)
  return mpp_solar:set_value(priorities.charger.cmd .. priority)
end

function set_output_priority(priority)
  return mpp_solar:set_value(priorities.output.cmd .. priority)
end

function merge_tables(t1, t2)
  for key, value in pairs(t2) do
    t1[key] = value
  end
end

main()
