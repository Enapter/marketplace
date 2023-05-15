-- In order to reduce telemetry size some metrics are commented out.
-- If needed uncomment them and add to manifest.yml.

local commands = {
  device_rating_info = {
    command = 'QPIRI',
    data = {
      -- grid_rating_voltage = 1,
      -- grid_rating_current = 2,
      -- ac_out_volt = 3,
      -- ac_out_freq = 4,
      -- ac_out_current = 5,
      ac_out_apparent_power = 6,
      -- ac_out_active_power = 7,
      -- battery_volt = 8,
      -- battery_recharge_voltage = 9,
      -- battery_under_voltage = 10,
      -- battery_bulk_voltage = 11,
      -- battery_float_voltage = 12,
      -- battery_type = 13,
      -- max_ac_charging_current = 14,
      -- max_charging_current = 15,
      -- input_voltage_range = 16,
      -- output_source_priority = 17,
      -- charger_source_priority = 18,
      parallel_max_num = 19,
      -- machine_type = 20,
      -- topology = 21,
      output_mode = 22,
      -- battery_discharge_voltage = 23,
      -- pv_ok_condition_for_parallel = 24,
      -- pv_power_balance = 25,
    },
  },
  firmware_version = {
    command = 'QVFW',
  },
  serial_number = {
    command = 'QID',
  },
  device_protocol = {
    command = 'QPI',
  },
  output_mode = {
    command = 'QOPM',
    values = {},
  },
  device_mode = {
    command = 'QMOD',
    values = {
      P = 'power_on',
      S = 'standby',
      L = 'line',
      B = 'battery',
      F = 'error',
      H = 'power_saving',
    },
  },
  set_priorities = {
    charger = {
      cmd = 'PCP0',
      values = {},
    },
    output = {
      cmd = 'POP0',
      values = {},
    },
  },
  parallel_info = {
    command = 'QPGS',
    data = {
      general = {
        num = {
          parallel_num_exists = 1,
          grid_volt = 5,
          grid_freq = 6,
          ac_out_volt = 7,
          ac_out_freq = 8,
          ac_out_apparent_power = 9,
          ac_out_active_power = 10,
          load_percentage = 11,
          battery_charge_current = 13,
          pv_input_volt = 15,
          -- inverter_status = 20,
          charger_source_priority = 22,
          -- max_charger_current = 23,
          -- max_charger_range = 24,
          pv_input_amp = 26,
          battery_discharge_current = 27,
          -- in reality device can send 2 metrics on positions 28 and 29
          -- which are not described in protocol
          pv2_input_volt = 28,
          pv2_input_amp = 29,
        },
        str = {
          serial_number = 2,
          fault_code = 4,
          output_mode = 21,
        },
      },
      total = {
        num = {
          battery_volt = 12,
          battery_capacity = 14,
          total_charging_current = 16,
          total_ac_out_apparent_power = 17,
          total_ac_out_active_power = 18,
          total_ac_out_percentage = 19,
        },
        str = {
          work_mode = 3, -- theoretically you can't set different work modes for parallel devices
        },
      },
    },
    fault_codes = {},
  },
}

commands.parallel_info.fault_codes['01'] = 'fan_locked'
commands.parallel_info.fault_codes['02'] = 'over_temperature'
commands.parallel_info.fault_codes['03'] = 'battery_voltage_is_too_high'
commands.parallel_info.fault_codes['04'] = 'battery_voltage_is_too_low'
commands.parallel_info.fault_codes['05'] = 'output_short_circuited_or_over_temperature'
commands.parallel_info.fault_codes['06'] = 'output_voltage_is_too_high'
commands.parallel_info.fault_codes['07'] = 'over_load_time_out'
commands.parallel_info.fault_codes['08'] = 'bus_voltage_is_too_high'
commands.parallel_info.fault_codes['09'] = 'bus_soft_start_failed'
commands.parallel_info.fault_codes['11'] = 'main_relay_failed'
commands.parallel_info.fault_codes['51'] = 'over_current_inverter'
commands.parallel_info.fault_codes['53'] = 'inverter_soft_start_failed'
commands.parallel_info.fault_codes['54'] = 'self_test_failed'
commands.parallel_info.fault_codes['55'] = 'over_dc_voltage_on_output_of_inverter'
commands.parallel_info.fault_codes['56'] = 'battery_connection_is_open'
commands.parallel_info.fault_codes['57'] = 'current_sensor_failed'
commands.parallel_info.fault_codes['58'] = 'output_voltage_is_too_low'
commands.parallel_info.fault_codes['60'] = 'inverter_negative_power'
commands.parallel_info.fault_codes['71'] = 'parallel_version_different'
commands.parallel_info.fault_codes['72'] = 'output_circuit_failed'
commands.parallel_info.fault_codes['80'] = 'can_communication_failed'
commands.parallel_info.fault_codes['81'] = 'parallel_host_line_lost'
commands.parallel_info.fault_codes['82'] = 'parallel_synchronized_signal_lost'
commands.parallel_info.fault_codes['83'] = 'parallel_battery_voltage_detect_different'
commands.parallel_info.fault_codes['84'] = 'parallel_line_voltage_or_frequency_detect_different'
commands.parallel_info.fault_codes['85'] = 'parallel_line_input_current_unbalanced'
commands.parallel_info.fault_codes['86'] = 'parallel_output_setting_different'

commands.output_mode.values['0'] = 'Single'
commands.output_mode.values['1'] = 'Parallel'
commands.output_mode.values['2'] = 'Phase 1'
commands.output_mode.values['3'] = 'Phase 2'
commands.output_mode.values['4'] = 'Phase 3'

commands.set_priorities.output.values[0] = 'Utility first'
commands.set_priorities.output.values[1] = 'Solar first'
commands.set_priorities.output.values[2] = 'SBU'

commands.set_priorities.charger.values[0] = 'Utility first'
commands.set_priorities.charger.values[1] = 'Solar first'
commands.set_priorities.charger.values[2] = 'Solar and utility'
commands.set_priorities.charger.values[3] = 'Only solar'

return commands
