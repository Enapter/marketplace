local config = require('enapter.ucm.config')

AUTOSTART_CONFIG = 'autostart'
CAN_ID_CONFIG = 'user_can_id'

telemetry = {}
alerts = {}
alerts_received = false
local user_can_id

function main()
  local result = can.init(250, can_handler)
  if result ~= 0 then
    enapter.log("CAN failed: "..can.err_to_str(result), "error", true)
  end

  config.init({
    [AUTOSTART_CONFIG] = { type = 'boolean', required = true },
    [CAN_ID_CONFIG] = { type = 'number', required = true },
  })

  scheduler.add(5000, function()
    telemetry.autostart = config.read(AUTOSTART_CONFIG) or false
  end)

  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
  scheduler.add(500, send_autostart_request)

  enapter.register_command_handler("set_start_voltage1", command_set_start_voltage1)
  enapter.register_command_handler("set_start_voltage2", command_set_start_voltage2)
  enapter.register_command_handler("set_stop_voltage1", command_set_stop_voltage1)
  enapter.register_command_handler("set_stop_voltage2", command_set_stop_voltage2)
  enapter.register_command_handler("set_target_voltage1", command_set_target_voltage1)
  enapter.register_command_handler("set_target_voltage2", command_set_target_voltage2)
end

function send_properties()
  user_can_id = math.floor(config.read(CAN_ID_CONFIG)) or 1
  enapter.send_properties({
    vendor = "Powercell",
    model = "PS-5",
    can_id = user_can_id })
end

function send_telemetry()
  -- Make sure to add alerts only if it was really reported by the FC
  -- to avoid accidental cleaning of alerts in the Cloud
  if alerts_received then
    telemetry.alerts = alerts
    alerts = {}
    alerts_received = false
  end

  if next(telemetry) == nil then
    enapter.send_telemetry({status = 'no_data', alerts = {'no_data'}})
  end

  enapter.send_telemetry(telemetry)
  telemetry = {}
end

function can_handler(msg_id, data)
  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0790) then
    local _, state = string.unpack("BB", data)
    state = state >> 4
    telemetry["state"] = state
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0B90) then
    telemetry["total_power"] = string.unpack("<I4<I2", data) / 100.0
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0C90) then
    telemetry["total_runtime"] = string.unpack("<I2", data) / 10.0
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0090) then
    local target_voltage1, stop_voltage1, start_voltage1 = string.unpack("<I2<I2<I2", data)
    telemetry["target_voltage1"] = target_voltage1 / 100.0
    telemetry["stop_voltage1"] = stop_voltage1 / 100.0
    telemetry["start_voltage1"] = start_voltage1 / 100.0
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0890) then
    local current, voltage, power = string.unpack("<I2<I2<I2", data)
    telemetry["current1"] = current / 10.0
    telemetry["voltage1"] = voltage / 100.0
    telemetry["power1"] = power
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0990) then
    local current, voltage, power = string.unpack("<I2<I2<I2", data)
    telemetry["current2"] = current / 10.0
    telemetry["voltage2"] = voltage / 100.0
    telemetry["power2"] = power
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0A90) then
    local _, coolant_temp, coolant_duty = string.unpack("I1I1I1", data)
    telemetry["coolant_temp"] = coolant_temp - 50
    telemetry["coolant_duty"] = coolant_duty
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0490) then
    local _, stop_alarm_active = string.unpack("I4I4", data)
    local stop_alarms = parse_stop_alarms(stop_alarm_active)
    alerts = table.move(stop_alarms, 1, #stop_alarms, #alerts + 1, alerts)
    alerts_received = true
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0590) then
    local _, shut_alarm_active = string.unpack("I4I4", data)
    local shut_alarms = parse_shutdown_alarms(shut_alarm_active)
    alerts = table.move(shut_alarms, 1, #shut_alarms, #alerts + 1, alerts)
    alerts_received = true
  end

  if msg_id == get_msg_id(0x1C8, user_can_id, 0x0690) then
    local _, warning_active = string.unpack("I4I4", data)
    local warnings = parse_warnings(warning_active)
    alerts = table.move(warnings, 1, #warnings, #alerts + 1, alerts)
    alerts_received = true
  end
end

function get_msg_id(msb, can_id, lsb)
  return (((msb << 4) | can_id - 1) << 16) | lsb
end

function get_hex_string(hex)
  return '0x'..string.rep('0', 8 - #string.format('%x', hex))..string.format('%x', hex)
end

function parse_stop_alarms(code)
  local stop_codes = {
    0x00000001, 0x00000002, 0x00000004, 0x00000008,
    0x00000010, 0x00000020, 0x00000040, 0x00000080,
    0x00000100, 0x00000200, 0x00000400,
    0x00001000, 0x00002000, 0x00004000, 0x00008000,
    0x00020000, 0x00040000, 0x00080000
  }
  local alarms = {}
  if code ~= 0 then
    if is_one_of(code, stop_codes) then
      table.insert(alarms, 'stop_'..get_hex_string(code))
    else
      table.insert(alarms, 'stop_underfined')
    end
  end
  return alarms
end

function parse_shutdown_alarms(code)
  local shutdown_codes = {
    0x00000001, 0x00000002, 0x00000004, 0x00000008,
    0x00000010,
    0x00000100, 0x00000200, 0x00000400, 0x00000800,
    0x00001000, 0x00004000, 0x00008000,
    0x00010000,
    0x00100000, 0x00800000,
    0x02000000,
    0x10000000, 0x40000000
  }
  local alarms = {}
  if code ~= 0 then
    if is_one_of(code, shutdown_codes) then
      table.insert(alarms, 'shutdown_'..get_hex_string(code))
    else
      table.insert(alarms, 'shutdown_underfined')
    end
  end
  return alarms
end

function parse_warnings(code)
  local warning_codes = {
    0x00000001, 0x00000002, 0x00000004, 0x00000008,
    0x00000010, 0x00000020, 0x00000040,
  }
  local alarms = {}
  if code ~= 0 then
    if is_one_of(code, warning_codes) then
      table.insert(alarms, 'warning_'..get_hex_string(code))
    else
      table.insert(alarms, 'warning_underfined')
    end
  end
  return alarms
end

function is_one_of(item, list)
  for _, value in pairs(list) do
    if value == item then
      return true
    end
  end
  return false
end

function command_set_start_voltage1(ctx, args)
    if args.voltage ~= nil then
      local request = string.pack("I2I2", 0, math.floor(args.voltage * 100))
      local result = can.err_to_str(can.send(get_msg_id(0x1C0, user_can_id, 0x0090), request))
      if result ~= 'Success' then
        ctx.error(result)
      else
        return result
      end
    else
      ctx.error('No voltage argument')
    end
end

function command_set_start_voltage2(ctx, args)
    if args.voltage ~= nil then
      local request = string.pack("I2I2", 10, math.floor(args.voltage * 100))
      local result = can.err_to_str(can.send(get_msg_id(0x1C0, user_can_id, 0x0090), request))
      if result ~= 'Success' then
        ctx.error(result)
      else
        return result
      end
    else
      ctx.error('No voltage argument')
    end
end

function command_set_stop_voltage1(ctx, args)
    if args.voltage ~= nil then
      local request = string.pack("I2I2", 1, math.floor(args.voltage * 100))
      local result = can.err_to_str(can.send(get_msg_id(0x1C0, user_can_id, 0x0090), request))
      if result ~= 'Success' then
        ctx.error(result)
      else
        return result
      end
    else
      ctx.error('No voltage argument')
    end
end

function command_set_stop_voltage2(ctx, args)
    if args.voltage ~= nil then
      local request = string.pack("I2I2", 11, math.floor(args.voltage * 100))
      local result = can.err_to_str(can.send(get_msg_id(0x1C0, user_can_id, 0x0090), request))
      if result ~= 'Success' then
        ctx.error(result)
      else
        return result
      end
    else
      ctx.error('No voltage argument')
    end
end

function command_set_target_voltage1(ctx, args)
    if args.voltage ~= nil then
      local request = string.pack("I2I2", 3, math.floor(args.voltage * 100))
      local result = can.err_to_str(can.send(get_msg_id(0x1C0, user_can_id, 0x0090), request))
      if result ~= 'Success' then
        ctx.error(result)
      else
        return result
      end
    else
      ctx.error('No voltage argument')
    end
end

function command_set_target_voltage2(ctx, args)
    if args.voltage ~= nil then
      local request = string.pack("I2I2", 14, math.floor(args.voltage * 100))
      local result = can.err_to_str(can.send(get_msg_id(0x1C0, user_can_id, 0x0090), request))
      if result ~= 'Success' then
        ctx.error(result)
      else
        return result
      end
    else
      ctx.error('No voltage argument')
    end
end

function send_autostart_request()
  local autostart, err = config.read(AUTOSTART_CONFIG)
  if autostart ~= nil then
    if autostart == true then
      local result = can.err_to_str(can.send(get_msg_id(0x140, user_can_id, 0x0090), string.pack("B", 1)))
      if result ~= 'Success' then
        enapter.log('CAN request failed: '..result, 'error')
      end
    else
      return
    end
  else
    enapter.log('Config read failed: '..err, 'error')
  end
end

main()
