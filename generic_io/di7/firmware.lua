local config = require('enapter.ucm.config')

local arg_required_number_err_msg = 'arg is required and must be a number'
local cfg_debounce_delay_err_msg = 'config debounce delay failed: '

local debounce_delay_time_number_units = 100

DEBOUNCE_DELAY_US_CONFIG = 'debounce_delay'

function main()
  config.init({
    [DEBOUNCE_DELAY_US_CONFIG] = { type = 'number', default = 100 },
  }, {
    before_write = validate_config,
    after_write = setup_di7,
  })

  local args, err = config.read_all()
  if err == nil then
    err = setup_di7(args)
  end

  if err ~= nil then
    enapter.log(err, 'error', true)
  end

  enapter.register_command_handler('is_closed', command_is_closed)
  enapter.register_command_handler('is_opened', command_is_opened)
  enapter.register_command_handler('read_counter', command_read_counter)
  enapter.register_command_handler('set_counter', command_set_counter)

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'Generic-DI7' })
end

function send_telemetry()
  local telemetry = {}
  local status = 'ok'

  for input = 1, 7 do
    local state, res = di7.is_closed(input)
    if res and res ~= 0 then
      status = 'error'
      enapter.log(
        'failed to get closed state for input' .. input .. ' ' .. di7.err_to_str(res),
        'error'
      )
    else
      telemetry['di' .. input .. '_is_closed'] = state
    end

    local counter
    local reset_time

    counter, reset_time, res = di7.read_counter(input)
    if res and res ~= 0 then
      status = 'error'
      enapter.log(
        'failed to read counter for input' .. input .. ' ' .. di7.err_to_str(res),
        'error'
      )
    else
      telemetry['di' .. input .. '_counter'] = counter
      telemetry['di' .. input .. '_reset_time'] = reset_time
    end
  end

  telemetry['status'] = status
  enapter.send_telemetry(telemetry)
end

function validate_config(args)
  local delay = math.tointeger(args[DEBOUNCE_DELAY_US_CONFIG])
  if delay == nil then
    return cfg_debounce_delay_err_msg .. 'value should be an integer'
  end

  if (delay % debounce_delay_time_number_units) ~= 0 or delay > 100000 then
    return cfg_debounce_delay_err_msg
      .. 'value should be a multiple of 100 and less or equal 100000'
  end
end

function setup_di7(args)
  local delay = math.tointeger(args[DEBOUNCE_DELAY_US_CONFIG])
  if delay == nil then
    return cfg_debounce_delay_err_msg .. 'value should be an integer'
  end

  local res = di7.set_debounce(math.tointeger(delay / debounce_delay_time_number_units))
  if res and res ~= 0 then
    return 'set debounce failed: ' .. di7.err_to_str(res)
  end
end

function command_is_closed(ctx, args)
  if not args.input or type(args.input) ~= 'number' then
    ctx.error('input ' .. arg_required_number_err_msg)
  end

  local state, res = di7.is_closed(math.tointeger(args.input))
  if res and res ~= 0 then
    ctx.error(di7.err_to_str(res))
  end

  return { closed = state }
end

function command_is_opened(ctx, args)
  if not args.input or type(args.input) ~= 'number' then
    ctx.error('input ' .. arg_required_number_err_msg)
  end

  local state, res = di7.is_opened(math.tointeger(args.input))
  if res and res ~= 0 then
    ctx.error(di7.err_to_str(res))
  end

  return { opened = state }
end

function command_read_counter(ctx, args)
  if not args.input or type(args.input) ~= 'number' then
    ctx.error('input' .. arg_required_number_err_msg)
  end

  local counter, reset_time, res = di7.read_counter(math.tointeger(args.input))
  if res and res ~= 0 then
    ctx.error(di7.err_to_str(res))
  end

  return { counter = counter, reset_time = reset_time }
end

function command_set_counter(ctx, args)
  if not args.input or type(args.input) ~= 'number' then
    ctx.error('input ' .. arg_required_number_err_msg)
  end

  if not args.count or type(args.count) ~= 'number' then
    ctx.error('count ' .. arg_required_number_err_msg)
  end

  local res = di7.set_counter(math.tointeger(args.input), math.tointeger(args.count))
  if res and res ~= 0 then
    ctx.error(di7.err_to_str(res))
  end
end

main()
