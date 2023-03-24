local function flag_a_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, 'AnodeOverPressure')
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, 'AnodeUnderPressure')
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, 'Stack1OverCurrent')
  end
  if flag & 0x10000000 ~= 0 then
    table.insert(errors, 'Outlet1OverTemperature')
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, 'Stack1MinCellUndervoltage')
  end
  if flag & 0x04000000 ~= 0 then
    table.insert(errors, 'Inlet1OverTemperature')
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, 'SafetyObserverWatchdogTrip')
  end
  if flag & 0x01000000 ~= 0 then
    table.insert(errors, 'BoardOverTemperature')
  end
  if flag & 0x00800000 ~= 0 then
    table.insert(errors, 'SafetyObserverFanTrip')
  end
  if flag & 0x00400000 ~= 0 then
    table.insert(errors, 'ValveDefeatCheckFault')
  end
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, 'Stack1UnderVoltage')
  end
  if flag & 0x00100000 ~= 0 then
    table.insert(errors, 'Stack1OverVoltage')
  end
  if flag & 0x00080000 ~= 0 then
    table.insert(errors, 'SafetyObserverMismatch')
  end
  if flag & 0x00040000 ~= 0 then
    table.insert(errors, 'Stack2MinCellUndervoltage')
  end
  if flag & 0x00020000 ~= 0 then
    table.insert(errors, 'SafetyObserverPressureTrip')
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, 'SafetyObserverBoardTxTrip')
  end
  if flag & 0x00008000 ~= 0 then
    table.insert(errors, 'Stack3MinCellUndervoltage')
  end
  if flag & 0x00004000 ~= 0 then
    table.insert(errors, 'SafetyObserverSoftwareTrip')
  end
  if flag & 0x00002000 ~= 0 then
    table.insert(errors, 'Fan2NoTacho')
  end
  if flag & 0x00001000 ~= 0 then
    table.insert(errors, 'Fan1NoTacho')
  end
  if flag & 0x00000800 ~= 0 then
    table.insert(errors, 'Fan3NoTacho')
  end
  if flag & 0x00000400 ~= 0 then
    table.insert(errors, 'Fan3ErrantSpeed')
  end
  if flag & 0x00000200 ~= 0 then
    table.insert(errors, 'Fan2ErrantSpeed')
  end
  if flag & 0x00000100 ~= 0 then
    table.insert(errors, 'Fan1ErrantSpeed')
  end
  if flag & 0x00000080 ~= 0 then
    table.insert(errors, 'Sib1Fault')
  end
  if flag & 0x00000040 ~= 0 then
    table.insert(errors, 'Sib2Fault')
  end
  if flag & 0x00000020 ~= 0 then
    table.insert(errors, 'Sib3Fault')
  end
  if flag & 0x00000010 ~= 0 then
    table.insert(errors, 'Inlet1TxSensorFault')
  end
  if flag & 0x00000008 ~= 0 then
    table.insert(errors, 'Outlet1TxSensorFault')
  end
  if flag & 0x00000004 ~= 0 then
    table.insert(errors, 'InvalidSerialNumber')
  end
  if flag & 0x00000002 ~= 0 then
    table.insert(errors, 'Dcdc1CurrentWhenDisabled')
  end
  if flag & 0x00000001 ~= 0 then
    table.insert(errors, 'Dcdc1OverCurrent')
  end
  return errors
end

local function flag_b_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, 'AmbientOverTemperature')
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, 'Sib1CommsFault')
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, 'BoardTxSensorFault')
  end
  if flag & 0x10000000 ~= 0 then
    table.insert(errors, 'Sib2CommsFault')
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, 'LowLeakTestPressure')
  end
  if flag & 0x04000000 ~= 0 then
    table.insert(errors, 'Sib3CommsFault')
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, 'LouverOpenFault')
  end
  if flag & 0x01000000 ~= 0 then
    table.insert(errors, 'StateDependentUnexpectedCurrent1')
  end
  if flag & 0x00800000 ~= 0 then
    table.insert(errors, 'SystemTypeFault')
  end
  if flag & 0x00400000 ~= 0 then
    table.insert(errors, 'SystemTypeChanged')
  end
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, 'Dcdc2CurrentWhenDisabled')
  end
  if flag & 0x00100000 ~= 0 then
    table.insert(errors, 'Dcdc3CurrentWhenDisabled')
  end
  if flag & 0x00080000 ~= 0 then
    table.insert(errors, 'Dcdc2OverCurrent')
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
    table.insert(errors, 'Stack1VoltageMismatch')
  end
  if flag & 0x00004000 ~= 0 then
    table.insert(errors, 'Dcdc3OverCurrent')
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
  if flag & 0x00000100 ~= 0 then
    table.insert(errors, 'DenyStartUnderVoltage')
  end
  if flag & 0x00000080 ~= 0 then
    table.insert(errors, 'StateDependentUnexpectedCurrent2')
  end
  if flag & 0x00000040 ~= 0 then
    table.insert(errors, 'StateDependentUnexpectedCurrent3')
  end
  if flag & 0x00000020 ~= 0 then
    table.insert(errors, 'Stack2UnderVoltage')
  end
  if flag & 0x00000010 ~= 0 then
    table.insert(errors, 'Stack3UnderVoltage')
  end
  if flag & 0x00000008 ~= 0 then
    table.insert(errors, 'Stack2OverVoltage')
  end
  if flag & 0x00000004 ~= 0 then
    table.insert(errors, 'Stack3OverVoltage')
  end
  if flag & 0x00000002 ~= 0 then
    table.insert(errors, 'Stack2OverCurrent')
  end
  if flag & 0x00000001 ~= 0 then
    table.insert(errors, 'Stack3OverCurrent')
  end
  return errors
end

local function flag_c_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, 'Stack2VoltageMismatch')
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, 'Stack3VoltageMismatch')
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, 'Outlet2OverTemperature')
  end
  if flag & 0x10000000 ~= 0 then
    table.insert(errors, 'Outlet3OverTemperature')
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, 'Inlet2OverTemperature')
  end
  if flag & 0x04000000 ~= 0 then
    table.insert(errors, 'Inlet3OverTemperature')
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, 'Inlet2TxSensorFault')
  end
  if flag & 0x01000000 ~= 0 then
    table.insert(errors, 'Inlet3TxSensorFault')
  end
  if flag & 0x00800000 ~= 0 then
    table.insert(errors, 'Outlet2TxSensorFault')
  end
  if flag & 0x00400000 ~= 0 then
    table.insert(errors, 'Outlet3TxSensorFault')
  end
  if flag & 0x00200000 ~= 0 then
    table.insert(errors, 'FuelOn1LowMeanVoltage')
  end
  if flag & 0x00100000 ~= 0 then
    table.insert(errors, 'FuelOn2LowMeanVoltage')
  end
  if flag & 0x00080000 ~= 0 then
    table.insert(errors, 'FuelOn3LowMeanVoltage')
  end
  if flag & 0x00040000 ~= 0 then
    table.insert(errors, 'FuelOn1LowMinVoltage')
  end
  if flag & 0x00020000 ~= 0 then
    table.insert(errors, 'FuelOn2LowMinVoltage')
  end
  if flag & 0x00010000 ~= 0 then
    table.insert(errors, 'FuelOn3LowMinVoltage')
  end
  if flag & 0x00008000 ~= 0 then
    table.insert(errors, 'SoftwareTripShutdown')
  end
  if flag & 0x00004000 ~= 0 then
    table.insert(errors, 'SoftwareTripFault')
  end
  if flag & 0x00002000 ~= 0 then
    table.insert(errors, 'TurnAroundTimeWarning')
  end
  if flag & 0x00001000 ~= 0 then
    table.insert(errors, 'PurgeCheckShutdown')
  end
  if flag & 0x00000800 ~= 0 then
    table.insert(errors, 'OutputUnderVoltage')
  end
  if flag & 0x00000400 ~= 0 then
    table.insert(errors, 'OutputOverVoltage')
  end
  if flag & 0x00000200 ~= 0 then
    table.insert(errors, 'SafetyObserverVoltRailTrip')
  end
  if flag & 0x00000100 ~= 0 then
    table.insert(errors, 'SafetyObserverDiffPressureTrip')
  end
  if flag & 0x00000080 ~= 0 then
    table.insert(errors, 'PurgeMissedOnePxOpen')
  end
  if flag & 0x00000040 ~= 0 then
    table.insert(errors, 'PurgeMissedOnePxOpen')
  end
  if flag & 0x00000020 ~= 0 then
    table.insert(errors, 'PurgeMissedOneIxOpen')
  end
  if flag & 0x00000010 ~= 0 then
    table.insert(errors, 'PurgeMissedOneIxSolSaver')
  end
  if flag & 0x00000008 ~= 0 then
    table.insert(errors, 'PurgeMissedOneIxClose')
  end
  if flag & 0x00000004 ~= 0 then
    table.insert(errors, 'InRangeFaultPx01')
  end
  if flag & 0x00000002 ~= 0 then
    table.insert(errors, 'NoisyInputPx01')
  end
  if flag & 0x00000001 ~= 0 then
    table.insert(errors, 'NoisyInputTx68')
  end
  return errors
end

local function flag_d_error(flag)
  local errors = {}
  if flag & 0x80000000 ~= 0 then
    table.insert(errors, 'NoisyInputDiffP')
  end
  if flag & 0x40000000 ~= 0 then
    table.insert(errors, 'ValveClosedPxRising')
  end
  if flag & 0x20000000 ~= 0 then
    table.insert(errors, 'DiffPSensorFault')
  end
  if flag & 0x10000000 ~= 0 then
    table.insert(errors, 'LossOfVentilation')
  end
  if flag & 0x08000000 ~= 0 then
    table.insert(errors, 'DiffPSensorHigh')
  end
  if flag & 0x04000000 ~= 0 then
    table.insert(errors, 'FanOverrun')
  end
  if flag & 0x02000000 ~= 0 then
    table.insert(errors, 'BlockedAirFlow')
  end
  return errors
end

local function make_alerts(telemetry)
  local flag_a, flag_b, flag_c, flag_d =
    telemetry['fault_flags_a'],
    telemetry['fault_flags_b'],
    telemetry['fault_flags_c'],
    telemetry['fault_flags_d']

  if flag_a == nil or flag_b == nil or flag_c == nil or flag_d == nil then
    return nil
  end

  local flag_a_errs = flag_a_error(flag_a)
  local flag_b_errs = flag_b_error(flag_b)
  local flag_c_errs = flag_c_error(flag_c)
  local flag_d_errs = flag_d_error(flag_d)

  local alerts = {}
  alerts = table.move(flag_a_errs, 1, #flag_a_errs, #alerts + 1, alerts)
  alerts = table.move(flag_b_errs, 1, #flag_b_errs, #alerts + 1, alerts)
  alerts = table.move(flag_c_errs, 1, #flag_c_errs, #alerts + 1, alerts)
  alerts = table.move(flag_d_errs, 1, #flag_d_errs, #alerts + 1, alerts)
  return alerts
end

return {
  make_from_telemetry = make_alerts,
}
