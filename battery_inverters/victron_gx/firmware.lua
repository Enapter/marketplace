--
-- Victron VE.Bus integration through GX device Modbus.
-- Based on Excel file documentation Rev 32.
--
-- WARNING: This Lua firmware is used for system control. BE CAREFUL!
--
-- Format: [register] [writabe?] Attribute name; type; scale; [range]; path in dbus
--
---------------------
-- Registers Table
---------------------
-- [31] VE.Bus state; uint16; scale=1; [0 to 65536]; /State
--          0=off
--          1=low_power
--          2=fault
--          3=bulk
--          4=absorption
--          5=float
--          6=storage
--          7=equalize
--          8=passthru
--          9=inverting
--          10=power_assist
--          11=power_supply
--          252=bulk_protection
-- [32] VE.Bus Error; uint16; scale=1; [0 to 65536]; /vebus_unit_idError
--          0=No error
--          1=Device is switched off because one of the other phases in the system has switched off
--          2=New and old types MK2 are mixed in the system
--          3=Not all- or more than- the expected devices were found in the system
--          4=No other device whatsoever detected
--          5=Overvoltage on AC-out
--          6=Error in DDC Program
--          7=VE.Bus BMS connected- which requires an Assistant- but no assistant found
--          10=System time synchronisation problem occurred
--          14=Device cannot transmit data
--          16=Dongle missing
--          17=One of the devices assumed master status because the original master failed
--          18=AC Overvoltage on the output of a slave has occurred while already switched off
--          22=This device cannot function as slave
--          24=Switch-over system protection initiated
--          25=Firmware incompatibility. The firmware of one of the connected
--          device is not sufficiently up to date to operate in conjunction
--          with this device
--          26=Internal error
--
--
---------------------
----- AC
---------------------
-- [28] Phase count (count); uint16; scale=1; [0 to 65536]; /Ac/NumberOfPhases
-- [29] Active input; uint16; scale=1; [0 to 65536]; /Ac/ActiveIn/ActiveInput
--          0=ac_input_1
--          1=ac_input_2
--          240=disconnected
--
-- [3] Input voltage phase 1 (V AC); uint16; scale=10; [0 to 6553.5]; /Ac/ActiveIn/L1/V
-- [4] Input voltage phase 2 (V AC); uint16; scale=10; [0 to 6553.5]; /Ac/ActiveIn/L2/V
-- [5] Input voltage phase 3 (V AC); uint16; scale=10; [0 to 6553.5]; /Ac/ActiveIn/L3/V
-- [6] Input current phase 1 (A AC); int16; scale=10; [-3276.8 to 3276.7]; /Ac/ActiveIn/L1/I
--          Positive: current flowing from mains to Multi. Negative: current flowing from Multi to mains.
-- [7] Input current phase 2 (A AC); int16; scale=10; [-3276.8 to 3276.7]; /Ac/ActiveIn/L2/I
--          Positive: current flowing from mains to Multi. Negative: current flowing from Multi to mains.
-- [8] Input current phase 3 (A AC); int16; scale=10; [-3276.8 to 3276.7]; /Ac/ActiveIn/L3/I
--          Positive: current flowing from mains to Multi. Negative: current flowing from Multi to mains.
-- [9] Input frequency 1 (Hz); int16; scale=100; [-327.68 to 327.67]; /Ac/ActiveIn/L1/F
-- [10] Input frequency 2 (Hz); int16; scale=100; [-327.68 to 327.67]; /Ac/ActiveIn/L2/F
-- [11] Input frequency 3 (Hz); int16; scale=100; [-327.68 to 327.67]; /Ac/ActiveIn/L3/F
-- [12] Input power 1 (VA or Watts); int16; scale=0,1; [-327680 to 327670]; /Ac/ActiveIn/L1/P
--          Sign meaning equal to Input current
-- [13] Input power 2 (VA or Watts); int16; scale=0,1; [-327680 to 327670]; /Ac/ActiveIn/L2/P
--          Sign meaning equal to Input current
-- [14] Input power 3 (VA or Watts); int16; scale=0,1; [-327680 to 327670]; /Ac/ActiveIn/L3/P
--          Sign meaning eaqual to Input current
-- [22] [w] Active input current limit (A); int16; scale=10; [-3276.8 to 3276.7]; /Ac/ActiveIn/CurrentLimit
--
-- [21] Output frequency (Hz); int16; scale=100; [-327.68 to 327.67]; /Ac/Out/L1/F
--          See Venus-OS manual for limitations, for example when VE.Bus BMS or DMC is installed.
-- [15] Output voltage phase 1 (V AC); uint16; scale=10; [0 to 6553.5]; /Ac/Out/L1/V
-- [16] Output voltage phase 2 (V AC); uint16; scale=10; [0 to 6553.5]; /Ac/Out/L2/V
-- [17] Output voltage phase 3 (V AC); uint16; scale=10; [0 to 6553.5]; /Ac/Out/L3/V
-- [18] Output current phase 1 (A AC); int16; scale=10; [-3276.8 to 3276.7]; /Ac/Out/L1/I
--          Postive: current flowing from Multi to the load. Negative: current flowing from load to the Multi.
-- [19] Output current phase 2 (A AC); int16; scale=10; [-3276.8 to 3276.7]; /Ac/Out/L2/I
--          Postive: current flowing from Multi to the load. Negative: current flowing from load to the Multi.
-- [20] Output current phase 3 (A AC); int16; scale=10; [-3276.8 to 3276.7]; /Ac/Out/L3/I
--          Postive: current flowing from Multi to the load. Negative: current flowing from load to the Multi.
-- [23] Output power 1 (VA or Watts); int16; scale=0,1; [-327680 to 327670]; /Ac/Out/L1/P
--          Sign meaning equal to Output current
-- [24] Output power 2 (VA or Watts); int16; scale=0,1; [-327680 to 327670]; /Ac/Out/L2/P
--          Sign meaning equal to Output current
-- [25] Output power 3 (VA or Watts); int16; scale=0,1; [-327680 to 327670]; /Ac/Out/L3/P
--          Sign meaning equal to Output current
--
--
---------------------
----- DC
---------------------
-- [26] Battery voltage (V DC); uint16; scale=100; [0 to 655.35]; /Dc/0/Voltage
-- [27] Battery current (A DC); int16; scale=10; [-3276.8 to 3276.7]; /Dc/0/Current
--          Positive: current flowing from the Multi to the dc system. Negative: the other way around.
-- [61] Battery temperature (Degrees celsius); int16; scale=10; [-3276.8 to 3276.7]; /Dc/0/Temperature
-- [30] VE.Bus state of charge (%); uint16; scale=10; [0 to 6553.5]; /Soc
--
--
---------------------
----- BMS
---------------------
-- [57] VE.Bus BMS allows battery to be charged (VE.Bus BMS allows the battery
-- to be charged); uint16; scale=1; [0 to 65536]; /Bms/AllowToCharge
--          0=no
--          1=yes
-- [58] VE.Bus BMS allows battery to be discharged (VE.Bus BMS allows the
-- battery to be discharged); uint16; scale=1; [0 to 65536];
-- /Bms/AllowToDischarge
--          0=no
--          1=yes
-- [59] VE.Bus BMS is expected; uint16; scale=1; [0 to 65536]; /Bms/BmsExpected
--          0=no
--          1=yes
--          Presence of VE.Bus BMS is expected based on vebus_unit_id settings
--          (presence of ESS or BMS assistant)
-- [60] VE.Bus BMS error; uint16; scale=1; [0 to 65536]; /Bms/Error
--          0=no
--          1=yes
--
--
---------------------
----- Alarms
---------------------
-- Values:
--   0=ok
--   1=warning
--   2=alarm
--
-- [34] Temperature alarm; uint16; scale=1; [0 to 65536]; /Alarms/HighTemperature
-- [35] Low battery alarm; uint16; scale=1; [0 to 65536]; /Alarms/LowBattery
-- [36] Overload alarm; uint16; scale=1; [0 to 65536]; /Alarms/Overload
-- [42] Temperatur sensor alarm; uint16; scale=1; [0 to 65536]; /Alarms/TemperatureSensor
-- [43] Voltage sensor alarm; uint16; scale=1; [0 to 65536]; /Alarms/VoltageSensor
-- [44] Temperature alarm L1; uint16; scale=1; [0 to 65536]; /Alarms/L1/HighTemperature
-- [45] Low battery alarm L1; uint16; scale=1; [0 to 65536]; /Alarms/L1/LowBattery
-- [46] Overload alarm L1; uint16; scale=1; [0 to 65536]; /Alarms/L1/Overload
-- [47] Ripple alarm L1; uint16; scale=1; [0 to 65536]; /Alarms/L1/Ripple
-- [48] Temperature alarm L2; uint16; scale=1; [0 to 65536]; /Alarms/L2/HighTemperature
-- [49] Low battery alarm L2; uint16; scale=1; [0 to 65536]; /Alarms/L2/LowBattery
-- [50] Overload alarm L2; uint16; scale=1; [0 to 65536]; /Alarms/L2/Overload
-- [51] Ripple alarm L2; uint16; scale=1; [0 to 65536]; /Alarms/L2/Ripple
-- [52] Temperature alarm L3; uint16; scale=1; [0 to 65536]; /Alarms/L3/HighTemperature
-- [53] Low battery alarm L3; uint16; scale=1; [0 to 65536]; /Alarms/L3/LowBattery
-- [54] Overload alarm L3; uint16; scale=1; [0 to 65536]; /Alarms/L3/Overload
-- [55] Ripple alarm L3; uint16; scale=1; [0 to 65536]; /Alarms/L3/Ripple
-- [63] Phase rotation warning; uint16; scale=1; [0 to 65536]; /Alarms/PhaseRotation
-- [64] Grid lost alarm; uint16; scale=1; [0 to 65536]; /Alarms/GridLost
--
--
---------------------
----- Inverter/Charger Control
---------------------
-- [33] [w] Switch Position; uint16; scale=1; [0 to 65536]; /Mode
--              1=charger_only
--              2=inverter_only
--              3=on
--              4=off
--              See Venus-OS manual for limitations, for example when VE.Bus BMS or DMC is installed.
--
--
---------------------
----- ESS
---------------------
-- [37] [w] ESS power setpoint phase 1 (W); int16; scale=1; [-32768 to 32767]; /Hub4/L1/AcPowerSetpoint
--              ESS Mode 3 - Instructs the multi to charge/discharge with giving power. Negative = discharge.
--              Used by the control loop in grid-parallel systems.
-- [40] [w] ESS power setpoint phase 2 (W); int16; scale=1; [-32768 to 32767]; /Hub4/L2/AcPowerSetpoint
--              ESS Mode 3 - Instructs the multi to charge/discharge with giving power. Negative = discharge.
--              Used by the control loop in grid-parallel systems.
-- [41] [w] ESS power setpoint phase 3 (W); int16; scale=1; [-32768 to 32767]; /Hub4/L3/AcPowerSetpoint
--              ESS Mode 3 - Instructs the multi to charge/discharge with giving power. Negative = discharge.
--              Used by the control loop in grid-parallel systems.
-- [38] [w] ESS disable charge flag phase; uint16; scale=1; [0 to 65536]; /Hub4/DisableCharge
--              0=charge_allowed
--              1=charge_disabled
--              ESS Mode 3 - Enables/Disables charge (0=enabled, 1=disabled).
--              Note that power setpoint will yield to this setting
-- [39] [w] ESS disable feedback flag phase; uint16; scale=1; [0 to 65536]; /Hub4/DisableFeedIn
--              0=feed_in_allowed
--              1=feed_in_disabled
--              ESS Mode 3 - Enables/Disables feedback (0=enabled, 1=disabled).
--              Note that power setpoint will yield to this setting
-- [65] [w] Feed DC overvoltage into grid; uint16; scale=1; [0 to 65536]; /Hub4/DoNotFeedInOvervoltage
--              0=feed_in_overvoltage
--              1=do_not_feed_in_overvoltage
-- [66] [w] Maximum overvoltage feed-in power L1 (W); uint16; scale=0,01; [0 to 6553600]; /Hub4/L1/MaxFeedInPower
-- [67] [w] Maximum overvoltage feed-in power L2 (W); uint16; scale=0,01; [0 to 6553600]; /Hub4/L2/MaxFeedInPower
-- [68] [w] Maximum overvoltage feed-in power L3 (W); uint16; scale=0,01; [0 to 6553600]; /Hub4/L3/MaxFeedInPower
--
--
---------------------
----- Disable PV inverter on AC out
---------------------
-- [56] [w] Disable PV inverter; uint16; scale=1; [0 to 65536]; /PvInverter/Disable
--              0=pv_enabled
--              1=pv_disabled
--              Disable PV inverter on AC out (using frequency shifting).
--              Only works when vebus_unit_id device is in inverter mode.
--              Needs ESS or PV inverter assistant
--
--
---------------------
----- Reset
---------------------
-- [62] [w] VE.Bus Reset; uint16; scale=1; [0 to 65536]; /SystemReset
--              1=vebus_unit_id_reset
--              Any write action will cause a reset
--
--
IP_ADDRESS = 'ip_address'
VEBUS_UNIT_ID = 'vebus_unit_id'
MODE2_UNIT_ID = 'mode2_unit_id'

local modbus
local ip_address
local vebus_unit_id
local mode2_unit_id

function main()
  config.init({
    [IP_ADDRESS] = { type = 'string', required = true },
    [VEBUS_UNIT_ID] = { type = 'number', required = true },
    [MODE2_UNIT_ID] = { type = 'number', required = true },
  })

  local victron_gx, err = connect_victron_gx()
  if err then
    enapter.log("[main]: can't connect to VictronGX: "..err, 'error')
    enapter.send_telemetry({
      status = 'connection_error',
      alerts = { 'connection_error' }
    })
    return
  else
    modbus = victron_gx.modbus
    vebus_unit_id = victron_gx.vebus_unit_id
    mode2_unit_id = victron_gx.mode2_unit_id

    scheduler.add(2000, telemetry_tick)
    scheduler.add(30000, send_properties)

    enapter.register_command_handler('read_inverter_charger_mode', command_read_inverter_charger_mode)
    enapter.register_command_handler('switch_inverter_charger_mode', command_switch_inverter_charger_mode)
    enapter.register_command_handler('read_state_of_charge', command_read_state_of_charge)
    enapter.register_command_handler('write_state_of_charge', command_write_state_of_charge)
    enapter.register_command_handler('read_ess_mode', command_read_ess_mode)

     -- Mode 2
    enapter.register_command_handler('read_mode2_grid_power_setpoint', command_read_mode2_grid_power_setpoint)
    enapter.register_command_handler('write_mode2_grid_power_setpoint', command_write_mode2_grid_power_setpoint)
    enapter.register_command_handler('read_mode2_maximum_inverter_power', command_read_mode2_maximum_inverter_power)
    enapter.register_command_handler('write_mode2_maximum_inverter_power', command_write_mode2_maximum_inverter_power)
    enapter.register_command_handler('read_mode2_enable_charge', command_read_mode2_enable_charge)
    enapter.register_command_handler('write_mode2_enable_charge', command_write_mode2_enable_charge)
    enapter.register_command_handler('read_mode2_enable_inverter', command_read_mode2_enable_inverter)
    enapter.register_command_handler('write_mode2_enable_inverter', command_write_mode2_enable_inverter)

     -- Mode 3
    enapter.register_command_handler('read_charge_allowance', command_read_charge_allowance)
    enapter.register_command_handler('switch_charge_allowance', command_switch_charge_allowance)
    enapter.register_command_handler('read_feedin_allowance', command_read_feedin_allowance)
    enapter.register_command_handler('switch_feedin_allowance', command_switch_feedin_allowance)
    enapter.register_command_handler('read_power_setpoints', command_read_power_setpoints)
    enapter.register_command_handler('write_power_setpoints', command_write_power_setpoints)
  end
end

function send_properties()
  local victron_gx, err = connect_victron_gx()
  if err then
    enapter.log("Can't connect to Victron GX: "..err)
    return nil
  else
    enapter.send_properties({
      ip_address = victron_gx.ip_address,
      vebus_unit_id = victron_gx.vebus_unit_id,
      mode2_unit_id = victron_gx.mode2_unit_id
    })
  end
end

function telemetry_tick()
  local victron_gx, err = connect_victron_gx()
  if err then
    enapter.log("Can't connect to Victron GX: "..err)
    return nil
  end

  local telemetry = { error_log = {} }
  local alerts = {}

  local state, err = victron_gx:read_state()
  if err then
    table.insert(telemetry.error_log, "state: "..tostring(err))
  else
    telemetry.status = state
  end

  local vebus_unit_id_errors, err = victron_gx:read_errors()
  if err then
    table.insert(telemetry.error_log, "vebus_unit_id_error: "..tostring(err))
  else
    -- TODO: add alarms
    -- FIXME: encodes [] as {} in JSON
    -- telemetry.errors = vebus_unit_id_errors
    -- for debug
    if vebus_unit_id_errors[1] then
      telemetry.error_message = errors_map[vebus_unit_id_errors[1]]
    end
  end

  -- TODO: grid_connected = read_(),

  victron_gx:read_uint16(telemetry, "grid_l1_voltage", 3, 10)
  victron_gx:read_uint16(telemetry, "grid_l2_voltage", 4, 10)
  victron_gx:read_uint16(telemetry, "grid_l3_voltage", 5, 10)
  victron_gx:read_int16(telemetry, "grid_l1_amperage", 6, 10)
  victron_gx:read_int16(telemetry, "grid_l2_amperage", 7, 10)
  victron_gx:read_int16(telemetry, "grid_l3_amperage", 8, 10)
  victron_gx:read_int16(telemetry, "grid_l1_freq", 9, 100)
  victron_gx:read_int16(telemetry, "grid_l2_freq", 10, 100)
  victron_gx:read_int16(telemetry, "grid_l3_freq", 11, 100)
  victron_gx:read_int16(telemetry, "grid_l1_power", 12, 0.1)
  victron_gx:read_int16(telemetry, "grid_l2_power", 13, 0.1)
  victron_gx:read_int16(telemetry, "grid_l3_power", 14, 0.1)
  victron_gx:read_uint16(telemetry, "ac_l1_voltage", 15, 10)
  victron_gx:read_uint16(telemetry, "ac_l2_voltage", 16, 10)
  victron_gx:read_uint16(telemetry, "ac_l3_voltage", 17, 10)
  victron_gx:read_int16(telemetry, "ac_l1_amperage", 18, 10)
  victron_gx:read_int16(telemetry, "ac_l2_amperage", 19, 10)
  victron_gx:read_int16(telemetry, "ac_l3_amperage", 20, 10)
  victron_gx:read_int16(telemetry, "ac_freq", 21, 100)
  victron_gx:read_int16(telemetry, "ac_l1_power", 23, 0.1)
  victron_gx:read_int16(telemetry, "ac_l2_power", 24, 0.1)
  victron_gx:read_int16(telemetry, "ac_l3_power", 25, 0.1)
  victron_gx:read_uint16(telemetry, "dc_voltage", 26, 100)
  victron_gx:read_int16(telemetry, "dc_amperage", 27, 10)
  victron_gx:read_uint16(telemetry, "battery_soc", 30, 10)
  victron_gx:read_uint16(telemetry, "alarm_low_battery", 45, 1)

  if telemetry.alarm_low_battery then
    if telemetry.alarm_low_battery == 1 then
      table.insert(alerts, "low_battery_w")
    elseif telemetry.alarm_low_battery == 2 then
      table.insert(alerts, "low_battery_e")
    end
  end

  telemetry.alerts = alerts

  enapter.send_telemetry(telemetry)
end

local victron_gx

function connect_victron_gx()
  if victron_gx then return victron_gx, nil end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    ip_address, vebus_unit_id, mode2_unit_id = values[IP_ADDRESS], values[VEBUS_UNIT_ID], values[MODE2_UNIT_ID]
    if not ip_address or not vebus_unit_id or not mode2_unit_id then
      return nil, 'not_configured'
    else
      victron_gx = VictronGX.new(ip_address, vebus_unit_id, mode2_unit_id)
      return victron_gx, nil
    end
  end
end

function toint16(data)
  if data[1] then
    local raw_str = string.pack("I2", data[1])
    return string.unpack("i2", raw_str)
  end
end

function touint16(data)
  if data[1] then
    local raw_str = string.pack("I2", data[1])
    return string.unpack("I2", raw_str)
  end
end

errors_map = {
  ["error1"]  = "Device is switched off because one of the other phases in the system has switched off",
  ["error2"]  = "New and old types MK2 are mixed in the system",
  ["error3"]  = "Not all- or more than- the expected devices were found in the system",
  ["error4"]  = "No other device whatsoever detected",
  ["error5"]  = "Overvoltage on AC-out",
  ["error6"]  = "Error in DDC Program",
  ["error7"]  = "VE.Bus BMS connected- which requires an Assistant- but no assistant found",
  ["error10"] = "System time synchronisation problem occurred",
  ["error14"] = "Device cannot transmit data",
  ["error16"] = "Dongle missing",
  ["error17"] = "One of the devices assumed master status because the original master failed",
  ["error18"] = "AC Overvoltage on the output of a slave has occurred while already switched off",
  ["error22"] = "This device cannot function as slave",
  ["error24"] = "Switch-over system protection initiated",
  ["error25"] = "Firmware incompatibility. The firmware of one of the "..
  "connected device is not sufficiently up to date to operate in "..
  "conjunction with this device",
  ["error26"] = "Internal error",
}


-- scheduler.add(10000, registration_tick)

--enapter.register_command_handler('read_ess_mode', command_read_ess_mode)
--enapter.register_command_handler('read_inverter_charger_mode', command_read_inverter_charger_mode)
--enapter.register_command_handler('switch_inverter_charger_mode', command_switch_inverter_charger_mode)
--enapter.register_command_handler('read_state_of_charge', command_read_state_of_charge)
--enapter.register_command_handler('write_state_of_charge', command_write_state_of_charge)
--
---- Mode 2
--enapter.register_command_handler('read_mode2_grid_power_setpoint', command_read_mode2_grid_power_setpoint)
--enapter.register_command_handler('write_mode2_grid_power_setpoint', command_write_mode2_grid_power_setpoint)
--enapter.register_command_handler('read_mode2_maximum_inverter_power', command_read_mode2_maximum_inverter_power)
--enapter.register_command_handler('write_mode2_maximum_inverter_power', command_write_mode2_maximum_inverter_power)
--enapter.register_command_handler('read_mode2_enable_charge', command_read_mode2_enable_charge)
--enapter.register_command_handler('write_mode2_enable_charge', command_write_mode2_enable_charge)
--enapter.register_command_handler('read_mode2_enable_inverter', command_read_mode2_enable_inverter)
--enapter.register_command_handler('write_mode2_enable_inverter', command_write_mode2_enable_inverter)
--
---- Mode 3
--enapter.register_command_handler('read_charge_allowance', command_read_charge_allowance)
--enapter.register_command_handler('switch_charge_allowance', command_switch_charge_allowance)
--enapter.register_command_handler('read_feedin_allowance', command_read_feedin_allowance)
--enapter.register_command_handler('switch_feedin_allowance', command_switch_feedin_allowance)
--enapter.register_command_handler('read_power_setpoints', command_read_power_setpoints)
--enapter.register_command_handler('write_power_setpoints', command_write_power_setpoints)


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
-- Victron GX API
---------------------------------

VictronGX = {}

function VictronGX.new()
  assert(type(ip_address) == 'string', 'ip_address (arg #1) must be string, given: '..inspect(ip_address))
  assert(type(vebus_unit_id) == 'number', 'vebus_unit_id (arg #2) must be number, given: '..inspect(vebus_unit_id))
  assert(type(mode2_unit_id) == 'number', 'mode2_unit_id (arg #2) must be number, given: '..inspect(mode2_unit_id))

  local self = setmetatable({}, { __index = VictronGX })
  self.ip_address = ip_address
  self.vebus_unit_id = vebus_unit_id
  self.mode2_unit_id = mode2_unit_id
  self.modbus = modbustcp.new(self.ip_address..':502')

  VictronGX.vebus_unit_id = vebus_unit_id
  VictronGX.mode2_unit_id = mode2_unit_id
  VictronGX.modbus = self.modbus
  return self
end

state_map = {
  [0] = "off",
  [1] = "low_power",
  [2] = "fault",
  [3] = "bulk",
  [4] = "absorption",
  [5] = "float",
  [6] = "storage",
  [7] = "equalize",
  [8] = "passthru",
  [9] = "inverting",
  [10] = "power_assist",
  [11] = "power_supply",
  [252] = "bulk_protection",
}
function VictronGX:read_state()
  local data, err = self.modbus:read_holdings(self.vebus_unit_id, 31, 1, 1000)
  if err and err ~= 0 then return nil, err end

  local value = touint16(data)
  if state_map[value] then
    return state_map[value], nil
  else
    return nil, "unknown state value "..value
  end
end

function VictronGX:read_errors()
  local data, err = self.modbus:read_holdings(self.vebus_unit_id, 32, 1, 1000)
  if err and err ~= 0 then return nil, err end

  local value = touint16(data)
  if value == 0 then -- no error
    return {}, nil
  else
    return {"error"..value}, nil
  end
end

function VictronGX:read_int16(telemetry, name, reg, scale)
  local data, err = self.modbus:read_holdings(self.vebus_unit_id, reg, 1, 1000)
  if err and err ~= 0 then
    table.insert(telemetry.error_log, name..": "..modbus:err_to_str(err))
    return
  end

  local value = toint16(data)
  if value then
    telemetry[name] = value / scale
  end
end

function VictronGX:read_uint16(telemetry, name, reg, scale)
  local data, err = self.modbus:read_holdings(self.vebus_unit_id, reg, 1, 1000)
  if err and err ~= 0 then
    table.insert(telemetry.error_log, name..": "..tostring(err))
    return
  end

  local value = touint16(data)
  if value then
    telemetry[name] = value / scale
  end
end

-- VE.Bus state of charge (%)
-- [30] [w] uint16; scale=10; [0 to 6553.5]
--
function command_write_state_of_charge(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value = tonumber(args.value)
  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local scaled_value = value * 10.0
  local err = modbus:write_holding(vebus_unit_id, 30, scaled_value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 30 with value `"..scaled_value.."`: "..tostring(err))
  end

  return "state of charge set to "..args.value
end
function command_read_state_of_charge(ctx)
  local data, err = modbus:read_holdings(vebus_unit_id, 30, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local value = touint16(data)
  if value then
    return { value = value / 10.0 }
  elseif type(data) == 'table' and #data >= 2 then
    ctx.error("unexpected value: "..data[1]..", "..data[2])
  else
    ctx.error("no value")
  end
end

------------------------------------------------------
------------------------------------------------------
-- ESS Mode 2 Commands
------------------------------------------------------
------------------------------------------------------

-- Switch inverter/charger modes.
-- See Venus-OS manual for limitations, for example when VE.Bus BMS or DMC is installed.
-- [33] [w] Switch Position; uint16; scale=1; [0 to 65536]; /Mode
--
inverter_charger_mode_map = {
  [1] = "charger_only",
  [2] = "inverter_only",
  [3] = "on",
  [4] = "off",
}
function command_switch_inverter_charger_mode(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value
  for k, v in pairs(inverter_charger_mode_map) do
    if args.value == v then
      value = k
    end
  end

  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local err = modbus:write_holding(vebus_unit_id, 33, value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 33 with value `"..value.."`: "..err)
  end

  return "mode switched to "..args.value
end

function command_read_inverter_charger_mode(ctx)
  local data, err = modbus:read_holdings(vebus_unit_id, 33, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local raw_value = touint16(data)
  local value = inverter_charger_mode_map[raw_value]
  if value then
    return { value = value }
  else
    ctx.error("unexpected inverter/charger mode: "..raw_value)
  end
end

-- Enable/Disable charge
-- [2701] [w] uint16; scale=1; []
--     0: disable charging. This setting may be used for time shifting.
--     For example by disabling charging the battery when feeding back
--     to the grid is profitable, and leaving battery capacity for later.
--     100: unlimited charging. Battery, VEConfigure settings, and BMS
--     permitting. Use value 100 here instead of 1 because this setting
--     was originally designed to be used as a percentage.
-- Note that this setting has a higher priority than the Grid power setpoint.
--
mode2_enable_charge_map = {
  [0] = "charge_disabled",
  [100] = "charge_enabled",
}
function command_write_mode2_enable_charge(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value
  for k, v in pairs(mode2_enable_charge_map) do
    if args.value == v then
      value = k
    end
  end

  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local err = modbus:write_holding(mode2_unit_id, 2701, value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 2701 with value `"..value.."`: "..err)
  end

  return "changed to "..args.value
end
function command_read_mode2_enable_charge(ctx)
  local data, err = modbus:read_holdings(mode2_unit_id, 2701, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local raw_value = touint16(data)
  local value = mode2_enable_charge_map[raw_value]
  if value then
    return { value = value }
  else
    ctx.error("unexpected value: "..raw_value)
  end
end

-- Enable/Disable inverter
-- [2702] [w] uint16; scale=1; []
--     0: disable inverter
--     100: enabled inverter. Use value 100 here instead of 1 because
--     this setting was originally designed to be used as a percentage.
-- Note that this settings has a higher priority than the Grid power
-- setpoint.
--
mode2_enable_inverter_map = {
  [0] = "inverter_disabled",
  [100] = "inverter_enabled",
}
function command_write_mode2_enable_inverter(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value
  for k, v in pairs(mode2_enable_inverter_map) do
    if args.value == v then
      value = k
    end
  end

  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local err = modbus:write_holding(mode2_unit_id, 2702, value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 2702 with value `"..value.."`: "..err)
  end

  return "changed to "..args.value
end
function command_read_mode2_enable_inverter(ctx)
  local data, err = modbus:read_holdings(mode2_unit_id, 2702, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local raw_value = touint16(data)
  local value = mode2_enable_inverter_map[raw_value]
  if value then
    return { value = value }
  else
    ctx.error("unexpected value: "..raw_value)
  end
end

-- Maximum inverter power on AC out.
-- [2704] [w] int16; scale=0.1; []
--     -1: No limit
--     Any positive number: Maximum power in Watt that the Multi will feed to the loads.
--
function command_write_mode2_maximum_inverter_power(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value = tonumber(args.value)
  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local scaled_value = value / 10.0
  local err = modbus:write_holding(mode2_unit_id, 2704, scaled_value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 2704 with value `"..scaled_value.."`: "..tostring(err))
  end

  return "inverter power set to "..args.value
end
function command_read_mode2_maximum_inverter_power(ctx)
  local data, err = modbus:read_holdings(mode2_unit_id, 2704, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local value = toint16(data)
  if value then
    return { value = value * 10.0 }
  else
    ctx.error("unexpected inverter power value: "..data[1]..", "..data[2])
  end
end

-- Grid power setpoint
-- [2700] [w] int16; scale=1; [-32768W to 32767W]
--   Positive: take power from grid.
--   Negative: send power to grid.
--   Default: 30 W.
--   Use register 2703 for a larger range (scale factor=0.01).
--
function command_write_mode2_grid_power_setpoint(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value = tonumber(args.value)
  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local err = modbus:write_holding(mode2_unit_id, 2700, value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 2700 with value `"..value.."`: "..tostring(err))
  end

  return "grid power set to "..args.value
end
function command_read_mode2_grid_power_setpoint(ctx)
  local data, err = modbus:read_holdings(mode2_unit_id, 2700, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local value = toint16(data)
  if value then
    return { value = value }
  else
    ctx.error("unexpected grid power setpoint: "..data[1]..", "..data[2])
  end
end


-- DVCC maximum system charge current
-- [2705] [w] int16; scale=1; []
--     -1: No limit. Solar Chargers and the Multi will charge to their full capacity or individual configurd limits.
--     Any positive number: Maximum combined current in Ampere for battery
--     charging. This limits the solar chargers and the multi, and takes
--     loads into account. Solar chargers take priority over the Multi.
--

-- Maximum system grid feed-in
-- [2706] [w] int16; scale=1; []
--     -1: No limit. If feeding in excess PV is enabled, all of it will be fed in. See registers 2707 and 2708 below.
--     Any positive number: Maximum power in 100 Watt units to feed into the grid.
--

-- Feed excess DC-coupled PV into the grid
-- [2707] [w] int16; scale=1; []
--     0: Excess DC-coupled PV is not fed into the grid.
--     1: Excess DC-coupled PV is fed into the grid
--

-- Feed excess AC-coupled PV into the grid
-- [2708] [w] int16; scale=1; []
-- Please note that for historical reasons this register is inverted compared to 2707.
--     0: Excess AC-coupled PV is fed into the grid
--     1: Excess AC-coupled PV is not fed into the grid.
--

-- Grid limiting status
-- [2709] [w] int16; scale=1; []
-- When feed-in of excess AC-coupled PV is disabled, or when a limit is set in register 2706, limiting will be active.
--     0: Feed-in of excess power is not limited in any way.
--     1: Feed-in of excess power is limited in some way, either register 2707
--     is set to 0, or register 2706 is set to a positive number.
--

-- Disable PV inverter on AC out (using frequency shifting).
-- Only works when vebus_unit_id device is in inverter mode.
-- Needs ESS or PV inverter assistant
-- [56] [w] Disable PV inverter; uint16; scale=1; [0 to 65536]; /PvInverter/Disable
--   0=pv_enabled
--   1=pv_disabled
--
-- function command_write_control_ac_pv_inverter(args)
-- end
-- function command_read_control_ac_pv_inverter(args)
-- end

-- Any write action will cause a reset
-- [62] [w] VE.Bus Reset; uint16; scale=1; [0 to 65536]; /SystemReset
--   1=vebus_unit_id_reset
--
-- function command_reset()
-- end

------------------------------------------------------
------------------------------------------------------
-- ESS Mode 3 Commands
------------------------------------------------------
------------------------------------------------------

-- ESS Mode 3 - Instructs the multi to charge/discharge with giving power. Negative = discharge.
-- Used by the control loop in grid-parallel systems.
-- [37] [w] ESS power setpoint phase 1 (W); int16; scale=1; [-32768 to 32767]; /Hub4/L1/AcPowerSetpoint
-- [40] [w] ESS power setpoint phase 2 (W); int16; scale=1; [-32768 to 32767]; /Hub4/L2/AcPowerSetpoint
-- [41] [w] ESS power setpoint phase 3 (W); int16; scale=1; [-32768 to 32767]; /Hub4/L3/AcPowerSetpoint
--
-- -- All phases - for UI.
power_setpoint_phases = {
  phase_1 = 37,
  -- phase_2 = 40,
  -- phase_3 = 41
}
function command_write_power_setpoints(ctx, args)
  local phases_to_set = {}
  for phase, reg in pairs(power_setpoint_phases) do
    if args[phase] then
      phases_to_set[reg] = tonumber(args[phase])
    end
  end

  -- no grid feed-in limit
  local err = modbus:write_holding(mode2_unit_id, 2706, -1, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 2706 with value [-1]: "..tostring(err))
  end

  for reg, value in pairs(phases_to_set) do
    local err = modbus:write_holding(vebus_unit_id, reg, value, 1000)
    if err and err ~= 0 then
      ctx.error("cannot write register "..reg.." with value `"..value.."`: "..tostring(err))
    end
  end

  return "power setpoints updated"
end
function command_read_power_setpoints(ctx)
  local result = {}
  for phase, reg in pairs(power_setpoint_phases) do
    local data, err = modbus:read_holdings(vebus_unit_id, reg, 1, 1000)
    if err and err ~= 0 then
      ctx.error("cannot read register "..reg..": "..tostring(err))
    end

    result[phase] = toint16(data)
  end

  return result
end
-- -- Per phase - for automatic control scripts.
-- function command_write_power_setpoint(args)
-- end
-- function command_read_power_setpoint(args)
-- end

-- ESS Mode 3 - Enables/Disables charge (0=enabled, 1=disabled).
-- Note that power setpoint will yield to this setting
-- [38] [w] ESS disable charge flag phase; uint16; scale=1; [0 to 65536]; /Hub4/DisableCharge
--   0=charge_allowed
--   1=charge_disabled
--
charge_allowance_map = {
  [0] = "charge_allowed",
  [1] = "charge_disabled",
}
function command_switch_charge_allowance(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value
  for k, v in pairs(charge_allowance_map) do
    if args.value == v then
      value = k
    end
  end

  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local err = modbus:write_holding(vebus_unit_id, 38, value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 38 with value `"..value.."`: "..err)
  end

  return "switched to "..args.value
end
function command_read_charge_allowance(ctx)
  local data, err = modbus:read_holdings(vebus_unit_id, 38, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local raw_value = touint16(data)
  local value = charge_allowance_map[raw_value]
  if value then
    return { value = value }
  else
    ctx.error("unexpected charger allowance value: "..raw_value)
  end
end

-- ESS Mode 3 - Enables/Disables feedback (0=enabled, 1=disabled).
-- Note that power setpoint will yield to this setting
-- [39] [w] ESS disable feedback flag phase; uint16; scale=1; [0 to 65536]; /Hub4/DisableFeedIn
--   0=feed_in_allowed
--   1=feed_in_disabled
--
feedin_allowance_map = {
  [0] = "feed_in_allowed",
  [1] = "feed_in_disabled",
}
function command_switch_feedin_allowance(ctx, args)
  if not args.value then
    ctx.error("`value` argument not passed")
  end

  local value
  for k, v in pairs(feedin_allowance_map) do
    if args.value == v then
      value = k
    end
  end

  if not value then
    ctx.error("unexpected value: "..args.value)
  end

  local err = modbus:write_holding(vebus_unit_id, 39, value, 1000)
  if err and err ~= 0 then
    ctx.error("cannot write register 39 with value `"..value.."`: "..err)
  end

  return "switched to "..args.value
end
function command_read_feedin_allowance(ctx)
  local data, err = modbus:read_holdings(vebus_unit_id, 39, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local raw_value = touint16(data)
  local value = feedin_allowance_map[raw_value]
  if value then
    return { value = value }
  else
    ctx.error("unexpected feed-in allowance value: "..raw_value)
  end
end

-- [65] [w] Feed DC overvoltage into grid; uint16; scale=1; [0 to 65536]; /Hub4/DoNotFeedInOvervoltage
--              0=feed_in_overvoltage
--              1=do_not_feed_in_overvoltage
-- [66] [w] Maximum overvoltage feed-in power L1 (W); uint16; scale=0,01; [0 to 6553600]; /Hub4/L1/MaxFeedInPower
-- [67] [w] Maximum overvoltage feed-in power L2 (W); uint16; scale=0,01; [0 to 6553600]; /Hub4/L2/MaxFeedInPower
-- [68] [w] Maximum overvoltage feed-in power L3 (W); uint16; scale=0,01; [0 to 6553600]; /Hub4/L3/MaxFeedInPower

-- ESS Mode
-- [2902] [w] int16; scale=1; []
--     1: ESS with Phase Compensation
--     2: ESS without phase compensation
--     3: Disabled/External Control
--
ess_mode_map = {
  [1] = "mode_1",
  [2] = "mode_2",
  [3] = "mode_3"
}

function command_read_ess_mode(ctx)
  local data, err = modbus:read_holdings(mode2_unit_id, 2902, 1, 1000)
  if err and err ~= 0 then
    ctx.error(err)
  end

  local raw_value = touint16(data)
  local value = ess_mode_map[raw_value]
  if value then
    return { value = value }
  else
    ctx.error("unexpected ESS mode value: "..raw_value)
  end
end

main()
