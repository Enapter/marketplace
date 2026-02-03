local modbus_client = nil
local conn_cfg = nil

function enapter.main()
  reconnect()
  configuration.after_write('connection', function()
    modbus_client = nil
    conn_cfg = nil
  end)

  scheduler.add(1000, reconnect)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('set_lower_start_limit', cmd_lower_start_limit)
  enapter.register_command_handler('set_higher_start_limit', cmd_higher_start_limit)
  enapter.register_command_handler('external_stop', cmd_external_stop)
end

function reconnect()
  if modbus_client then
    return
  end

  if not configuration.is_all_required_set('connection') then
    return
  end

  local config, err = configuration.read('connection')
  if err ~= nil then
    enapter.log('read configuration: ' .. err, 'error')
    return
  end
  conn_cfg = config

  modbus_client = modbus.new(conn_cfg.conn_str)
  if not modbus_client then
    enapter.log('connect: modbus.new failed', 'error')
    return
  end
end

function send_properties()
  enapter.send_properties({
    vendor = 'EFOY',
    model = 'H2 Cabinet N-Series',
  })
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', conn_alerts = { 'not_configured' } })
    return
  end

  if not modbus_client then
    enapter.send_telemetry({ status = 'conn_error', conn_alerts = { 'communication_failed' } })
    return
  end

  enapter.send_telemetry(read_telemetry())
end

function read_telemetry()
  local START_REG = 2
  local ALL_REGISTERS_COUNT = 102

  local FLOAT_REGISTERS = {
    hydrogen_inlet_pressure = { addr = 2, factor = 1000 },
    output_voltage = { addr = 4, factor = 1000 },
    output_current = { addr = 6, factor = 1000 },
    inlet_temperature = { addr = 8, factor = 100 },
    rating_fuel_cell_module0 = { addr = 12, factor = 1 },
    rating_fuel_cell_module1 = { addr = 14, factor = 1 },
    rating_fuel_cell_module2 = { addr = 16, factor = 1 },
    rating_fuel_cell_module3 = { addr = 18, factor = 1 },
    internal_hydrogen_pressure_rack0 = { addr = 62, factor = 1000 },
    battery_temperature = { addr = 72, factor = 100 },
    rack_temperature0 = { addr = 74, factor = 100 },
    lower_start_limit = { addr = 100, factor = 1000 },
    higher_start_limit = { addr = 102, factor = 1000 },
  }

  local INT_REGISTERS = {
    { addr = 53, parser = parse_emergency_signals },
    { addr = 55, parser = parse_warning_signals },
    { addr = 57, parser = parse_ready_signals },
    { addr = 59, parser = parse_fc_controller_data },
    { addr = 85, parser = parse_rack_data },
  }

  local data, err = modbus_client:read_holdings(conn_cfg.address, START_REG, ALL_REGISTERS_COUNT, 1000)
  if err then
    enapter.log('Failed to read data: ' .. err, 'error')
    return { status = 'conn_error', conn_alerts = { 'communication_failed' }, alerts = {} }
  end

  local telemetry = {}
  for name, reg in pairs(FLOAT_REGISTERS) do
    telemetry[name] = to_float(slice(data, reg.adrr - START_REG + 1, reg.addr)) * reg.factor
  end

  local alerts = {}
  for _, reg in pairs(INT_REGISTERS) do
    local signals = reg.parser(data[reg.adrr - START_REG + 1] or 0)
    for _, signal in ipairs(signals) do
      table.insert(alerts, signal)
    end
  end

  telemetry.status = 'ok'
  telemetry.alerts = alerts
  telemetry.conn_alerts = {}
  return telemetry
end

function cmd_lower_start_limit(ctx, args)
  if not args.limit then
    ctx.error('Missing argument: limit')
  end

  if not modbus_client then
    reconnect()
  end

  if not modbus_client then
    ctx.error('Modbus not initialized')
  end

  local values = to_int32_pair(math.floor(tonumber(args.limit) * 1000))
  local err = modbus_client:write_multiple_holdings(conn_cfg.address, 400, values, 1000)

  if err then
    ctx.error('Failed: ' .. tostring(err))
  else
    ctx.log('Lower start limit set to ' .. args.limit .. 'V')
  end
end

function cmd_higher_start_limit(ctx, args)
  if not args.limit then
    ctx.error('Missing argument: limit')
  end

  if not modbus_client then
    reconnect()
  end

  if not modbus_client then
    ctx.error('Modbus not initialized')
  end

  local values = to_int32_pair(math.floor(tonumber(args.limit) * 1000))
  local err = modbus_client:write_multiple_holdings(conn_cfg.address, 402, values, 1000)

  if err then
    ctx.error('Failed: ' .. tostring(err))
  else
    ctx.log('Higher start limit set to ' .. args.limit .. 'V')
  end
end

function cmd_external_stop(ctx, args)
  if not args.action then
    ctx.error('Missing argument: action')
  end

  if not modbus_client then
    reconnect()
  end

  if not modbus_client then
    ctx.error('Modbus not initialized')
  end

  local action_value = args.action == 'auto' and 0 or 1
  local err = modbus_client:write_holding(conn_cfg.address, 451, action_value, 1000)

  if err then
    ctx.error('Failed: ' .. tostring(err))
  else
    ctx.log('External stop set to ' .. args.action)
  end
end

function to_float(registers)
  if not registers or #registers < 2 then
    return 0.0
  end
  local raw_str = string.pack(
    'BBBB',
    (registers[1] >> 8) & 0xff,
    registers[1] & 0xff,
    (registers[2] >> 8) & 0xff,
    registers[2] & 0xff
  )
  return string.unpack('>f', raw_str)
end

function to_int32_pair(value)
  local packed = string.pack('>f', tonumber(value))
  local b1, b2, b3, b4 = string.unpack('BBBB', packed)
  return { (b1 << 8) | b2, (b3 << 8) | b4 }
end

function parse_emergency_signals(value)
  return parse_int_register(53, value)
end

function parse_warning_signals(value)
  return parse_int_register(55, value)
end

function parse_ready_signals(value)
  return parse_int_register(57, value)
end

function parse_fc_controller_data(value)
  return parse_int_register(59, value)
end

function parse_rack_data(value)
  return parse_int_register(85, value)
end

function parse_int_register(addr, value)
  local signals = {}
  local bits_map = {}

  if addr == 53 then
    bits_map = { emergency_module0 = 0, emergency_module1 = 1, emergency_module2 = 2, emergency_module3 = 3 }
  elseif addr == 55 then
    bits_map = { warning_module0 = 0, warning_module1 = 1, warning_module2 = 2, warning_module3 = 3 }
  elseif addr == 57 then
    bits_map = { ready_module0 = 0, ready_module1 = 1, ready_module2 = 2, ready_module3 = 3 }
  elseif addr == 59 then
    bits_map = { alarm = 0, warning = 1, fc_status = 2, fc_running = 3, filter_change = 5 }
  elseif addr == 85 then
    bits_map = { ventilation0 = 0, heating0 = 5 }
  end

  for signal_name, bit_pos in pairs(bits_map) do
    if (value & (1 << bit_pos)) ~= 0 then
      table.insert(signals, signal_name)
    end
  end

  return signals
end

function slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced + 1] = tbl[i]
  end

  return sliced
end
