-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
ADDRESS_CONFIG = 'address'
UNIT_ID_CONFIG = 'unit_id'

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(30000, send_properties)
  scheduler.add(2000, send_telemetry)

  config.init({
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [UNIT_ID_CONFIG] = { type = 'number', required = true }
  })
end

function send_properties()
  local properties = {}

  local sma, _ = connect_sma()
  if sma then
    properties.serial_num = sma:read_u32_fix0(30057)
    properties.model = parse_model(sma:read_u32_enum(30053))

    local nominal_capacity_ah = sma:read_u32_fix0(40031)
    local nominal_voltage = sma:read_u32_fix0(40037)
    if nominal_capacity_ah and nominal_voltage then
      properties.nominal_capacity = nominal_capacity_ah * nominal_voltage / 1000
    end
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    for name, val in pairs(values) do
      properties[name] = val
    end
  end

  enapter.send_properties(properties)
end


function send_telemetry()
  local sma, err = connect_sma()
  if not sma then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = {'cannot_read_config'} })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'ok', alerts = {'not_configured'} })
    end
    return
  end

  enapter.send_telemetry({
    status = parse_status(sma:read_u32_enum(30201)),
    alerts = parse_event_msg(sma:read_u32_enum(30247)),
    recom_action = parse_recom_action(sma:read_u32_enum(30211)),
    bat_op_status = parse_bat_op_status(sma:read_u32_enum(30955)),
    -- absorb_status = sma:read_u32_enum(31059),
    -- message = parse_nilable_enum(sma:read_u32_enum(30213), 886),
    -- fault_corr_measure = parse_nilable_enum(sma:read_u32_enum(30215), 885),

    events_num = sma:read_u32_fix0(30247),
    absorbed_energy = sma:read_u32_fix0(30595),
    released_energy = sma:read_u32_fix0(30597),
    power = sma:read_s32_fix0(30775),
    power_l1 = sma:read_s32_fix0(30777),
    power_l2 = sma:read_s32_fix0(30779),
    power_l3 = sma:read_s32_fix0(30781),
    volt_l1 = sma:read_u32_fix2(30783),
    volt_l2 = sma:read_u32_fix2(30785),
    volt_l3 = sma:read_u32_fix2(30787),
    amp_l1 = sma:read_s32_fix3(30977),
    amp_l2 = sma:read_s32_fix3(30979),
    amp_l3 = sma:read_s32_fix3(30981),
    grid_freq = sma:read_u32_fix2(30803),
    r_power = sma:read_s32_fix2(30805),
    r_power_l1 = sma:read_s32_fix0(30807),
    r_power_l2 = sma:read_s32_fix0(30809),
    r_power_l3 = sma:read_s32_fix0(30811),
    bat_amp = sma:read_s32_fix3(30843),
    bat_soc = sma:read_u32_fix0(30845),
    bat_fault_soc = sma:read_u32_fix1(30987),
    bat_cap = sma:read_u32_fix0(30847),
    bat_temp = sma:read_s32_fix1(30849),
    bat_volt = sma:read_u32_fix2(30851),
    load_power = sma:read_s32_fix0(30861),
    bat_charge_factor = sma:read_u32_fix3(30993),
    time_until_charged = sma:read_u32_fix0(31003),
    time_until_equalized = sma:read_u32_fix0(31005),
    time_until_absorbed = sma:read_u32_fix0(31007),
    bat_charge_power = sma:read_u32_fix0(31393),
    bat_discharge_power = sma:read_u32_fix0(31395),
    bat_amph_charge = sma:read_u32_fix0(30567),
    bat_amph_discharge = sma:read_u32_fix0(30569),
    dc_amp = sma:read_s32_fix3(30769),
    dc_volt = sma:read_s32_fix2(30771),
    dc_power = sma:read_s32_fix2(30771),
    ac_power = sma:read_s32_fix0(30775),
    total_yield = sma:read_u32_fix0(30529),
    daily_yield = sma:read_u32_fix0(30535),
  })
end

-- holds global SMA connection
local sma

function connect_sma()
  if sma then return sma, nil end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local address, unit_id = values[ADDRESS_CONFIG], values[UNIT_ID_CONFIG]
    if not address or not unit_id then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      sma = SmaModbusTcp.new(address, tonumber(unit_id))
      sma:connect()
      return sma, nil
    end
  end
end

function parse_model(value)
  if not value then return end

  if value == 9157 then return 'SI 2012'
  elseif value == 9158 then return 'SI 2224'
  elseif value == 9159 then return 'SI 5048'
  elseif value == 9254 then return 'SI 3324'
  elseif value == 9255 then return 'SI 4.0M'
  elseif value == 9256 then return 'SI 4248'
  elseif value == 9257 then return 'SI 4248U'
  elseif value == 9258 then return 'SI 4500'
  elseif value == 9259 then return 'SI 4548U'
  elseif value == 9260 then return 'SI 5.4M'
  elseif value == 9261 then return 'SI 5048U'
  elseif value == 9262 then return 'SI 6048U'
  elseif value == 9278 then return 'SI 3.0M'
  elseif value == 9279 then return 'SI 4.4M'
  elseif value == 9331 then return 'SI 3.0M-12'
  elseif value == 9332 then return 'SI 4.4M-12'
  elseif value == 9333 then return 'SI 6.0H-12'
  elseif value == 9334 then return 'SI 8.0H-12'
  end
end

function parse_status(value)
  if not value then return end

  if value == 35 then return 'fault'
  elseif value == 303 then return 'off'
  elseif value == 307 then return 'ok'
  elseif value == 455 then return 'warning'
  else
    enapter.log('Cannot decode status: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_event_msg(value)
  if not value then return {} end

  local events = {}

  -- No alerts for the following events:
  -- 7320, 7345-7356, 7616, 8618-8619,
  -- 10251-10255, 10284-10340, 10426-10429, 10520-10528
  if value == 104 then table.insert(events, 'volt_high')
  elseif value == 204 then table.insert(events, 'volt_low')
  elseif value == 301 then table.insert(events, 'rise_in_volt_protection')
  elseif value == 405 then table.insert(events, 'external_grid_disconnect')
  elseif value == 504 then table.insert(events, 'freq_too_low')
  elseif value == 505 then table.insert(events, 'freq_too_high')
  elseif value == 803 then table.insert(events, 'grid_incident')
  elseif value == 1304 then table.insert(events, 'grid_connect_install_error')
  elseif value == 1402 then table.insert(events, 'volt_redundant_measure')
  elseif value == 1403 then table.insert(events, 'ratio_high')
  elseif value == 1404 then table.insert(events, 'line_conduct_disconnect')
  elseif value == 1405 then table.insert(events, 'short_circuit')
  elseif value == 1407 then table.insert(events, 'volt_freq_ratio_fault')
  elseif value == 1408 then table.insert(events, 'gen_reverse_pow_fault')
  elseif value == 1409 then table.insert(events, 'prohibited_feedback')
  elseif value == 1410 then table.insert(events, 'high_feed_in_current')
  elseif value == 1411 then table.insert(events, 'high_external_current')
  elseif value == 1412 then table.insert(events, 'open_pre_fuse')
  elseif value == 1413 then table.insert(events, 'phase_position_no_match')
  elseif value == 1415 then table.insert(events, 'tie_switch_no_close')
  elseif value == 1416 then table.insert(events, 'line_conduct_volt_imbalance')
  elseif value == 1601 then table.insert(events, 'auto_gen_start')
  elseif value == 1602 then table.insert(events, 'auto_gen_stop')
  elseif value == 1603 then table.insert(events, 'manual_gen_start')
  elseif value == 1604 then table.insert(events, 'manual_gen_stop')
  elseif value == 1605 then table.insert(events, 'manual_gen_err')
  elseif value == 1606 then table.insert(events, 'gen_requested')
  elseif value == 1607 then table.insert(events, 'gen_started')
  elseif value == 1608 then table.insert(events, 'gen_stopped')
  elseif value == 1609 then table.insert(events, 'low_battery_soc')
  elseif value == 1610 then table.insert(events, 'sufficient_battery_soc')
  elseif value == 1611 then table.insert(events, 'power_limit_exceed')
  elseif value == 1612 then table.insert(events, 'power_limit_not_reached')
  elseif value == 1613 then table.insert(events, 'manual_grid_request')
  elseif value == 1614 then table.insert(events, 'manual_grid_disconnect')
  elseif value == 1615 then table.insert(events, 'blocking_of_gen')
  elseif value == 1616 then table.insert(events, 'no_sync_with_gen')
  elseif value == 1701 then table.insert(events, 'auto_freq_control_intervene')
  elseif value == 1702 then table.insert(events, 'auto_freq_control_end')
  elseif value == 1704 then table.insert(events, 'gen_operation_not_possible')
  elseif value == 1705 then table.insert(events, 'invalid_grid_volt')
  elseif value == 1706 then table.insert(events, 'multicluster_box_fault')
  elseif value == 1707 then table.insert(events, 'overvoltage')
  elseif value == 1708 then table.insert(events, 'overfreq')
  elseif value == 1709 then table.insert(events, 'underfreq')
  elseif value == 1710 then table.insert(events, 'volt_ac1_low')
  elseif value == 1711 then table.insert(events, 'volt_ac1_undesired')
  elseif value == 1712 then table.insert(events, 'open_tie_switch')
  elseif value == 1713 then table.insert(events, 'missing_line_conductor')
  elseif value == 3809 then table.insert(events, 'inverter_bridge_overcurrent')
  elseif value >= 6120 and value <= 6135 then table.insert(events, 'ocu_watchdog_triggered')
  elseif value == 6316 then table.insert(events, 'measurement_intereference')
  elseif value == 6463 then table.insert(events, 'device_fault')
  elseif value == 6465 then table.insert(events, 'incorrect_processor_volt')
  elseif value == 6466 then table.insert(events, 'defective_volt_supply')
  elseif value >= 6502 and value <= 6514 then table.insert(events, 'overtemperature')
  elseif value == 6609 then table.insert(events, 'overload_volt_low')
  elseif value == 6610 then table.insert(events, 'overload_volt_high')
  elseif value == 6612 then table.insert(events, 'excessive_current')
  elseif value == 6613 then table.insert(events, 'high_power')
  elseif value == 6614 then table.insert(events, 'overload_5min_capacity')
  elseif value == 6615 then table.insert(events, 'overload_30min_capacity')
  elseif value == 6616 then table.insert(events, 'overload_shortterm_capacity')
  elseif value >= 7002 and value <= 7004 then table.insert(events, 'fan_sensor_error')
  elseif value == 7010 then table.insert(events, 'short_circuit_battery_temp_sensor')
  elseif value == 7011 then table.insert(events, 'cable_break_battery_temp_sensor')
  elseif value == 7101 then table.insert(events, 'defective_sd_memory_card')
  elseif value == 7102 then table.insert(events, 'param_file_not_found_defective')
  elseif value == 27103 then table.insert(events, 'set_param')
  elseif value == 27104 then table.insert(events, 'set_param_succeeded')
  elseif value == 7105 then table.insert(events, 'set_param_failed')
  elseif value == 7106 then table.insert(events, 'update_failed')
  elseif value == 27107 then table.insert(events, 'update_ok')
  elseif value == 27108 then table.insert(events, 'read_sd_card')
  elseif value == 27109 then table.insert(events, 'no_update_sd_card')
  elseif value == 7110 then table.insert(events, 'no_update_file_found')
  elseif value == 7112 then table.insert(events, 'update_file_copy_success')
  elseif value == 7113 then table.insert(events, 'sd_card_protected')
  elseif value == 27301 then table.insert(events, 'update_communication')
  elseif value == 27302 then table.insert(events, 'update_main_cpu')
  elseif value == 7303 then table.insert(events, 'update_main_cpu_failed')
  elseif value == 27312 then table.insert(events, 'update_completed')
  elseif value == 7329 then table.insert(events, 'condition_test_success')
  elseif value == 7330 then table.insert(events, 'condition_test_failed')
  elseif value == 7331 then table.insert(events, 'update_transport_started')
  elseif value == 7332 then table.insert(events, 'update_transport_success')
  elseif value == 7333 then table.insert(events, 'update_transport_fail')
  elseif value == 7341 then table.insert(events, 'update_bootloader')
  elseif value == 7342 then table.insert(events, 'update_bootloader_failed')
  elseif value == 7601 then table.insert(events, 'communication_error_ipc')
  elseif value == 7602 then table.insert(events, 'dev_internal_can_comm_missing')
  elseif value == 7608 then table.insert(events, 'cluster_internal_comm_interrupt')
  elseif value == 7609 then table.insert(events, 'energy_meter_comm_fault')
  elseif value == 7611 then table.insert(events, 'energy_meter_protocol_fault')
  elseif value == 7617 then table.insert(events, 'mc_box_comm_interrupted')
  elseif value == 7618 then table.insert(events, 'cluster_can_fault')
  elseif value == 7619 then table.insert(events, 'meter_unit_comm_fault')
  elseif value == 7620 then table.insert(events, 'grid_power_meter_comm_fault')
  elseif value == 7716 then table.insert(events, 'tie_switch_does_not_open')
  elseif value == 7717 then table.insert(events, 'neutral_conduct_relay_fault')
  elseif value == 7718 then table.insert(events, 'transfer_relay_fault')
  elseif value == 7719 then table.insert(events, 'mc_box_plausibility_check_fail')
  elseif value == 8003 then table.insert(events, 'reduced_battery_charge_overheat')
  elseif value >= 8101 and value <= 8104 then table.insert(events, 'comm_impaired')
  elseif value == 8609 then table.insert(events, 'slave_fault_status')
  elseif value == 8610 or value == 8611 then table.insert(events, 'cluster_config_error')
  elseif value == 8612 then table.insert(events, 'master_comm_interrupt')
  elseif value == 8613 then table.insert(events, 'cannot_measure_cluster_volt')
  elseif value == 8615 then table.insert(events, 'box_encoding_fault')
  elseif value == 8616 then table.insert(events, 'short_circuit_on_load_side')
  elseif value == 8617 then table.insert(events, 'cluster_incorrect_country_standard')
  elseif value == 8620 then table.insert(events, 'cluster_another_firmware_version')
  elseif value == 8706 then table.insert(events, 'setpoint_activated')
  elseif value == 8707 then table.insert(events, 'setpoint_deactivated')
  elseif value == 8716 then table.insert(events, 'saving_mode')
  elseif value == 9002 then table.insert(events, 'sma_grid_guard_code_invalid')
  elseif value == 9003 then table.insert(events, 'grid_parameter_locked')
  elseif value == 29004 then table.insert(events, 'grid_parameters_unchanged')
  elseif value == 9301 then table.insert(events, 'reset_battery_management')
  elseif value == 9308 then table.insert(events, 'bms_timeout')
  elseif value == 9313 then table.insert(events, 'temp_low_limit_undercut')
  elseif value == 9314 then table.insert(events, 'temp_upper_limit_exceed')
  elseif value == 9318 then table.insert(events, 'emergency_charge')
  elseif value == 9319 then table.insert(events, 'battery_float_charge')
  elseif value == 9320 then table.insert(events, 'battery_boost_charge')
  elseif value == 9321 then table.insert(events, 'battery_full_charge')
  elseif value == 9322 then table.insert(events, 'calibration_20_per_done')
  elseif value == 9324 then table.insert(events, 'low_soh')
  elseif value == 9325 then table.insert(events, 'recalibration_jump')
  elseif value == 9326 then table.insert(events, 'battery_protection_mode_on')
  elseif value == 9331 then table.insert(events, 'battery_voltage_above_range')
  elseif value == 9332 then table.insert(events, 'bms_not_configured')
  elseif value == 9333 then table.insert(events, 'battery_voltage_below_range')
  elseif value == 9341 then table.insert(events, 'battery_equalization_charge')
  elseif value == 9362 then table.insert(events, 'deep_discharge_area')
  elseif value == 9401 then table.insert(events, 'saving_mode_slaves_single_phase')
  elseif value == 9402 then table.insert(events, 'saving_mode_at_grid')
  elseif value == 9403 then table.insert(events, 'saving_mode_start')
  elseif value == 9404 then table.insert(events, 'saving_mode_stop')
  elseif value == 9601 then table.insert(events, 'di_status_changed')
  elseif value == 10001 then table.insert(events, 'parallel_grid_operation')
  elseif value == 10003 then table.insert(events, 'operation_status')
  elseif value == 10004 then table.insert(events, 'cold_start_status')
  elseif value == 10006 then table.insert(events, 'startup_status')
  elseif value == 10007 then table.insert(events, 'stop_status')
  elseif value == 10010 then table.insert(events, 'restart_diagnosis_system')
  elseif value == 10060 then table.insert(events, 'gen_operation')
  elseif value == 10061 then table.insert(events, 'feeding_network_op')
  elseif value == 10100 or value == 10102 then table.insert(events, 'param_set_success')
  elseif value == 10101 or value == 10103 then table.insert(events, 'param_set_fail')
  elseif value == 10108 then table.insert(events, 'old_time')
  elseif value == 10109 then table.insert(events, 'new_time')
  elseif value == 10110 then table.insert(events, 'time_sync_failed')
  elseif value == 10114 then table.insert(events, 'ntp_server_no_info')
  elseif value == 10117 then table.insert(events, 'invalid_time')
  elseif value == 10118 then table.insert(events, 'param_upload_success')
  elseif value == 10121 then table.insert(events, 'param_xx_set_fail1')
  elseif value == 10122 then table.insert(events, 'param_xx_set_fail2')
  elseif value == 10248 or value == 10249 then table.insert(events, 'network_busy')
  elseif value == 10250 then table.insert(events, 'package_error_rate_changed')
  elseif value == 10283 then table.insert(events, 'wifi_module_fault')
  elseif value == 10414 then table.insert(events, 'shutdown_due_to_fault')
  elseif value == 10415 then table.insert(events, 'automatic_start')
  elseif value == 10416 then table.insert(events, 'manual_start')
  elseif value == 10417 then table.insert(events, 'manual_stop')
  elseif value == 10418 then table.insert(events, 'system_control_start')
  elseif value == 10419 then table.insert(events, 'system_control_stop')
  elseif value == 10420 then table.insert(events, 'self_consumpt_control_start')
  elseif value == 10421 then table.insert(events, 'self_consumpt_control_stop')
  elseif value == 10422 then table.insert(events, 'self_consumpt_only_charge')
  elseif value == 10423 then table.insert(events, 'charge_active_self_consumpt')
  elseif value == 10424 then table.insert(events, 'back_to_self_consumption')
  elseif value == 10425 then table.insert(events, 'switch_off')
  elseif value == 10517 then table.insert(events, 'dynamic_act_pow_limit_start')
  elseif value == 10518 then table.insert(events, 'dynamic_act_pow_limit_terminate')
  elseif value == 10704 then table.insert(events, 'current_sensor_defective')
  end

  return events
end

function parse_recom_action(value)
  if not value then return end

  if value == 336 then return 'contact_manufacturer'
  elseif value == 337 then return 'contact_installer'
  elseif value == 338 or value == 887 then return 'ok'
  else
    enapter.log('Cannot decode recommended action: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_bat_op_status(value)
  if not value then return end

  if value == 2292 then return 'charge'
  elseif value == 2293 then return 'discharge'
  else
    enapter.log('Cannot decode battery op status: '..tostring(value), 'error')
    return tostring(value)
  end
end


---------------------------------
-- Stored Configuration API
---------------------------------

config = {}

-- Initializes config options. Registers required UCM commands.
-- @param options: key-value pairs with option name and option params
-- @example
--   config.init({
--     address = { type = 'string', required = true },
--     unit_id = { type = 'number', default = 1 },
--     reconnect = { type = 'boolean', required = true }
--   })
function config.init(options)
  assert(next(options) ~= nil, 'at least one config option should be provided')
  assert(not config.initialized, 'config can be initialized only once')
  for name, params in pairs(options) do
    local type_ok = params.type == 'string' or params.type == 'number' or params.type == 'boolean'
    assert(type_ok, 'type of `'..name..'` option should be either string or number or boolean')
  end

  enapter.register_command_handler('write_configuration', config.build_write_configuration_command(options))
  enapter.register_command_handler('read_configuration', config.build_read_configuration_command(options))

  config.options = options
  config.initialized = true
end

-- Reads all initialized config options
-- @return table: key-value pairs
-- @return nil|error
function config.read_all()
  local result = {}

  for name, _ in pairs(config.options) do
    local value, err = config.read(name)
    if err then
      return nil, 'cannot read `'..name..'`: '..err
    else
      result[name] = value
    end
  end

  return result, nil
end

-- @param name string: option name to read
-- @return string
-- @return nil|error
function config.read(name)
  local params = config.options[name]
  assert(params, 'undeclared config option: `'..name..'`, declare with config.init')

  local ok, value, ret = pcall(function()
    return storage.read(name)
  end)

  if not ok then
    return nil, 'error reading from storage: '..tostring(value)
  elseif ret and ret ~= 0 then
    return nil, 'error reading from storage: '..storage.err_to_str(ret)
  elseif value then
    return config.deserialize(name, value), nil
  else
    return params.default, nil
  end
end

-- @param name string: option name to write
-- @param val string: value to write
-- @return nil|error
function config.write(name, val)
  local ok, ret = pcall(function()
    return storage.write(name, config.serialize(name, val))
  end)

  if not ok then
    return 'error writing to storage: '..tostring(ret)
  elseif ret and ret ~= 0 then
    return 'error writing to storage: '..storage.err_to_str(ret)
  end
end

-- Serializes value into string for storage
function config.serialize(_, value)
  if value then
    return tostring(value)
  else
    return nil
  end
end

-- Deserializes value from stored string
function config.deserialize(name, value)
  local params = config.options[name]
  assert(params, 'undeclared config option: `'..name..'`, declare with config.init')

  if params.type == 'number' then
    return tonumber(value)
  elseif params.type == 'string' then
    return value
  elseif params.type == 'boolean' then
    if value == 'true' then
      return true
  elseif value == 'false' then
      return false
    else
      return nil
    end
  end
end

function config.build_write_configuration_command(options)
  return function(ctx, args)
    for name, params in pairs(options) do
      if params.required then
        assert(args[name], '`'..name..'` argument required')
      end

      local err = config.write(name, args[name])
      if err then ctx.error('cannot write `'..name..'`: '..err) end
    end
  end
end

function config.build_read_configuration_command(_config_options)
  return function(ctx)
    local result, err = config.read_all()
    if err then
      ctx.error(err)
    else
      return result
    end
  end
end

---------------------------------
-- SMA ModbusTCP API
---------------------------------

SmaModbusTcp = {}

function SmaModbusTcp.new(addr, unit_id)
  assert(type(addr) == 'string', 'addr (arg #1) must be string, given: '..inspect(addr))
  assert(type(unit_id) == 'number', 'unit_id (arg #2) must be number, given: '..inspect(unit_id))

  local self = setmetatable({}, { __index = SmaModbusTcp })
  self.addr = addr
  self.unit_id = unit_id
  return self
end

function SmaModbusTcp:connect()
  self.modbus = modbustcp.new(self.addr)
end

function SmaModbusTcp:read_holdings(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: '..inspect(address))
  assert(type(number) == 'number', 'number (arg #1) must be number, given: '..inspect(number))

  local registers, err = self.modbus:read_holdings(self.unit_id, address, number, 1000)
  if err and err ~= 0 then
    enapter.log('read error: '..err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
    return nil
  end

  return registers
end

function SmaModbusTcp:read_u32(address)
  local reg = self:read_holdings(address, 2)
  if not reg then return end

  -- NaN for U32 values
  if reg[1] == 0xFFFF and reg[2] == 0xFFFF then
    return nil
  end

  -- NaN for ENUM values
  if reg[1] == 0x00FF and reg[2] == 0xFFFD then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw)
end

function SmaModbusTcp:read_u32_enum(address)
  return self:read_u32(address)
end

function SmaModbusTcp:read_u32_fix0(address)
  return self:read_u32(address)
end

function SmaModbusTcp:read_u32_fix1(address)
  local v = self:read_u32(address)
  if v then
    return v / 10
  else
    return v
  end
end

function SmaModbusTcp:read_u32_fix2(address)
  local v = self:read_u32(address)
  if v then
    return v / 100
  else
    return v
  end
end

function SmaModbusTcp:read_u32_fix3(address)
  local v = self:read_u32(address)
  if v then
    return v / 1000
  else
    return v
  end
end

function SmaModbusTcp:read_s32(address)
  local reg = self:read_holdings(address, 2)
  if not reg then return end

  if reg[1] == 0x8000 and reg[2] == 0 then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>i4', raw)
end

function SmaModbusTcp:read_s32_fix0(address)
  return self:read_s32(address)
end

function SmaModbusTcp:read_s32_fix1(address)
  local v = self:read_s32(address)
  if v then
    return v / 10
  else
    return v
  end
end

function SmaModbusTcp:read_s32_fix2(address)
  local v = self:read_s32(address)
  if v then
    return v / 100
  else
    return v
  end
end

function SmaModbusTcp:read_s32_fix3(address)
  local v = self:read_s32(address)
  if v then
    return v / 1000
  else
    return v
  end
end

main()
