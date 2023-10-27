local config = require('enapter.ucm.config')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
ADDRESS = 'address'

function main()
  scheduler.add(1000, send_telemetry)
  scheduler.add(30000, send_properties)
  config.init({
    [ADDRESS] = { type = 'number', required = true, default = 1 },
  })
end

function send_properties()
  enapter.send_properties({
    vendor = 'Deye',
    model = 'SUN-10k-SG04LP3-EU'
  })
end

function send_telemetry()
  local modbus = modbusrtu.new("/dev/ttyUSB0", {
    baud_rate=9600, data_bits=8, stop_bits=1, parity="N", read_timeout=1000
  })

  local addr, err = config.read(ADDRESS)
  if err ~= nil then
    enapter.send_telemetry({
      status = 'warning',
      alerts = {'config_read_error'}
    })
    return
  end

  local telemetry = {}

  local data, err = modbus:read_holdings(addr, 514, 13, 1000)
  if err ~= 0 then
    enapter.log('514-526: ' .. modbusrtu.err_to_str(err), 'error')
  else
    telemetry.total_battery_charge = data[1] * 0.1
    telemetry.total_battery_discharge = data[515 - 514 + 1] * 0.1
    telemetry.day_gridbuy_power = data[520 - 514 + 1] * 0.1
    telemetry.day_gridsell_power = data[521 - 514 + 1] * 0.1
    telemetry.day_load_power = data[526 - 514 + 1] * 0.1
  end

  local data, err = modbus:read_holdings(addr, 587, 5, 1000)
  if err ~= 0 then
    enapter.log('587-591: ' .. modbusrtu.err_to_str(err), 'error')
  else
    telemetry.battery_voltage = data[1] * 0.01
    telemetry.battery_output_power = data[590 - 587 + 1]
    telemetry.battery_output_current = data[591 - 587 + 1]
  end

  local data, err = modbus:read_holdings(addr, 604, 6, 1000)
  if err ~= 0 then
    enapter.log('604-609: ' .. modbusrtu.err_to_str(err), 'error')
  else
    telemetry.inner_grid_power_a = data[1]
    telemetry.inner_grid_power_b = data[605 - 604 + 1]
    telemetry.inner_grid_power_c = data[606 - 604 + 1]
    telemetry.total_active_power_side_to_side = data[607 - 604 + 1]
    telemetry.grid_frequency = data[609 - 604 + 1]
  end

  local data, err = modbus:read_holdings(addr, 616, 10, 1000)
  if err ~= 0 then
    enapter.log('616-619: ' .. modbusrtu.err_to_str(err), 'error')
  else
    telemetry.out_of_grid_power_a = data[1]
    telemetry.out_of_grid_power_b = data[617 - 616 + 1]
    telemetry.out_of_grid_power_c = data[618 - 616 + 1]
    telemetry.total_out_of_grid_power = data[619 - 616 + 1]
  end

  local data, err = modbus:read_holdings(addr, 622, 4, 1000)
  if err ~= 0 then
    enapter.log('622-625: ' .. modbusrtu.err_to_str(err), 'error')
  else
    telemetry.grid_power_a = data[1]
    telemetry.grid_power_b = data[2]
    telemetry.grid_power_c = data[3]
    telemetry.total_grid_power = data[4]
  end

  local data, err = modbus:read_holdings(addr, 633, 4, 1000)
  if err ~= 0 then
    enapter.log('633-636: ' .. modbusrtu.err_to_str(err), 'error')
  else
    telemetry.inverter_output_power_a = data[1]
    telemetry.inverter_output_power_b = data[2]
    telemetry.inverter_output_power_c = data[3]
    telemetry.total_inverter_output_power = data[4]
  end

  local data, err = modbus:read_holdings(addr, 650, 4, 1000)
  if err ~= 0 then
    enapter.log('650-653: ' .. modbusrtu.err_to_str(err), 'error')
  else
    telemetry.load_power_a = data[1]
    telemetry.load_power_b = data[2]
    telemetry.load_power_c = data[3]
    telemetry.total_load_power = data[4]
  end

  enapter.send_telemetry(telemetry)
end

main()
