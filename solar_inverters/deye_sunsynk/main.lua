local conn
local conn_cfg
local conn_error_msg

function main()
  reconnect()
  configuration.after_write('connection', function()
    conn = nil
    conn_cfg = nil
  end)
  scheduler.add(1000, reconnect)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function reconnect()
  if conn then
    return
  end

  local configured = configuration.is_all_required_set('connection')
  if not configured then
    return
  end

  local cfg, err = configuration.read('connection')
  if err ~= nil then
    conn_error_msg = 'failed to read configuration: ' .. err
    return
  end

  conn_cfg = cfg
  local client, err = modbus.new(conn_cfg.conn_str)
  if err ~= nil then
    conn_error_msg = 'failed to connect: ' .. err
    return
  end

  conn = client
  conn_error_msg = nil
end

function send_properties()
  if not conn then
    return
  end

  local properties = {}
  properties.vendor = conn_cfg.vendor

  local results, err = fetch_properties(conn)
  if err then
    enapter.log('failed to get properties: ' .. err, 'error', true)
  else
    parse_properties(properties, results)
  end

  if next(properties) then
    enapter.send_properties(properties)
  end
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ alerts = { 'not_configured' } })
    return
  end

  if not conn then
    enapter.send_telemetry({
      alerts = { 'conn_error' },
      alert_details = { conn_error = { errmsg = conn_error_msg } },
    })
    enapter.log(conn_error_msg, 'error', true)
    return
  end

  local telemetry = {}
  local alert_error_msg = nil

  -- We slow down the polling to avoid overloading the inverter,
  -- otherwise it starts to respond with wrong CRCs
  system.delay(500)

  local addr = conn_cfg.address
  local data, err = conn:read_holdings(addr, 500, 110, 50)
  if err then
    alert_error_msg = 'error reading metrics 1: ' .. err
  else
    parse_metrics1(telemetry, data)
  end

  system.delay(500)

  data, err = conn:read_holdings(addr, 616, 80, 50)
  if err then
    alert_error_msg = 'error reading metrics 2: ' .. err
  else
    parse_metrics2(telemetry, data)
  end

  if alert_error_msg then
    telemetry.alerts = { 'conn_error' }
    telemetry.alert_details = { conn_error = { errmsg = alert_error_msg } }
    enapter.log(alert_error_msg, 'error', true)
  end

  enapter.send_telemetry(telemetry)
end

function parse_metrics1(telemetry, data)
  local base = 500
  telemetry.grid_status = get_grid_status(data, base)
  telemetry.status = get_device_status(data, base)
  telemetry.alerts = get_alerts(data, base)
  -- XXX: check again on low/high word registers
  telemetry.internal_temperature = data[540 - base + 1] * 0.1 - 100
  telemetry.heatsink_temperature = data[541 - base + 1] * 0.1 - 100

  telemetry.battery_temperature = data[586 - base + 1] * 0.1 - 100
  telemetry.battery_voltage = data[587 - base + 1] * 0.01
  telemetry.battery_soc = data[588 - base + 1]
  telemetry.battery_power = s16(data[590 - base + 1])
  telemetry.battery_current = s16(data[591 - base + 1]) * 0.01

  telemetry.battery_charged_energy_total = ((data[517 - base + 1] << 16) + data[516 - base + 1]) * 0.1 * 1000
  telemetry.battery_discharged_energy_total = ((data[519 - base + 1] << 16) + data[518 - base + 1]) * 0.1 * 1000

  telemetry.ac_frequency = data[609 - base + 1] * 0.01

  telemetry.ac_energy_today = data[501 - base + 1] * 0.1 * 1000
  telemetry.ac_energy_total = ((data[505 - base + 1] << 16) + data[504 - base + 1]) * 0.1 * 1000

  telemetry.pv_energy_today = data[529 - base + 1] * 0.1 * 1000
  telemetry.pv_energy_total = ((data[535 - base + 1] << 16) + data[534 - base + 1]) * 0.1 * 1000
end

function parse_metrics2(telemetry, data)
  local base = 616
  telemetry.ac_l1_voltage = data[627 - base + 1]
  telemetry.ac_l2_voltage = data[628 - base + 1]
  telemetry.ac_l3_voltage = data[629 - base + 1]
  telemetry.ac_l1_current = s16(data[630 - base + 1])
  telemetry.ac_l2_current = s16(data[631 - base + 1])
  telemetry.ac_l3_current = s16(data[632 - base + 1])
  telemetry.ac_l1_power = s16(data[633 - base + 1])
  telemetry.ac_l2_power = s16(data[634 - base + 1])
  telemetry.ac_l3_power = s16(data[635 - base + 1])
  telemetry.ac_power = s16(data[636 - base + 1])

  telemetry.load_l1_power = s16(data[656 - base + 1])
  telemetry.load_l2_power = s16(data[657 - base + 1])
  telemetry.load_l3_power = s16(data[658 - base + 1])
  telemetry.load_power = s16(data[659 - base + 1])

  telemetry.grid_l1_power = s16(data[622 - base + 1])
  telemetry.grid_l2_power = s16(data[623 - base + 1])
  telemetry.grid_l3_power = s16(data[624 - base + 1])
  telemetry.grid_power = s16(data[625 - base + 1])

  local pv1_power = data[672 - base + 1]
  local pv2_power = data[673 - base + 1]
  local pv3_power = data[674 - base + 1]
  local pv4_power = data[675 - base + 1]
  telemetry.pv_total_power = pv1_power + pv2_power + pv3_power + pv4_power

  local pv1_voltage = data[676 - base + 1] * 0.1
  local pv1_current = data[677 - base + 1] * 0.1
  local pv2_voltage = data[678 - base + 1] * 0.1
  local pv2_current = data[679 - base + 1] * 0.1
  local pv3_voltage = data[680 - base + 1] * 0.1
  local pv3_current = data[681 - base + 1] * 0.1
  local pv4_voltage = data[682 - base + 1] * 0.1
  local pv4_current = data[683 - base + 1] * 0.1
  telemetry.pv_current = (pv1_current + pv2_current + pv3_current + pv4_current) / 4

  local pv_volts = { pv1_voltage, pv2_voltage, pv3_voltage, pv4_voltage }
  telemetry.pv_voltage = get_pv_voltage(pv_volts)
end

function get_grid_status(data, base)
  if not data then
    return
  end
  if data[552 - base + 1] & (1 << 2) ~= 0 then
    return 'connected'
  else
    return 'disconnected'
  end
end

function get_device_status(data, base)
  if not data then
    return
  end
  local run_state = data[500 - base + 1]
  if run_state == 0 then
    -- 0000  待机 standby
    return 'standby'
  elseif run_state == 1 then
    -- 0001  自检 selfcheck
    return 'operating'
  elseif run_state == 2 then
    -- 0002  正常 normal
    return 'operating'
  elseif run_state == 3 then
    -- 0003  告警 alarm
    return 'operating'
  elseif run_state == 4 then
    -- 0004  故障 fault
    return 'fault'
  elseif run_state == 5 then
    -- 0005  激活中
    return 'starting'
  end
end

function get_alerts(data, base)
  if not data then
    return
  end
  local alerts = {}
  if data[553 - base + 1] & (1 << 1) ~= 0 then
    table.insert(alerts, 'fan_warning')
  end
  if data[553 - base + 1] & (1 << 2) ~= 0 then
    table.insert(alerts, 'grid_phase_warning')
  end
  if data[554 - base + 1] & (1 << 14) ~= 0 then
    table.insert(alerts, 'lithium_battery_loss_warning')
  end
  if data[554 - base + 1] & (1 << 15) ~= 0 then
    table.insert(alerts, 'parallel_communication_quality_warning')
  end

  local add_fault = function(bit, code)
    local reg = 555 - base + 1 + math.floor((bit - 1) / 16)
    if data[reg] & (1 << ((bit - 1) % 16)) ~= 0 then
      table.insert(alerts, code)
    end
  end
  add_fault(1, 'dc_inversed_failure')
  add_fault(7, 'dc_start_failure')
  add_fault(10, 'aux_power_board_failure')
  add_fault(13, 'working_mode_change')
  add_fault(15, 'ac_over_current_sw_failure')
  add_fault(16, 'dc_ground_leakage_current_fault')
  add_fault(18, 'ac_over_current_tz')
  add_fault(20, 'dc_over_current')
  add_fault(21, 'dc_hv_bus_over_current')
  add_fault(22, 'remote_emergency_stop')
  add_fault(23, 'ac_leakage_current_is_transient_over_current')
  add_fault(24, 'dc_insulation_impedance')
  add_fault(26, 'dc_busbar_imbalanced')
  add_fault(29, 'parallel_comms_cable')
  add_fault(34, 'ac_overload_backup')
  add_fault(35, 'no_ac_grid')
  add_fault(41, 'parallel_system_stopped')
  add_fault(42, 'ac_line_low_voltage')
  add_fault(46, 'battery_1_fault')
  add_fault(49, 'battery_2_fault')
  add_fault(47, 'ac_grid_freq_too_high')
  add_fault(48, 'ac_grid_freq_too_low')
  add_fault(52, 'dc_voltage_too_high')
  add_fault(53, 'dc_voltage_too_low')
  add_fault(54, 'battery_1_voltage_high')
  add_fault(55, 'battery_2_voltage_high')
  add_fault(56, 'battery_1_voltage_low')
  add_fault(57, 'battery_2_voltage_low')
  add_fault(58, 'bms_communication_lost')
  add_fault(62, 'drm_stop_activated')
  add_fault(63, 'arc_fault')
  add_fault(64, 'heat_sink_temp_failure')
  return alerts
end

function get_pv_voltage(pv_volts)
  if not conn_cfg.pv_string_voltage then
    return
  end
  local sum = 0
  local count = 0
  for _, v in pairs(pv_volts) do
    if v >= conn_cfg.pv_string_voltage then
      sum = sum + v
      count = count + 1
    end
  end
  return sum / count
end

function fetch_properties(client)
  local addr = conn_cfg.address
  local queries = {
    { type = 'holdings', addr = addr, reg = 0, count = 40, timeout = 50 },
    { type = 'holdings', addr = addr, reg = 98, count = 6, timeout = 50 },
    { type = 'holdings', addr = addr, reg = 336, count = 4, timeout = 50 },
  }
  return fetch_data(client, queries)
end

function parse_properties(properties, results)
  local data = results[1]
  local inverter_nameplate_capacity = parse_inverter_nameplate_capacity(data)

  properties.inverter_nameplate_capacity = inverter_nameplate_capacity
  properties.model = parse_model(data, inverter_nameplate_capacity)
  properties.communication_protocol_version = parse_comm_protocol_version(data)
  properties.serial_number = parse_serial_number(data)
  properties.firmware_version = parse_fw_ver(data)

  data = results[2]
  properties.battery_type = parse_battery_type(data)
  properties.battery_nameplate_capacity = data[5]

  fill_parallel_mode(properties, results[3])
end

function parse_inverter_nameplate_capacity(data)
  return ((data[22] << 16) + data[21]) / 10
end

function parse_model(data, inverter_nameplate_capacity)
  local mppt_num = data[23] >> 8
  local phase_num = data[23] & 0xFF
  local device_type, err = parse_device_type(data)
  if err then
    enapter.log(err, 'error', true)
    return
  end
  local model_voltage = get_model_voltage(device_type)
  local raw_cap = inverter_nameplate_capacity / 1000
  local model_cap = math.floor(raw_cap) == raw_cap and tostring(math.floor(raw_cap)) or string.format('%.1f', raw_cap)
  return 'SUN-'
    .. tostring(model_cap)
    .. 'k-SG'
    .. string.format('%02d', mppt_num)
    .. model_voltage
    .. 'P'
    .. tostring(phase_num)
end

function parse_device_type(data)
  local device_types = {
    [0x0002] = 'string_inverter',
    [0x0003] = '1phase_hybrid',
    [0x0004] = 'microinverter',
    [0x0005] = '3phase_lv_hybrid',
    [0x0006] = '3phase_hv_6_15kw_hybrid',
    [0x0106] = '3phase_hv_20_50kw_hybrid',
    [0x0008] = '3phase_100k_pcs',
    [0x0009] = 'balcony_storage',
  }
  local device_type = device_types[data[1]]
  if not device_type or not string.find(device_type, 'hybrid') then
    return nil, 'skipping device model because device type is not supported: ' .. tostring(device_type)
  end
  return device_type
end

function parse_comm_protocol_version(data)
  return tostring(data[3] >> 8) .. '.' .. tostring(data[3] & 0xFF)
end

function parse_serial_number(data)
  local function get_ascii_string(d, start, length)
    local str = ''
    for i = start, start + length - 1 do
      local value = d[i]
      if value then
        -- Extract two ASCII characters from each register
        local char1 = string.char((value >> 8) & 0xFF)
        local char2 = string.char(value & 0xFF)
        str = str .. char1 .. char2
      end
    end
    return str
  end
  return get_ascii_string(data, 4, 5)
end

function parse_fw_ver(data)
  return string.format('%04X', data[15])
    .. '-'
    .. string.format('%04X', data[16])
    .. '-'
    .. string.format('%04X', data[12])
end

function get_model_voltage(device_type)
  -- only 3-phase hybrid inverters add a suffix to the model
  local model_voltage = ''
  if device_type == '3phase_lv_hybrid' then
    model_voltage = 'L'
  elseif device_type == '3phase_hv_6_15kw_hybrid' or device_type == '3phase_hv_20_50kw_hybrid' then
    model_voltage = 'H'
  end
  return model_voltage
end

function parse_battery_type(data)
  if data[1] == 0x0000 then
    return 'lead_based'
  elseif data[1] == 0x0001 then
    return 'lithium_based'
  end
end

function fill_parallel_mode(properties, data)
  local value = data[1]

  properties.parallel_enabled = (value & (1 << 0)) ~= 0
  properties.parallel_role = ((value >> 1) & 0x1) == 1 and 'master' or 'slave'

  local phase_bits = (value >> 8) & 0x3
  local phase_map = { [0] = 'A', [1] = 'B', [2] = 'C' }
  properties.parallel_phase = phase_map[phase_bits]
end

function fetch_data(client, queries)
  local results, err = client:read(queries)
  if err then
    return nil, err
  elseif not results then
    return nil, 'no results received'
  elseif #results ~= #queries then
    return nil, 'invalid response length (expected: ' .. #queries .. ', got: ' .. #results .. ')'
  end
  for i, _ in ipairs(results) do
    local err = check_query_result(results, i)
    if err then
      return nil, err
    end
  end
  return results, nil
end

function check_query_result(results, num)
  local res = results[num]
  if res.errmsg ~= nil then
    return 'reading query error ' .. num .. ': ' .. res.errmsg
  end

  if res.data == nil then
    return 'reading query error' .. num .. ': data is missing'
  end
  return nil
end

function s16(value)
  if not value then
    return
  end
  if value >= 0x8000 then
    return value - 0x10000
  else
    return value
  end
end

main()
