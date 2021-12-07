ADDRESS_CONFIG = 'address'
UNIT_ID_CONFIG = 'unit_id'

-- global SMA Modbus TCP connection, initialized below
sma = nil

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
    operation_status = parse_operation_status(sma:read_u32_enum(40029)),
    alerts = parse_event_msg(sma:read_u32_enum(30247)),
    recom_action = parse_recom_action(sma:read_u32_enum(30211)),

    dc_amp = sma:read_s32_fix3(30769),
    dc_volt = sma:read_s32_fix2(30771),
    dc_power = sma:read_s32_fix2(30773),
    ac_power = sma:read_s32_fix0(30775),
    total_yield = sma:read_u32_fix0(30529),
    daily_yield = sma:read_u32_fix0(30535),
  })
end

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

  if value == 9225 then return 'SB 5000SE-10'
  elseif value == 9226 then return 'SB 3600SE-10'
  elseif value == 9074 then return 'SB 3000TL-21'
  elseif value == 9165 then return 'SB 3600TL-21'
  elseif value == 9075 then return 'SB 4000TL-21'
  elseif value == 9076 then return 'SB 5000TL-21'
  elseif value == 9184 then return 'SB 2500TLST-21'
  elseif value == 9185 then return 'SB 3000TLST-21'
  elseif value == 9162 then return 'SB 3500TL-JP-22'
  elseif value == 9164 then return 'SB 4500TL-JP-22'
  elseif value == 9198 then return 'SB 3000TL-US-22'
  elseif value == 9199 then return 'SB 3800TL-US-22'
  elseif value == 9200 then return 'SB 4000TL-US-22'
  elseif value == 9201 then return 'SB 5000TL-US-22'
  elseif value == 9274 then return 'SB 6000TL-US-22'
  elseif value == 9275 then return 'SB 7000TL-US-22'
  elseif value == 9293 then return 'SB 7700TL-US-22'
  elseif value == 9301 then return 'SB1.5-1VL-40'
  elseif value == 9302 then return 'SB2.5-1VL-40'
  elseif value == 9328 then return 'SB3.0-1SP-US-40'
  elseif value == 9329 then return 'SB3.8-1SP-US-40'
  elseif value == 9304 then return 'SB5.0-1SP-US-40'
  elseif value == 9305 then return 'SB6.0-1SP-US-40'
  elseif value == 9330 then return 'SB7.0-1SP-US-40'
  elseif value == 9306 then return 'SB7.7-1SP-US-40'
  elseif value == 9319 then return 'SB3.0-1AV-40'
  elseif value == 9320 then return 'SB3.6-1AV-40'
  elseif value == 9321 then return 'SB4.0-1AV-40'
  elseif value == 9322 then return 'SB5.0-1AV-40'
  elseif value == 9067 then return 'STP 10000TL-10'
  elseif value == 9068 then return 'STP 12000TL-10'
  elseif value == 9069 then return 'STP 15000TL-10'
  elseif value == 9070 then return 'STP 17000TL-10'
  elseif value == 9182 then return 'STP 15000TLEE-10'
  elseif value == 9181 then return 'STP 20000TLEE-10'
  elseif value == 9222 then return 'STP 10000TLEE-JP-10'
  elseif value == 9194 then return 'STP 12000TL-US-10'
  elseif value == 9195 then return 'STP 15000TL-US-10'
  elseif value == 9196 then return 'STP 20000TL-US-10'
  elseif value == 9197 then return 'STP 24000TL-US-10'
  elseif value == 9310 then return 'STP 30000TL-US-10'
  elseif value == 9271 then return 'STP 20000TLEE-JP-11'
  elseif value == 9272 then return 'STP 10000TLEE-JP-11'
  elseif value == 9098 then return 'STP 5000TL-20'
  elseif value == 9099 then return 'STP 6000TL-20'
  elseif value == 9100 then return 'STP 7000TL-20'
  elseif value == 9103 then return 'STP 8000TL-20'
  elseif value == 9102 then return 'STP 9000TL-20'
  elseif value == 9281 then return 'STP 10000TL-20'
  elseif value == 9282 then return 'STP 11000TL-20'
  elseif value == 9283 then return 'STP 12000TL-20'
  elseif value == 9284 then return 'STP 20000TL-30'
  elseif value == 9285 then return 'STP 25000TL-30'
  elseif value == 9311 then return 'STP 25000TL-JP-30'
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

function parse_operation_status(value)
  if not value then return end

  if value == 295 then return 'mpp'
  elseif value == 1467 then return 'start'
  elseif value == 381 then return 'stop'
  elseif value == 2119 then return 'derating'
  elseif value == 1469 then return 'shutdown'
  elseif value == 1392 then return 'fault'
  elseif value == 1480 then return 'wait_for_utilities_company'
  elseif value == 1393 then return 'wait_for_pv_voltage'
  elseif value == 443 then return 'constant_voltage'
  elseif value == 1855 then return 'stand_alone_operation'
  else
    enapter.log('Cannot decode operation status: '..tostring(value), 'error')
    return tostring(value)
  end
end

function parse_event_msg(value)
  if not value then return {} end

  local events = {}

  -- No alerts for the following events:
  -- 7320, 10250-10251, 10253-10254, 10282, 10901-10912
  if value >= 101 and value <= 103 then table.insert(events, 'grid_voltage_high')
  elseif value >= 202 and value <= 205 then table.insert(events, 'grid_voltage_low')
  elseif value == 301 then table.insert(events, 'average_grid_volt_high')
  elseif value == 302 then table.insert(events, 'reduced_power_high_volt')
  elseif value == 401 or value == 404 then table.insert(events, 'utility_grid_disconnect')
  elseif value == 501 then table.insert(events, 'power_freq_out_range')
  elseif value == 601 then table.insert(events, 'direct_current_high_proportion')
  elseif value == 701 then table.insert(events, 'freq_not_permit')
  elseif value == 901 then table.insert(events, 'pe_connection_missing')
  elseif value == 1001 then table.insert(events, 'l_n_swapped')
  elseif value == 1101 then table.insert(events, 'installation_fault')
  elseif value == 1302 then table.insert(events, 'wait_for_grid_voltage')
  elseif value == 1501 then table.insert(events, 'invalid_country_standard')
  elseif value >= 3301 and value <= 3303 then table.insert(events, 'low_power_dc_input')
  elseif value == 3401 or value == 3402 or value == 3407 then table.insert(events, 'dc_overvoltage')
  elseif value == 3501 then table.insert(events, 'insulation_fail')
  elseif value == 3701 then table.insert(events, 'high_residual_current')
  elseif value == 3801 or value == 3802 or value == 3805 then table.insert(events, 'dc_overcurrent')
  elseif value == 3901 or value == 3902 then table.insert(events, 'start_conditions_not_met')
  elseif value == 4011 then table.insert(events, 'bridged_strings_detected')
  elseif value >= 6002 and value <= 6412 then table.insert(events, 'interference_device')
  elseif value == 6501 or value == 6502 or value == 6509 then table.insert(events, 'overtermperature')
  elseif value == 6512 then table.insert(events, 'low_operating_temperature')
  elseif value >= 6602 or value <= 6604 then table.insert(events, 'overload')
  elseif value == 6801 or value == 6802 then table.insert(events, 'defective_a_input')
  elseif value == 6901 or value == 6902 then table.insert(events, 'defective_b_input')
  elseif value == 6701 or value == 6702 then table.insert(events, 'comm_disturbed')
  elseif value == 7102 then table.insert(events, 'param_file_not_found')
  elseif value == 7105 then table.insert(events, 'param_setting_failed')
  elseif value == 7106 then table.insert(events, 'update_file_defective')
  elseif value == 7110 then table.insert(events, 'no_update_file_found')
  elseif value == 7112 then table.insert(events, 'update_file_copied_success')
  elseif value == 7113 then table.insert(events, 'memory_card_protected')
  elseif value == 7201 or value == 7202 then table.insert(events, 'data_storage_not_possible')
  elseif value == 7303 then table.insert(events, 'update_main_cpu_failed')
  elseif value == 7330 then table.insert(events, 'condition_test_fail')
  elseif value == 7331 then table.insert(events, 'update_transport_started')
  elseif value == 7332 then table.insert(events, 'update_transport_success')
  elseif value == 7333 then table.insert(events, 'update_transport_failed')
  elseif value == 7341 then table.insert(events, 'update_bootloader')
  elseif value == 7342 then table.insert(events, 'update_bootloader_fail')
  elseif value == 7347 then table.insert(events, 'incompatible_file')
  elseif value == 7348 then table.insert(events, 'incorrect_file_format')
  elseif value == 7349 then table.insert(events, 'incorrect_login_rights')
  elseif value == 7350 then table.insert(events, 'transfer_config_file_start')
  elseif value == 7351 then table.insert(events, 'update_wlan')
  elseif value == 7352 then table.insert(events, 'update_wlan_fail')
  elseif value == 7353 then table.insert(events, 'update_time_zone_database')
  elseif value == 7354 then table.insert(events, 'update_time_zone_database_fail')
  elseif value == 7355 then table.insert(events, 'update_webui')
  elseif value == 7356 then table.insert(events, 'update_webui_fail')
  elseif value == 7500 or value == 7501 then table.insert(events, 'fan_fault')
  elseif value == 7619 then table.insert(events, 'meter_unit_comm_fault')
  elseif value == 7702 then table.insert(events, 'interference_device2')
  elseif value == 8003 then table.insert(events, 'active_power_limit_temp')
  elseif value >= 8101 and value <= 8104 then table.insert(events, 'communication_disturbed')
  elseif value == 9002 then table.insert(events, 'invalid_sma_grid_guard')
  elseif value == 9003 then table.insert(events, 'grid_param_locked')
  elseif value == 9005 then table.insert(events, 'change_grid_param_fail')
  elseif value == 9007 then table.insert(events, 'abort_self_test')
  elseif value == 10108 then table.insert(events, 'time_adjust_old_time')
  elseif value == 10109 then table.insert(events, 'time_adjust_new_time')
  elseif value == 10110 then table.insert(events, 'time_sync_fail')
  elseif value == 10118 then table.insert(events, 'param_upload_complete')
  elseif value == 10248 then table.insert(events, 'network_busy')
  elseif value == 10249 then table.insert(events, 'network_overload')
  elseif value == 10252 then table.insert(events, 'comm_disrupted')
  elseif value == 10255 then table.insert(events, 'network_load_ok')
  elseif value == 10283 then table.insert(events, 'wlan_module_fault')
  elseif value == 10284 then table.insert(events, 'no_wlan_connection')
  elseif value == 10285 then table.insert(events, 'wlan_established')
  elseif value == 10286 then table.insert(events, 'wlan_connection_lost')
  elseif value == 10339 then table.insert(events, 'webconnect_enabled')
  elseif value == 10340 then table.insert(events, 'webconnect_disabled')
  elseif value == 10502 then table.insert(events, 'active_power_limit_ac_freq')
  elseif value == 27103 then table.insert(events, 'set_param')
  elseif value == 27104 then table.insert(events, 'param_set_success')
  elseif value == 27107 then table.insert(events, 'update_file_ok')
  elseif value == 27301 then table.insert(events, 'update_comm')
  elseif value == 27302 then table.insert(events, 'update_main_cpu')
  elseif value == 27312 then table.insert(events, 'update_completed')
  elseif value == 29001 then table.insert(events, 'installer_code_valid')
  elseif value == 29004 then table.insert(events, 'grid_param_unchanged')
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
