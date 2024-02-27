-- In order to reduce telemetry size some metrics are commented out.
-- If needed uncomment them and add to manifest.yml.

local commands = {
  device_protocol = {
    command = 'QPI',
  },
  serial_number = {
    command = 'QID',
  },
  firmware_version = {
    command = 'QVFW',
  },
  device_rating_info = {
    command = 'QPIRI',
    data = {
      max_output_power = 1,
      nominal_battery_voltage = 2,
      nominal_charging_current = 3,
      absorption_voltage_per_unit = 4,
      float_voltage_per_unit = 5,
      battery_type = 6,
      remote_battery_voltage_detect = 7,
      battery_temperature_compensation = 8,
      remote_temperature_detect = 9,
      battery_rated_voltage_set = 10,
      the_piece_of_battery_in_serial = 11,
      battery_low_warning_voltage = 12,
      battery_low_shutdown_detect = 13,
    },
  },
  general_parameters = {
    command = 'QPIGS',
    data = {
      pv_input_voltage = 1,
      battery_voltage = 2,
      charging_current = 3,
      charging_current_1 = 4,
      charging_current_2 = 5,
      charging_power = 6,
      -- unit_temperature = 7,
      -- remote_battery_voltage = 8,
      -- remote_battery_temperature = 9,
      -- reserved = 10,
      status = 11,
    },
  },
  device_warning_status = {
    command = 'QPIWS',
    general = {
      over_charge_current = 1,
      over_temperature = 2,
      battery_voltage_under = 3,
      battery_voltage_high = 4,
      pv_high_loss = 5,
      battery_temperature_too_low = 6,
      battery_temperature_too_high = 7,
      -- reserved = 8,
      -- reserved = 9,
      -- reserved = 13,
      -- reserved = 14,
      -- reserved = 15,
      -- reserved = 16,
      -- reserved = 17,
      -- reserved = 18,
      -- reserved = 19,
      pv_low_loss = 20,
      pv_high_derating = 21,
      temperature_high_derating = 22,
      battery_temperature_low_alarm = 23,
      battery_low_warning = 30,
    },
  },
}

return commands
