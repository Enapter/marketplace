-- QPIRI.grid_rating_voltage.name QPIRI.grid_rating_voltage.pos
local commands = {
  device_rating_info = {
    command = 'QPIRI',
    data = {
      start_byte = 0,
      grid_rating_voltage = 1,
      grid_rating_current = 2,
      ac_out_voltage = 3,
      ac_out_freq = 4,
      ac_out_current = 5,
      ac_out_apparent_power = 6,
      ac_out_active_power = 7,
      battery_voltage = 8,
      battery_recharge_voltage = 9,
      battery_under_voltage = 10,
      battery_bulk_voltage = 11,
      battery_float_voltage = 12,
      battery_type = 13,
      max_ac_charging_current = 14,
      max_charging_current = 15,
      input_voltage_range = 16,
      output_source_priority = 17,
      charger_source_priority = 18,
      parallel_max_num = 19,
      machine_type = 20,
      topology = 21,
      output_mode = 22,
      battery_discharge_voltage = 23,
      pv_ok_condition_for_parallel = 24,
      pv_power_balance = 25,
    }
  },
  firmware_version = {
    command = 'QVFW',
    data = {
      version = 1
    }
  },
  serial_number = {
    command = 'QID',
    data = {
      serial_number = 1
    }
  },
  device_protocol = {
    command = 'QPI',
    data = {
      protocol = 1
    }
  },
  general_status_parameters = {
    command = 'QPIGS',
    data = {
      grid_volt = 1,
      grid_freq = 2,
      ac_out_volt = 3,
      ac_out_freq = 4,
      ac_out_apparent_power = 5,
      ac_out_active_power = 6,
      ac_out_load_percent = 7,
      dc_bus_volt= 8,
      battery_volt = 9,
      battery_charging_amp = 10,
      battery_capacity = 11,
      heat_sink_temperature = 12,
      pv_input_amp = 13,
      pv_input_volt = 14,
      battery_volt_scc = 15,
      battery_discharge_amp = 16,
      -- device_status = 17,
      -- fans_battery_voltage_offset = 18,
      -- eeprom_version = 19,
      -- pv_charging_power = 20,
      -- device_status1 = 21
    }
  },
  output_mode = {
    command = 'QOPM',
    data = {
      mode = 1,
    }
  },
  default_settings_info = {
    command = 'QDI',
    data = {
      ac_output_voltage = 1,
      ac_output_freq = 2,
      max_ac_charging_current = 3,
      battery_under_voltage = 4,
      charging_float_voltage = 5,
      charging_bulk_voltage = 6,
      battery_recharge_voltage = 7,
      max_charging_current = 8,
      ac_input_voltage_range = 9,
      output_source_priority = 10,
      charger_output_priority = 11,
      battery_type = 12,
      enable_buzzer = 13,
      power_saving = 14,
      overload_start = 15,
      over_temperature_restart = 16,
      lcd_backlight_on = 17,
    },
  },
  device_mode = {
    command = 'QMOD',
    data = {
      mode = 1
    }
  },
  device_warning_status = {
    command = 'QPIWS',
    general = {
      fault_flag = 1,
      inverter_fault = 2,
      bus_over = 3,
      bus_under = 4,
      bus_soft_fail = 5,
      line_fail = 6,
      inverter_voltage_low = 8,
      inverter_voltage_high = 9,
      battery_low_alarm = 13,
      battery_shutdown = 15,
      eeprom_fault = 18,
      inverter_over_current = 19,
      inverter_soft_fail = 20,
      self_test_fail = 21,
      output_dc_voltage_over = 22,
      battery_open = 23,
      current_sensor_fail = 24,
      battery_short = 25,
      power_limit = 26,
      pv_voltage_high = 27,
      mppt_overload_fault = 28,
      mppt_overload_warning = 29,
      battery_too_low_to_charge = 30,
    },
    dependent = {
      overtemperature = 10,
      fan_locked = 11,
      battery_voltage_high = 12,
      overload = 17,
    }
  },
  set_priorities = {
    charger =  {
      cmd = 'PCP0',
      min = 0,
      max = 4
    },
    output = {
      cmd = 'POP0',
      min = 0,
      max = 3
    }
  }
}
return commands
