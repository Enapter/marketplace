local fault_flag_alerts = require('fault_flag_alerts')

local RX_SCALE_FACTOR_10 = 10.0
local RX_SCALE_FACTOR_100 = 100.0

local can_client = nil
local can_monitor = nil
local power_relay = nil
local start_relay = nil
local conn_cfg = nil
local message_specs = nil

function enapter.main()
  reconnect_can()
  reconnect_relays()

  configuration.after_write('connection', function()
    can_client = nil
    can_monitor = nil
    power_relay = nil
    start_relay = nil
    conn_cfg = nil
    message_specs = nil
  end)

  scheduler.add(1000, reconnect_can)
  scheduler.add(1000, reconnect_relays)
  scheduler.add(5000, send_properties)
  scheduler.add(1000, send_telemetry)

  enapter.register_command_handler('start', cmd_start)
  enapter.register_command_handler('stop', cmd_stop)
  enapter.register_command_handler('power_on', cmd_power_on)
  enapter.register_command_handler('power_off', cmd_power_off)
end

function reconnect_can()
  if can_client then
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

  local client, err = can.new(conn_cfg.can_connection_uri)
  if err then
    enapter.log('failed to create CAN client: ' .. err, 'error')
    return
  end

  build_message_specs()

  if not message_specs then
    enapter.log('failed to create CAN monitor: empty message specs', 'error')
    return
  end

  local all_msg_ids = {}
  local seen_ids = {}
  for _, group_messages in pairs(message_specs) do
    for _, msg_spec in ipairs(group_messages) do
      if not seen_ids[msg_spec.msg_id] then
        table.insert(all_msg_ids, msg_spec.msg_id)
        seen_ids[msg_spec.msg_id] = true
      end
    end
  end

  local monitor, err = client:monitor(all_msg_ids)
  if err then
    enapter.log('failed to create CAN monitor: ' .. err, 'error')
    return
  end

  can_client = client
  can_monitor = monitor
end

function reconnect_relays()
  if not configuration.is_all_required_set('connection') then
    return
  end

  local config, err = configuration.read('connection')
  if err ~= nil then
    enapter.log('read configuration: ' .. err, 'error')
    return
  end
  conn_cfg = config

  if not power_relay then
    local client, err = relay.new(conn_cfg.power_relay_connection_uri)
    if err then
      enapter.log('failed to create power relay client: ' .. err, 'error')
      return
    end
    power_relay = client
  end

  if not start_relay then
    local client, err = relay.new(conn_cfg.start_relay_connection_uri)
    if err then
      enapter.log('failed to create start relay client: ' .. err, 'error')
      return
    end
    start_relay = client
  end
end

function send_properties()
  if not can_client or not can_monitor then
    return
  end

  local info = { vendor = 'Intelligent Energy', model = 'FCM 804' }
  local can_props, err = read_can_messages('properties')
  if err then
    enapter.log(err, 'info')
  else
    for k, v in pairs(can_props) do
      info[k] = v
    end
  end
  enapter.send_properties(info)
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ status = 'error', conn_alerts = { 'not_configured' } })
    return
  end

  if not can_client or not can_monitor then
    enapter.send_telemetry({ status = 'error', conn_alerts = { 'communication_failed' } })
    return
  end

  local telemetry, err = read_can_messages('telemetry')
  if err then
    enapter.send_telemetry({
      status = 'error',
      conn_alerts = { 'communication_failed' },
      alert_details = { communication_failed = { errmsg = err } },
    })
    return
  end

  local is_empty = next(telemetry) == nil
  if is_empty then
    telemetry = { alerts = {} }
  else
    telemetry.alerts = fault_flag_alerts.make_from_telemetry(telemetry)
  end

  local powered, err = get_relay_state(power_relay)
  if err then
    enapter.log('failed to get power relay state: ' .. tostring(err), 'error')
  else
    telemetry.powered = powered
  end

  local started, err = get_relay_state(start_relay)
  if err then
    enapter.log('failed to get start relay state: ' .. tostring(err), 'error')
  else
    telemetry.started = started
  end

  telemetry.conn_alerts = {}
  enapter.send_telemetry(telemetry)
end

function build_message_specs()
  if message_specs then
    return
  end

  if not conn_cfg then
    enapter.log('cannot build message specs: no config', 'error')
    return
  end

  local can_idx = conn_cfg.can_index

  message_specs = {
    properties = {
      { name = 'fw_ver', msg_id = 0x318 + can_idx - 1, parser = software_version },
      {
        name = 'serial_number',
        msg_id = 0x310 + can_idx - 1,
        multi_msg = true,
        parser = make_serial_number_parser(),
      },
    },
    telemetry = {
      {
        names = { 'run_hours', 'total_run_energy' },
        msg_id = 0x320 + can_idx - 1,
        parser = bytes_extractor({
          { type = 'uint32', from = 1, to = 4 },
          { type = 'uint32', from = 5, to = 8 },
        }),
      },
      {
        names = { 'fault_flags_a', 'fault_flags_b' },
        msg_id = 0x328 + can_idx - 1,
        parser = bytes_extractor({
          { type = 'uint32', from = 1, to = 4 },
          { type = 'uint32', from = 5, to = 8 },
        }),
      },
      {
        names = { 'fault_flags_c', 'fault_flags_d' },
        msg_id = 0x378 + can_idx - 1,
        parser = bytes_extractor({
          { type = 'uint32', from = 1, to = 4 },
          { type = 'uint32', from = 5, to = 8 },
        }),
      },
      {
        names = { 'output_power', 'output_voltage', 'output_current', 'hydrogen_inlet_pressure' },
        msg_id = 0x338 + can_idx - 1,
        parser = bytes_extractor({
          { type = 'int16', from = 1, to = 2 },
          { type = 'int16', from = 3, to = 4, scale_factor = RX_SCALE_FACTOR_100 },
          { type = 'int16', from = 5, to = 6, scale_factor = RX_SCALE_FACTOR_100 },
          { type = 'int16', from = 7, to = 8, scale_factor = RX_SCALE_FACTOR_10 },
        }),
      },
      {
        names = { 'outlet_temperature', 'inlet_temperature', 'dcdc_volt_setpoint', 'dcdc_amp_limit' },
        msg_id = 0x348 + can_idx - 1,
        parser = bytes_extractor({
          { type = 'int16', from = 1, to = 2, scale_factor = RX_SCALE_FACTOR_100 },
          { type = 'int16', from = 3, to = 4, scale_factor = RX_SCALE_FACTOR_100 },
          { type = 'int16', from = 5, to = 6, scale_factor = RX_SCALE_FACTOR_100 },
          { type = 'int16', from = 7, to = 8, scale_factor = RX_SCALE_FACTOR_100 },
        }),
      },
      {
        names = { 'louver_pos', 'cooling_control_duty' },
        msg_id = 0x358 + can_idx - 1,
        parser = bytes_extractor({
          { type = 'int16', from = 1, to = 2, scale_factor = RX_SCALE_FACTOR_100 },
          { type = 'int16', from = 3, to = 4, scale_factor = RX_SCALE_FACTOR_100 },
        }),
      },
      { name = 'status', msg_id = (0x368 + can_idx - 1), parser = parse_status },
    },
  }

  if conn_cfg.save_0x400 then
    table.insert(message_specs.telemetry, {
      name = 'messages_0x400',
      msg_id = 0x400 + can_idx - 1,
      multi_msg = true,
      parser = dump_0x400_parser,
    })
  end
end

function read_can_messages(data_type)
  if not message_specs then
    return nil, 'CAN not initialized'
  end

  local result = {}
  local messages = message_specs[data_type]
  if not messages then
    return result, nil
  end

  local msg_ids = {}
  for _, msg_spec in ipairs(messages) do
    table.insert(msg_ids, msg_spec.msg_id)
  end

  local frames, err = can_monitor:pop(msg_ids)
  if err then
    return nil, 'failed to read CAN messages: ' .. err
  end

  for i, msg_spec in ipairs(messages) do
    local frame = frames[i]
    if frame then
      if msg_spec.multi_msg then
        local parsed = msg_spec.parser({ frame })
        if parsed then
          result[msg_spec.name] = parsed
        end
      elseif msg_spec.names then
        local values = msg_spec.parser(frame)
        if values then
          for j, name in ipairs(msg_spec.names) do
            result[name] = values[j]
          end
        end
      elseif msg_spec.name then
        local value = msg_spec.parser(frame)
        if value then
          result[msg_spec.name] = value
        end
      end
    end
  end

  return result, nil
end

function cmd_start(ctx)
  local is_powered, err = get_relay_state(power_relay)
  if err then
    ctx.error('cannot read power relay state: ' .. err)
    return
  end

  if not is_powered then
    ctx.error('cannot start powered off fuel cell, power it on first')
    return
  end

  err = set_relay(start_relay, true)
  if err then
    ctx.error(err)
  end
end

function cmd_stop(ctx)
  local err = set_relay(start_relay, false)
  if err then
    ctx.error(err)
  end
end

function cmd_power_on(ctx)
  local err = set_relay(power_relay, true)
  if err then
    ctx.error(err)
  end
end

function cmd_power_off(ctx)
  local is_started, err = get_relay_state(start_relay)
  if err then
    ctx.error('cannot read start relay state: ' .. err)
  end

  if is_started then
    ctx.error('cannot power off started fuel cell, stop it first')
  end

  err = set_relay(power_relay, false)
  if err then
    ctx.error(err)
  end
end

function get_relay_state(relay_client)
  if not relay_client then
    return nil, 'relay not initialized'
  end
  return relay_client:is_closed()
end

function set_relay(relay_client, should_close)
  if not relay_client then
    return 'relay not initialized'
  end

  if should_close then
    return relay_client:close()
  else
    return relay_client:open()
  end
end

function convert_input_data(data)
  if type(data) == 'string' and #data == 16 then
    local v = { string.unpack('c2c2c2c2c2c2c2c2', data) }
    local vv = {}
    for j = 1, 8 do
      vv[j] = tonumber(v[j], 16)
    end
    return string.pack('BBBBBBBB', table.unpack(vv))
  else
    return data
  end
end

function toint16(data)
  return string.unpack('>i2', data)
end

function touint32(data)
  return string.unpack('>I4', data)
end

function parse_status(data)
  local state = string.sub(data, 1, 2)
  if state == '10' then
    return 'fault'
  elseif state == '20' then
    return 'steady'
  elseif state == '40' then
    return 'run'
  elseif state == '80' then
    return 'inactive'
  else
    return nil
  end
end

function software_version(data)
  data = convert_input_data(data)
  return string.format('%u.%u.%u', string.byte(data, 1), string.byte(data, 2), string.byte(data, 3))
end

function make_serial_number_parser()
  local serial_number_first_part = ''
  return function(datas)
    for _, data in ipairs(datas) do
      data = convert_input_data(data)
      if string.byte(data, 1) > 127 then
        if serial_number_first_part ~= '' then
          local serial_number_second_part = string.char(string.byte(data, 1, 1) - 128, string.byte(data, 2, 8))
          local serial_number = serial_number_first_part .. serial_number_second_part
          serial_number_first_part = ''
          return serial_number:match('([^\0]*)')
        end
      else
        serial_number_first_part = data
      end
    end
  end
end

function dump_0x400_parser(datas)
  local str_0x400 = nil
  for _, data in pairs(datas) do
    str_0x400 = str_0x400 or ''
    str_0x400 = str_0x400 .. ' ' .. data
  end
  return str_0x400
end

function bytes_extractor(parts)
  return function(data)
    data = convert_input_data(data)
    local ret = {}
    for i, p in pairs(parts) do
      local s = string.sub(data, p.from, p.to)
      if p.type == 'uint32' then
        ret[i] = touint32(s)
      elseif p.type == 'int16' then
        ret[i] = toint16(s)
      else
        assert('bad type')
      end

      if p.scale_factor ~= nil then
        ret[i] = ret[i] / p.scale_factor
      end
    end
    return ret
  end
end
