local smamodbus = require('./smamodbus')

local conn = nil
local conn_cfg = nil

function enapter.main()
  reconnect()
  configuration.after_write('connection', function()
    conn = nil
    conn_cfg = nil
  end)
  scheduler.add(1000, reconnect)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_realtime_telemetry)
  scheduler.add(5000, send_detailed_telemetry)
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
    enapter.log('read configuration: ' .. err, 'error')
    return
  end

  conn_cfg = cfg
  local sma = smamodbus.new(conn_cfg.address, conn_cfg.unit_id)
  local connect_err = sma:connect()
  if connect_err ~= nil then
    enapter.log('connect: ' .. connect_err, 'error')
    return
  end

  conn = sma
end

function send_properties()
  if not conn then
    return
  end

  local properties = {}
  properties.vendor = 'SMA'
  properties.model = parse_model(conn:read_u32_enum(30053))
  properties.serial_number = tostring(conn:read_u32_fix0(30057))
  properties.firmware_version = parse_firmware_version(conn:read_u32_fix0(30059))
  properties.inverter_nameplate_capacity = 8000
  properties.grid_mode = 'off_grid'
  properties.battery_type = parse_battery_type(conn:read_u32_enum(40035))
  properties.battery_nameplate_capacity = (conn:read_u32_fix0(40031) or 0) * 48
  properties.country_code = parse_country_code(conn:read_u32_fix0(40109))
  if conn_cfg then
    properties.address = conn_cfg.address
    properties.unit_id = conn_cfg.unit_id
  end

  enapter.send_properties(properties)
end

function send_realtime_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ conn_alerts = { 'not_configured' } })
    return
  end
  if not conn then
    enapter.send_telemetry({ conn_alerts = { 'communication_failed' } })
    return
  end

  local operating_status = parse_operating_status(conn:read_u32_enum(40029))

  local battery_current = conn:read_s32_fix3(30843)
  local battery_voltage = conn:read_u32_fix2(30851)
  local battery_power
  if battery_current and battery_voltage then
    battery_power = battery_current * battery_voltage
  end

  local telemetry = {
    alerts = parse_alerts(conn:read_u32_enum(30213), conn:read_u32_enum(30247)),
    health = parse_health_status(conn:read_u32_enum(30201)),
    status = convert_operating_status_to_status(operating_status),
    operating_status = operating_status,

    battery_soc = conn:read_u32_fix0(30845),
    battery_soh = conn:read_u32_fix0(30847),
    battery_voltage = battery_voltage,
    battery_current = battery_current,
    battery_power = battery_power,
    battery_temperature = conn:read_s32_fix1(30849),

    ac_total_power = conn:read_s32_fix0(30775),
    ac_frequency = conn:read_u32_fix2(30803),
    grid_total_power = conn:read_s32_fix0(31417),

    grid_relay_closed = parse_grid_relay_closed(conn:read_u32_enum(30217)),
  }
  telemetry.conn_alerts = {}

  enapter.send_telemetry(telemetry)
end

function send_detailed_telemetry()
  if not conn then
    return
  end

  local telemetry = {
    recom_action = parse_recom_action(conn:read_u32_enum(30211)),
    derating_reason = parse_derating_reason(conn:read_u32_enum(30219)),

    ac_l1_power = conn:read_s32_fix0(30777),
    ac_l2_power = conn:read_s32_fix0(30779),
    ac_l3_power = conn:read_s32_fix0(30781),
    ac_l1_voltage = conn:read_u32_fix2(30783),
    ac_l2_voltage = conn:read_u32_fix2(30785),
    ac_l3_voltage = conn:read_u32_fix2(30787),
    ac_l1_current = conn:read_s32_fix3(30977),
    ac_l2_current = conn:read_s32_fix3(30979),
    ac_l3_current = conn:read_s32_fix3(30981),

    ac_l1_power_reactive = conn:read_s32_fix0(30807),
    ac_l2_power_reactive = conn:read_s32_fix0(30809),
    ac_l3_power_reactive = conn:read_s32_fix0(30811),
    ac_power_reactive = conn:read_s32_fix0(30805),
    ac_power_apparent = conn:read_s32_fix0(30813),
    ac_power_factor = conn:read_u32_fix3(30949),

    residual_current = conn:read_s32_fix3(31247),
    internal_temperature = conn:read_s32_fix1(34113),

    load_power = conn:read_s32_fix0(30861),
  }

  enapter.send_telemetry(telemetry)
end

-- Model parsing

function parse_model(value)
  if not value then
    return
  end

  local models = {
    [9331] = 'SI 3.0M-12',
    [9332] = 'SI 4.4M-12',
    [9333] = 'SI 6.0H-12',
    [9334] = 'SI 8.0H-12',
    [9474] = 'SI4.4M-13',
    [9475] = 'SI6.0H-13',
    [9476] = 'SI8.0H-13',
    [9486] = 'SI5.0H-13',
    [9157] = 'SI 2012',
    [9158] = 'SI 2224',
    [9159] = 'SI 5048',
    [9223] = 'SI6.0H-11',
    [9224] = 'SI8.0H-11',
    [9254] = 'SI 3324',
    [9255] = 'SI 4.0M',
    [9256] = 'SI 4248',
    [9257] = 'SI 4248U',
    [9258] = 'SI 4500',
    [9259] = 'SI 4548U',
    [9260] = 'SI 5.4M',
    [9261] = 'SI 5048U',
    [9262] = 'SI 6048U',
    [9278] = 'SI3.0M-11',
    [9279] = 'SI4.4M-11',
  }

  local model = models[value]
  if model then
    return model
  end

  enapter.log('Cannot decode model: ' .. tostring(value), 'error')
  return tostring(value)
end

-- Status parsing

function parse_health_status(value)
  if not value then
    return
  end

  if value == 35 then
    return 'fault'
  elseif value == 303 then
    return nil
  elseif value == 307 then
    return 'ok'
  elseif value == 455 then
    return 'warning'
  else
    enapter.log('Cannot decode health status: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function parse_operating_status(value)
  if not value then
    return
  end

  local statuses = {
    [1295] = 'standby',
    [1392] = 'fault',
    [1393] = 'waiting_pv_voltage',
    [1467] = 'start',
    [1469] = 'shutdown',
    [1480] = 'waiting_utilities',
    [1795] = 'bolted',
    [1855] = 'standalone',
    [2119] = 'derating',
    [295] = 'mpp',
    [303] = 'off',
    [381] = 'stop',
    [443] = 'const_voltage',
    [455] = 'warning',
    [569] = 'run',
  }

  local status = statuses[value]
  if status then
    return status
  end

  enapter.log('Cannot decode operating status: ' .. tostring(value), 'error')
  return tostring(value)
end

function convert_operating_status_to_status(value)
  if not value then
    return
  end

  if value == 'off' or value == 'stop' then
    return 'off'
  elseif value == 'standby' or value == 'waiting_pv_voltage' or value == 'waiting_utilities' or value == 'bolted' then
    return 'standby'
  elseif value == 'start' then
    return 'starting'
  elseif
    value == 'derating'
    or value == 'mpp'
    or value == 'run'
    or value == 'standalone'
    or value == 'const_voltage'
    or value == 'warning'
  then
    return 'operating'
  elseif value == 'shutdown' then
    return 'shutting_down'
  elseif value == 'fault' then
    return 'fault'
  end
end

function parse_recom_action(value)
  if not value then
    return
  end

  if value == 336 then
    return 'contact_manufacturer'
  elseif value == 337 then
    return 'contact_installer'
  elseif value == 338 or value == 887 or value == 973 then
    return 'ok'
  else
    enapter.log('Cannot decode recommended action: ' .. tostring(value), 'error')
    return tostring(value)
  end
end

function parse_grid_relay_closed(value)
  if not value then
    return
  end

  if value == 51 then
    return true
  elseif value == 311 then
    return false
  else
    enapter.log('Cannot decode grid relay status: ' .. tostring(value), 'error')
    return
  end
end

function parse_derating_reason(value)
  if not value then
    return
  end

  local reasons = {
    [1705] = 'frequency_deviation',
    [3520] = 'voltage_deviation',
    [3554] = 'reactive_power_priority',
    [3556] = 'high_dc_voltage',
    [4560] = 'external_setting',
    [4561] = 'external_setting_2',
    [557] = 'overtemperature',
    [884] = 'ok',
  }

  local reason = reasons[value]
  if reason then
    return reason
  end

  enapter.log('Cannot decode derating reason: ' .. tostring(value), 'error')
  return tostring(value)
end

-- Alert parsing

function parse_alerts(presence, message)
  if not presence and not message then
    return
  end

  if presence == 886 or presence == 302 then
    return {}
  elseif message then
    return parse_event_message(message)
  else
    return { 'unknown_event' }
  end
end

function parse_event_message(value)
  if not value then
    return {}
  end

  local event_map = {
    [104] = 'volt_high',
    [204] = 'volt_low',
    [301] = 'rise_in_volt_protection',
    [405] = 'external_grid_disconnect',
    [504] = 'freq_too_low',
    [505] = 'freq_too_high',
    [803] = 'grid_incident',
    [1304] = 'grid_connect_install_error',
    [1402] = 'volt_redundant_measure',
    [1403] = 'ratio_high',
    [1404] = 'line_conduct_disconnect',
    [1405] = 'short_circuit',
    [1407] = 'volt_freq_ratio_fault',
    [1408] = 'gen_reverse_pow_fault',
    [1409] = 'prohibited_feedback',
    [1410] = 'high_feed_in_current',
    [1411] = 'high_external_current',
    [1412] = 'open_pre_fuse',
    [1413] = 'phase_position_no_match',
    [1415] = 'tie_switch_no_close',
    [1416] = 'line_conduct_volt_imbalance',
    [1601] = 'auto_gen_start',
    [1602] = 'auto_gen_stop',
    [1603] = 'manual_gen_start',
    [1604] = 'manual_gen_stop',
    [1605] = 'manual_gen_err',
    [1606] = 'gen_requested',
    [1607] = 'gen_started',
    [1608] = 'gen_stopped',
    [1609] = 'low_battery_soc',
    [1610] = 'grid_disconnect',
    [1611] = 'power_limit_exceed',
    [1612] = 'power_limit_not_reached',
    [1613] = 'manual_grid_request',
    [1614] = 'manual_grid_disconnect',
    [1615] = 'blocking_of_gen',
    [1616] = 'no_sync_with_gen',
    [1701] = 'auto_freq_control_intervene',
    [1702] = 'auto_freq_control_end',
    [1704] = 'gen_operation_not_possible',
    [1705] = 'invalid_grid_volt',
    [1706] = 'multicluster_box_fault',
    [1707] = 'overvoltage',
    [1708] = 'overfreq',
    [1709] = 'underfreq',
    [1710] = 'volt_ac1_low',
    [1711] = 'volt_ac1_undesired',
    [1712] = 'open_tie_switch',
    [1713] = 'missing_line_conductor',
    [3809] = 'inverter_bridge_overcurrent',
    [6316] = 'measurement_intereference',
    [6463] = 'device_fault',
    [6465] = 'incorrect_processor_volt',
    [6466] = 'defective_volt_supply',
    [6609] = 'overload_volt_low',
    [6610] = 'overload_volt_high',
    [6612] = 'excessive_current',
    [6613] = 'high_power',
    [6614] = 'overload_5min_capacity',
    [6615] = 'overload_30min_capacity',
    [6616] = 'overload_shortterm_capacity',
    [7010] = 'short_circuit_battery_temp_sensor',
    [7011] = 'cable_break_battery_temp_sensor',
    [7101] = 'defective_sd_memory_card',
    [7102] = 'param_file_not_found_defective',
    [27103] = 'set_param',
    [27104] = 'set_param_succeeded',
    [7105] = 'set_param_failed',
    [7106] = 'update_failed',
    [27107] = 'update_ok',
    [27108] = 'read_sd_card',
    [27109] = 'no_update_sd_card',
    [7110] = 'no_update_file_found',
    [7112] = 'update_file_copy_success',
    [7113] = 'sd_card_protected',
    [27301] = 'update_communication',
    [27302] = 'update_main_cpu',
    [7303] = 'update_main_cpu_failed',
    [27312] = 'update_completed',
    [7329] = 'firmware_update_success',
    [7330] = 'condition_test_failed',
    [7331] = 'update_transport_started',
    [7332] = 'update_transport_success',
    [7333] = 'update_transport_fail',
    [7341] = 'update_bootloader',
    [7342] = 'update_bootloader_failed',
    [7601] = 'communication_error_ipc',
    [7602] = 'internal_can_comm_missing',
    [7608] = 'cluster_internal_comm_interrupt',
    [7609] = 'energy_meter_comm_fault',
    [7611] = 'energy_meter_protocol_fault',
    [7617] = 'mc_box_comm_interrupted',
    [7618] = 'cluster_can_fault',
    [7619] = 'meter_unit_comm_fault',
    [7620] = 'grid_power_meter_comm_fault',
    [7716] = 'tie_switch_does_not_open',
    [7717] = 'neutral_conduct_relay_fault',
    [7718] = 'transfer_relay_fault',
    [7719] = 'mc_box_plausibility_check_fail',
    [8003] = 'reduced_battery_charge_overheat',
    [8609] = 'slave_fault_status',
    [8610] = 'cluster_config_error',
    [8611] = 'cluster_config_error',
    [8612] = 'master_comm_interrupt',
    [8613] = 'cannot_measure_cluster_volt',
    [8615] = 'box_encoding_fault',
    [8616] = 'short_circuit_on_load_side',
    [8617] = 'cluster_incorrect_country_standard',
    [8620] = 'cluster_another_firmware_version',
    [8706] = 'setpoint_activated',
    [8707] = 'setpoint_deactivated',
    [8716] = 'saving_mode',
    [9002] = 'sma_grid_guard_code_invalid',
    [9003] = 'grid_parameter_locked',
    [29004] = 'grid_parameters_unchanged',
    [9301] = 'reset_battery_management',
    [9308] = 'bms_timeout',
    [9313] = 'temp_low_limit_undercut',
    [9314] = 'temp_upper_limit_exceed',
    [9318] = 'emergency_charge',
    [9319] = 'battery_float_charge',
    [9320] = 'battery_boost_charge',
    [9321] = 'battery_full_charge',
    [9322] = 'calibration_20_per_done',
    [9324] = 'low_soh',
    [9325] = 'recalibration_jump',
    [9326] = 'battery_protection_mode_on',
    [9331] = 'battery_voltage_above_range',
    [9332] = 'bms_not_configured',
    [9333] = 'battery_voltage_below_range',
    [9341] = 'battery_equalization_charge',
    [9362] = 'deep_discharge_area',
    [9401] = 'saving_mode_slaves_single_phase',
    [9402] = 'saving_mode_at_grid',
    [9403] = 'saving_mode_start',
    [9404] = 'saving_mode_stop',
    [9601] = 'di_status_changed',
    [10001] = 'parallel_grid_operation',
    [10003] = 'operation_status',
    [10004] = 'cold_start_status',
    [10006] = 'startup_status',
    [10007] = 'stop_status',
    [10010] = 'restart_diagnosis_system',
    [10060] = 'gen_operation',
    [10061] = 'feeding_network_op',
    [10100] = 'param_set_success',
    [10102] = 'param_set_success',
    [10101] = 'param_set_fail',
    [10103] = 'param_set_fail',
    [10108] = 'old_time',
    [10109] = 'new_time',
    [10110] = 'time_sync_failed',
    [10114] = 'ntp_server_no_info',
    [10117] = 'invalid_time',
    [10118] = 'param_upload_success',
    [10121] = 'param_xx_set_fail1',
    [10122] = 'param_xx_set_fail2',
    [10248] = 'network_busy',
    [10249] = 'network_busy',
    [10250] = 'package_error_rate_changed',
    [10283] = 'wifi_module_fault',
    [10414] = 'shutdown_due_to_fault',
    [10415] = 'automatic_start',
    [10416] = 'manual_start',
    [10417] = 'manual_stop',
    [10418] = 'system_control_start',
    [10419] = 'system_control_stop',
    [10420] = 'self_consumpt_control_start',
    [10421] = 'self_consumpt_control_stop',
    [10422] = 'self_consumpt_only_charge',
    [10423] = 'charge_active_self_consumpt',
    [10424] = 'back_to_self_consumption',
    [10425] = 'switch_off',
    [10517] = 'dynamic_act_pow_limit_start',
    [10518] = 'dynamic_act_pow_limit_terminate',
    [10704] = 'current_sensor_defective',
  }

  local alert = event_map[value]
  if alert then
    return { alert }
  end

  -- Range-based alerts
  if value >= 6120 and value <= 6135 then
    return { 'ocu_watchdog_triggered' }
  elseif value >= 6502 and value <= 6514 then
    return { 'overtemperature' }
  elseif value >= 7002 and value <= 7004 then
    return { 'fan_sensor_error' }
  elseif value >= 8101 and value <= 8104 then
    return { 'comm_impaired' }
  end

  return {}
end

-- Firmware version parsing

function parse_firmware_version(value)
  if not value then
    return
  end

  local release_id = value & 0xFF
  local build = (value >> 8) & 0xFF
  local minor = (value >> 16) & 0xFF
  local major = (value >> 24) & 0xFF

  local release_map = {
    [0] = 'N',
    [1] = 'E',
    [2] = 'A',
    [3] = 'B',
    [4] = 'R',
    [5] = 'S',
  }

  local release = release_map[release_id] or tostring(release_id)

  return major .. '.' .. minor .. '.' .. build .. '.' .. release
end

-- Country code parsing

function parse_country_code(value)
  if not value then
    return
  end

  local codes = {
    [1199] = 'PPDS',
    [27] = 'Adj',
    [306] = 'Off-Grid60',
    [313] = 'Off-Grid50',
    [333] = 'PPC',
    [42] = 'AS4777.3',
    [438] = 'VDE0126-1-1',
    [7504] = 'SI4777-2',
    [7508] = 'JP50',
    [7509] = 'JP60',
    [7510] = 'VDE-AR-N4105',
    [7513] = 'VDE-AR-N4105-MP',
    [7514] = 'VDE-AR-N4105-HP',
    [7517] = 'CEI0-21Int',
    [7518] = 'CEI0-21Ext',
    [7523] = 'C10/11/2012',
    [7525] = 'G83/2',
    [7527] = 'VFR2014',
    [7528] = 'G59/3',
    [7530] = 'MEA2013',
    [7531] = 'PEA2013',
    [7532] = 'EN50438_2013',
    [7533] = 'NEN-EN50438_13',
    [7535] = 'WorstCase',
    [7536] = 'DftEN',
    [7538] = 'SI4777_HS131_13',
    [7539] = 'RD1699/413',
    [7549] = 'AS4777.2_2015',
    [7550] = 'NRS97-2-1',
    [7551] = 'NT_Ley2057',
    [7556] = 'MEA2016',
    [7557] = 'PEA2016',
    [7559] = 'UL1741/2016/120',
    [7560] = 'UL1741/2016/240',
    [7561] = 'UL1741/2016/208',
    [7562] = 'HECO2017/120',
    [7563] = 'HECO2017/208',
    [7564] = 'HECO2017/240',
    [7565] = 'ABNT_NBR_16149_2013',
    [7566] = 'IE-EN50438_2013',
    [7567] = 'DEWA_2016_intern',
    [7568] = 'DEWA_2016_extern',
    [7569] = 'TOR_D4_2016',
    [7573] = 'G83/2-1_2018',
    [7574] = 'G59/3-4_2018',
    [7584] = 'VDEARN4105/18a',
    [7586] = 'VDEARN4105/18c',
    [7590] = 'EN50549-1/18',
    [7592] = 'DftSMA/19',
    [7594] = 'ENA-G98/1/18',
    [7595] = 'ENA-G99/1/18',
    [7599] = 'DK1-West/19',
    [7600] = 'DK2-East/19',
    [7602] = 'BE-C10/11/19-09 PV_a',
    [7603] = 'BE-C10/11/19-09 PV_b',
    [7610] = 'IT-CEI0-21/19_a',
    [7612] = 'IT-CEI0-21/19_c',
    [7615] = 'AT-TOR-Erzeuger-A/19_b',
  }

  local code = codes[value]
  if code then
    return code
  end

  enapter.log('Cannot decode country code: ' .. tostring(value), 'error')
  return nil
end

-- Battery type parsing

function parse_battery_type(value)
  if not value then
    return
  end

  if value == 1782 or value == 1783 then
    return 'lead_based'
  elseif value == 1785 then
    return 'lithium_based'
  else
    enapter.log('Cannot decode battery type: ' .. tostring(value), 'error')
    return 'other'
  end
end
