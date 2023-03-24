local rx_scale_factor10 = 10.0
local rx_scale_factor100 = 100.0

function build(can_index, save_0x400)
  local messages = {
    properties = {
      { name = 'fw_ver', msg_id = 0x318 + can_index - 1, parser = software_version },
      {
        name = 'serial_number',
        msg_id = 0x310 + can_index - 1,
        multi_msg = true,
        parser = make_serial_number_parser(),
      },
    },
    telemetry = {
      {
        names = { 'run_hours', 'total_run_energy' },
        msg_id = 0x320 + can_index - 1,
        parser = bytes_extractor({
          { type = 'uint32', from = 1, to = 4 },
          { type = 'uint32', from = 5, to = 8 },
        }),
      },
      {
        names = { 'fault_flags_a', 'fault_flags_b' },
        msg_id = 0x328 + can_index - 1,
        parser = bytes_extractor({
          { type = 'uint32', from = 1, to = 4 },
          { type = 'uint32', from = 5, to = 8 },
        }),
      },
      {
        names = { 'fault_flags_c', 'fault_flags_d' },
        msg_id = 0x378 + can_index - 1,
        parser = bytes_extractor({
          { type = 'uint32', from = 1, to = 4 },
          { type = 'uint32', from = 5, to = 8 },
        }),
      },
      {
        names = { 'watt', 'volt', 'amp', 'anode_pressure' },
        msg_id = 0x338 + can_index - 1,
        parser = bytes_extractor({
          { type = 'int16', from = 1, to = 2 },
          { type = 'int16', from = 3, to = 4, scale_factor = rx_scale_factor100 },
          { type = 'int16', from = 5, to = 6, scale_factor = rx_scale_factor100 },
          { type = 'int16', from = 7, to = 8, scale_factor = rx_scale_factor10 },
        }),
      },
      {
        names = { 'outlet_temp', 'inlet_temp', 'dcdc_volt_setpoint', 'dcdc_amp_limit' },
        msg_id = 0x348 + can_index - 1,
        parser = bytes_extractor({
          { type = 'int16', from = 1, to = 2, scale_factor = rx_scale_factor100 },
          { type = 'int16', from = 3, to = 4, scale_factor = rx_scale_factor100 },
          { type = 'int16', from = 5, to = 6, scale_factor = rx_scale_factor100 },
          { type = 'int16', from = 7, to = 8, scale_factor = rx_scale_factor100 },
        }),
      },
      {
        names = { 'louver_pos', 'fan_sp_duty' },
        msg_id = 0x358 + can_index - 1,
        parser = bytes_extractor({
          { type = 'int16', from = 1, to = 2, scale_factor = rx_scale_factor100 },
          { type = 'int16', from = 3, to = 4, scale_factor = rx_scale_factor100 },
        }),
      },
      { name = 'status', msg_id = (0x368 + can_index - 1), parser = parse_status },
    },
  }

  if save_0x400 then
    table.insert(messages.telemetry, {
      name = 'messages_0x400',
      msg_id = 0x400 + can_index - 1,
      multi_msg = true,
      parser = dump_0x400_parser,
    })
  end

  return messages
end

local function convert_input_data(data)
  local v = { string.unpack('c2c2c2c2c2c2c2c2', data) }
  local vv = {}
  for j = 1, 8 do
    vv[j] = tonumber(v[j], 16)
  end
  return string.pack('BBBBBBBB', table.unpack(vv))
end

function make_serial_number_parser()
  local serial_number_first_part = ''
  return function(datas)
    for _, data in ipairs(datas) do
      data = convert_input_data(data)
      if string.byte(data, 1) > 127 then
        if serial_number_first_part ~= '' then
          local serial_number_second_part =
            string.char(string.byte(data, 1, 1) - 128, string.byte(data, 2, 8))
          local serial_number = serial_number_first_part .. serial_number_second_part
          serial_number_first_part = ''
          return serial_number:match('([^\0]*)')
        end
      else
        serial_number_first_part = data
      end
    end
  end
end

function dump_0x400_parser(datas)
  local str_0x400 = nil
  for _, data in pairs(datas) do
    str_0x400 = str_0x400 or ''
    str_0x400 = str_0x400 .. ' ' .. data
  end
  return str_0x400
end

function bytes_extractor(parts)
  return function(data)
    data = convert_input_data(data)
    local ret = {}
    for i, p in pairs(parts) do
      local s = string.sub(data, p.from, p.to)
      if p.type == 'uint32' then
        ret[i] = touint32(s)
      elseif p.type == 'int16' then
        ret[i] = toint16(s)
      else
        assert('bad type')
      end

      if p.scale_factor ~= nil then
        ret[i] = ret[i] / p.scale_factor
      end
    end
    return ret
  end
end

function toint16(data)
  return string.unpack('>i2', data)
end

function touint32(data)
  return string.unpack('>I4', data)
end

function parse_status(data)
  local state = string.sub(data, 1, 2)
  if state == '10' then
    return 'fault'
  elseif state == '20' then
    return 'steady'
  elseif state == '40' then
    return 'run'
  elseif state == '80' then
    return 'inactive'
  else
    return nil
  end
end

function software_version(data)
  data = convert_input_data(data)
  return string.format('%u.%u.%u', string.byte(data, 1), string.byte(data, 2), string.byte(data, 3))
end

return {
  build = build,
}
