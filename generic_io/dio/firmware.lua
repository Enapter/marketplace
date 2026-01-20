-- Lua script implements device interface declared in the manifest file
-- using Lua programming language.
--
-- See https://developers.enapter.com/docs/reference/vucm/enapter

local arg_required_number_err_msg = 'arg is required and must be a number'

function main()
  enapter.register_command_handler('close', command_close)
  enapter.register_command_handler('open', command_open)

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Welotec', model = 'Arrakis MK series' })
end

function send_telemetry()
  local telemetry = {}
  local status = 'ok'

  for input = 1, 4 do
    local state, res = dio.input(input)
    if res and res ~= 0 then
      status = 'error'
      enapter.log(
        'failed to get state for input' .. input .. ' ' .. dio.err_to_str(res),
        'error'
      )
    else
      telemetry['di' .. input ] = (state == dio.HIGH)
    end
  end

  telemetry['status'] = status
  enapter.send_telemetry(telemetry)
end

function command_open(ctx, args)
  if not args.output or type(args.output) ~= 'number' then
    ctx.error('output ' .. arg_required_number_err_msg)
  end

  local state, res = dio.output(math.tointeger(args.output), dio.LOW)
  if res and res ~= 0 then
    ctx.error(dio.err_to_str(res))
  end
  return { level = state }
end

function command_close(ctx, args)
  if not args.output or type(args.output) ~= 'number' then
    ctx.error('output ' .. arg_required_number_err_msg)
  end

  local state, res = dio.output(math.tointeger(args.output), dio.HIGH)
  if res and res ~= 0 then
    ctx.error(dio.err_to_str(res))
  end
  return { level = state }
end

main()
