local mpp_solar = require('mpp_solar')
local parser = require('parser')
local commands = require('commands')
local rules = require('rules')

function main()
  local err =
    rs232.init(mpp_solar.baudrate, mpp_solar.data_bits, mpp_solar.parity, mpp_solar.stop_bits)
  if err ~= 0 then
    enapter.log('RS232 init failed: ' .. rs232.err_to_str(err), 'error')
    enapter.send_telemetry({ status = 'error', alerts = { 'init_error' } })
    return
  end

  err = rules:load()
  if err then
    enapter.log('rules init failed: ' .. err, 'error')
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
  scheduler.add(10000, execute_rules)

  enapter.register_command_handler('set_output_priority', command_set_output_priority)
  enapter.register_command_handler('set_charger_priority', command_set_charger_priority)
  enapter.register_command_handler('set_rules', command_set_rules)
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

function execute_rules()
  rules:execute()
end

function command_set_charger_priority(ctx, args)
  command_set_priority(ctx, args, commands.set_priorities.charger)
end

function command_set_output_priority(ctx, args)
  command_set_priority(ctx, args, commands.set_priorities.output)
end

function command_set_priority(ctx, args, priorities)
  local args_priority = args['priority']
  if not args_priority then
    ctx.error("missed required argument 'priority'")
  end

  local priority_value = priorities.values[args_priority]
  if not priority_value then
    ctx.error('unsupported priority value: ' .. args_priority)
  end

  local result, err = mpp_solar:set_value(priorities.cmd .. priority_value)
  if not result then
    ctx.error(err)
  end
end

function command_set_rules(ctx, args)
  local args_rules = args['rules']
  if not args_rules then
    ctx.error("missed required argument 'rules'")
  end

  local tz_offset = args['tz_offset']
  local tz_offsets = args['tz_offsets']

  if tz_offset and tz_offsets then
    ctx.error("only one argument should pass 'tz_offset' or 'tz_offsets")
  end

  if tz_offset then
    tz_offsets = { { from = 0, offset = tz_offset } }
  end

  local parsed_rules, err = convert_and_validate_args_rules(args_rules)
  if err then
    ctx.error(err)
  end

  local err = rules:set(parsed_rules, tz_offsets)
  if err then
    ctx.error(err)
  end
end

function convert_and_validate_args_rules(args_rules)
  if args_rules == nil then
    return {}
  end

  if type(args_rules) ~= 'table' then
    return nil, "invalid type of 'rules', should be a 'table'"
  end

  local converted_rules = {}
  for i, r in ipairs(args_rules) do
    local action = r.action
    if not action then
      action = {}
    end

    local priorities
    if action.name == 'set_charger_priority' then
      priorities = commands.set_priorities.charger
    elseif action.name == 'set_output_priority' then
      priorities = commands.set_priorities.output
    else
      return nil, 'action is missed at rule #' .. i
    end

    local priority
    if action.arguments and action.arguments.priority then
      priority = action.arguments.priority
    else
      return nil, 'priority is missed at rule #' .. i
    end

    local priority_value = priorities.values[priority]
    if not priority_value then
      return nil, 'unsupported priority value at rule #' .. i
    end

    local condition = r.condition
    if not condition then
      return nil, 'condition is missed at rule #' .. i
    end

    if not condition.voltage_min and not condition.voltage_max then
      return nil, 'condition on voltage is missed at rule #' .. i
    end

    if
      (condition.time_min and not condition.time_max)
      or (condition.time_max and not condition.time_min)
    then
      return nil, 'condition on time should have both min and max at rule #' .. i
    end

    converted_rules[i] = {
      cmd = priorities.cmd .. priority_value,
      condition = condition,
    }
  end

  return converted_rules
end

function merge_tables(t1, t2)
  for key, value in pairs(t2) do
    t1[key] = value
  end
end

main()
