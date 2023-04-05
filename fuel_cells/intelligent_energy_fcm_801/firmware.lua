local config = require('enapter.ucm.config')

INDEX_CONFIG = 'index'
SAVE_0x400_CONFIG = 'save_0x400'

VENDOR = 'Intelligent Energy'
MODEL = 'FCM 801'

configured = false
telemetry = {}
total_can_packets = 0
is_serial_number_completed = false
serial_number = nil
fw_ver = nil
temp_serial_number = ''
ab_alerts = nil
cd_alerts = nil

can_index = 1
save_0x400 = false
messages_0x400 = {}

function main()
  local result = can.init(500, can_handler)
  if result ~= 0 then
    enapter.log('CAN failed: ' .. result .. ' ' .. can.err_to_str(result), 'error', true)
  end

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  config.init({
    [INDEX_CONFIG] = { type = 'number', default = 1, required = true },
    [SAVE_0x400_CONFIG] = { type = 'boolean', default = false },
  }, {
    after_write = setup_options,
  })

  local args, err = config.read_all()
  if err == nil then
    setup_options(args)
  else
    enapter.log('failed to read config: ' .. err, 'error', true)
  end
end

function setup_options(args)
  can_index = args[INDEX_CONFIG]
  save_0x400 = args[SAVE_0x400_CONFIG]
  configured = true
end

function send_properties()
  local info = { vendor = VENDOR, model = MODEL }

  if is_serial_number_completed then
    info['serial_number'] = serial_number
    is_serial_number_completed = false
  end
  info['fw_ver'] = fw_ver

  enapter.send_properties(info)
end

function send_telemetry()
  if not configured then
    enapter.send_telemetry({ alerts = { 'not_configured' } })
    return
  end

  telemetry['total_can_packets'] = total_can_packets

  local str_0x400
  for _, data in pairs(messages_0x400) do
    local str_0x400_part =
      string.format('%02x%02x%02x%02x%02x%02x%02x%02x', string.unpack('I1I1I1I1I1I1I1I1', data))
    str_0x400 = str_0x400 or ''
    str_0x400 = str_0x400 .. ' ' .. str_0x400_part
  end
  telemetry['messages_0x400'] = str_0x400
  messages_0x400 = {}

  -- Make sure to add alerts only if it was really reported by the FC
  -- to avoid accidental cleaning of alerts in the Cloud
  if ab_alerts and cd_alerts then
    telemetry.alerts = ab_alerts
    table.move(cd_alerts, 1, #cd_alerts, #telemetry.alerts + 1, telemetry.alerts)
    ab_alerts = nil
    cd_alerts = nil
  end

  enapter.send_telemetry(telemetry)
  telemetry = {}
end

function can_handler(msg_id, data)
  total_can_packets = total_can_packets + 1

  local rx_scale_factor10 = 10.0
  local rx_scale_factor100 = 100.0

  if msg_id == (0x400 + can_index - 1) and save_0x400 then
    table.insert(messages_0x400, data)
  elseif msg_id == (0x310 + can_index - 1) then
    if not is_serial_number_completed then
      if string.byte(data, 1) > 127 then
        if #temp_serial_number == 8 then
          local serial_number_part =
            string.char(string.byte(data, 1, 1) - 128, string.byte(data, 2, 8))
          temp_serial_number = temp_serial_number .. serial_number_part
          serial_number = temp_serial_number
          is_serial_number_completed = true
        else
          temp_serial_number = ''
          is_serial_number_completed = false
        end
      else
        temp_serial_number = string.char(string.byte(data, 1, 8))
      end
    end
  elseif msg_id == (0x318 + can_index - 1) then
    fw_ver = software_version(data)
  elseif msg_id == (0x320 + can_index - 1) then
    telemetry['run_hours'] = touint32(string.sub(data, 1, 4))
    telemetry['total_run_energy'] = touint32(string.sub(data, 5, 8))
  elseif msg_id == (0x328 + can_index - 1) then
    local flag_a, flag_b = touint32(string.sub(data, 1, 4)), touint32(string.sub(data, 5, 8))
    telemetry['fault_flags_a'] = flag_a
    telemetry['fault_flags_b'] = flag_b
    local flag_a_errs = flag_a_error(flag_a)
    local flag_b_errs = flag_b_error(flag_b)
    ab_alerts = {}
    ab_alerts = table.move(flag_a_errs, 1, #flag_a_errs, 1, ab_alerts)
    ab_alerts = table.move(flag_b_errs, 1, #flag_b_errs, #ab_alerts + 1, ab_alerts)
  elseif msg_id == (0x338 + can_index - 1) then
    telemetry['watt'] = toint16(string.sub(data, 1, 2))
    telemetry['volt'] = toint16(string.sub(data, 3, 4)) / rx_scale_factor100
    telemetry['amp'] = toint16(string.sub(data, 5, 6)) / rx_scale_factor100
    telemetry['anode_pressure'] = toint16(string.sub(data, 7, 8)) / rx_scale_factor10
  elseif msg_id == (0x348 + can_index - 1) then
    telemetry['outlet_temp'] = toint16(string.sub(data, 1, 2)) / rx_scale_factor100
    telemetry['inlet_temp'] = toint16(string.sub(data, 3, 4)) / rx_scale_factor100
    telemetry['dcdc_volt_setpoint'] = toint16(string.sub(data, 5, 6)) / rx_scale_factor100
    telemetry['dcdc_amp_limit'] = toint16(string.sub(data, 7, 8)) / rx_scale_factor100
  elseif msg_id == (0x358 + can_index - 1) then
    telemetry['louver_pos'] = toint16(string.sub(data, 1, 2)) / rx_scale_factor100
    telemetry['fan_sp_duty'] = toint16(string.sub(data, 3, 4)) / rx_scale_factor100
  elseif msg_id == (0x368 + can_index - 1) then
    telemetry['status'] = parse_state(string.byte(data, 1))
    -- telemetry["load_logic"] = string.byte(data, 2)
    -- telemetry["out_bits"] = string.byte(data, 3)
  elseif msg_id == (0x378 + can_index - 1) then
    local flag_c, flag_d = touint32(string.sub(data, 1, 4)), touint32(string.sub(data, 5, 8))
    telemetry['fault_flags_c'] = flag_c
    telemetry['fault_flags_d'] = flag_d
    local flag_c_errs = flag_c_error(flag_c)
    local flag_d_errs = flag_d_error(flag_d)
    cd_alerts = {}
    cd_alerts = table.move(flag_c_errs, 1, #flag_c_errs, 1, cd_alerts)
    cd_alerts = table.move(flag_d_errs, 1, #flag_d_errs, #cd_alerts + 1, cd_alerts)
  end
end

function toint16(data)
  return string.unpack('>i2', data)
end

function touint32(data)
  return string.unpack('>I4', data)
end

function parse_state(state)
  if state == 0x10 then
    return 'fault'
  elseif state == 0x20 then
    return 'steady'
  elseif state == 0x40 then
    return 'run'
  elseif state == 0x80 then
    return 'inactive'
  else
    return nil
  end
end

function software_version(data)
  return string.format('%u.%u.%u', string.byte(data, 1), string.byte(data, 2), string.byte(data, 3))
end

function flag_a_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, 'AnodeOverPressure')
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, 'AnodeUnderPressure')
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, 'StackOverCurrent')
  end
  if flag & 0x10000000 ~= 0 then
    table.insert(errors, 'OutletOverTemperature')
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, 'MinCellUndervoltage')
  end
  if flag & 0x04000000 ~= 0 then
    table.insert(errors, 'InletOverTemperature')
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, 'HboWatchdogFault')
  end
  if flag & 0x01000000 ~= 0 then
    table.insert(errors, 'BoardOverTemperature')
  end
  if flag & 0x00800000 ~= 0 then
    table.insert(errors, 'HboFan1UnderSpeed')
  end
  if flag & 0x00400000 ~= 0 then
    table.insert(errors, 'ValveDefeatCheckFault')
  end
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, 'StackUnderVoltage')
  end
  if flag & 0x00100000 ~= 0 then
    table.insert(errors, 'StackOverVoltage')
  end
  if flag & 0x00080000 ~= 0 then
    table.insert(errors, 'SafetyObserverMismatch')
  end
  if flag & 0x00020000 ~= 0 then
    table.insert(errors, 'HboAnodeOverPressure')
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, 'HboBoardUnderTemperature')
  end
  if flag & 0x00004000 ~= 0 then
    table.insert(errors, 'HboAnodeUnderPressure')
  end
  if flag & 0x00002000 ~= 0 then
    table.insert(errors, 'HboBoardOverTemperature')
  end
  if flag & 0x00001000 ~= 0 then
    table.insert(errors, 'Fan1NoTacho')
  end
  if flag & 0x00000100 ~= 0 then
    table.insert(errors, 'Fan1ErrantSpeed')
  end
  if flag & 0x00000010 ~= 0 then
    table.insert(errors, 'InletTxSensorFault')
  end
  if flag & 0x00000008 ~= 0 then
    table.insert(errors, 'OutletTxSensorFault')
  end
  if flag & 0x00000004 ~= 0 then
    table.insert(errors, 'InvalidSerialNumber')
  end
  if flag & 0x00000002 ~= 0 then
    table.insert(errors, 'DcdcCurrentWhenDisabled')
  end
  if flag & 0x00000001 ~= 0 then
    table.insert(errors, 'DcdcOverCurrent')
  end
  return errors
end

function flag_b_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, 'AmbientOverTemperature')
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, 'SibCommsFault')
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, 'BoardTxSensorFault')
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, 'LowLeakTestPressure')
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, 'LouverOpenFault')
  end
  if flag & 0x01000000 ~= 0 then
    table.insert(errors, 'StateDependentUnexpectedCurrent')
  end
  if flag & 0x00800000 ~= 0 then
    table.insert(errors, 'SystemTypeFault')
  end
  if flag & 0x00040000 ~= 0 then
    table.insert(errors, 'ReadConfigFault')
  end
  if flag & 0x00020000 ~= 0 then
    table.insert(errors, 'CorruptConfigFault')
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, 'ConfigValueRangeFault')
  end
  if flag & 0x00008000 ~= 0 then
    table.insert(errors, 'StackVoltageMismatch')
  end
  if flag & 0x00002000 ~= 0 then
    table.insert(errors, 'UnexpectedPurgeInhibit')
  end
  if flag & 0x00001000 ~= 0 then
    table.insert(errors, 'FuelOnNoVolts')
  end
  if flag & 0x00000800 ~= 0 then
    table.insert(errors, 'LeakDetected')
  end
  if flag & 0x00000400 ~= 0 then
    table.insert(errors, 'AirCheckFault')
  end
  if flag & 0x00000200 ~= 0 then
    table.insert(errors, 'AirCheckFaultShadow')
  end
  return errors
end

function flag_c_error(flag)
  local errors = {}
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, 'PurgeCheckShutdown')
  end
  return errors
end

function flag_d_error(flag)
  local errors = {}
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, 'Dcdc1OutputFault')
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, 'CalcCoreTxSensorFault')
  end
  if flag & 0x00008000 ~= 0 then
    table.insert(errors, 'CalcCoreOverTemperature')
  end
  if flag & 0x00004000 ~= 0 then
    table.insert(errors, 'LouverFailedToOpen')
  end
  return errors
end

main()
