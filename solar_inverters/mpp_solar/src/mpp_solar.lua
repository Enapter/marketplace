local mpp_solar = {}

mpp_solar.baudrate = 2400
mpp_solar.data_bits = 8
mpp_solar.parity = 'N'
mpp_solar.stop_bits = 1
mpp_solar.no_qpgs = { 'VM-3000', 'MKS2-5000' }

function mpp_solar:run_with_cache(name)
  if mpp_solar:is_in_cache(name) then
    local data = mpp_solar:run_command(name)
    if data and data ~= 'NAK' then
      mpp_solar:add_to_cache(name, data, os.time())
      return true, data
    end
  else
    local result, data = mpp_solar:read_cache(name)
    if result then
      return true, data
    end
  end
  return false
end

function mpp_solar:set_value(name)
  local res = mpp_solar:run_command(name)
  if res then
    if res == 'ACK' then
      return true, nil
    elseif res == 'NAK' then
      return false, 'Response: NAK'
    else
      return false, 'Response neither ACK or NAK'
    end
  else
    return false, 'No response from device'
  end
end

function mpp_solar:run_command(name)
  if name ~= nil then
    local crc = mpp_solar:crc16(name)
    name = name .. string.char((crc & 0xFF00) >> 8)
    name = name .. string.char(crc & 0x00FF)
    name = name .. string.char(0x0D)
    rs232.send(name)

    local raw_data, result = rs232.receive(2000)
    if raw_data and string.byte(raw_data, #raw_data) == 0x0d then
      local data = string.sub(raw_data, 1, -4)
      local r_crc = mpp_solar:crc16(data)
      if
        (r_crc & 0xFF00) >> 8 == string.byte(raw_data, -3)
        and r_crc & 0x00FF == string.byte(raw_data, -2)
      then
        local com_response = string.sub(data, 2)
        mpp_solar:add_to_cache(name, com_response, os.time())
        return com_response
      end
    else
      enapter.log(name .. ' command failed: ' .. rs232.err_to_str(result), 'error')
    end
  end
  return nil
end

COMMAND_CACHE = {}

function mpp_solar:add_to_cache(command_name, data, updated)
  COMMAND_CACHE[command_name] = { data = data, updated = updated }
end

function mpp_solar:read_cache(command_name)
  if COMMAND_CACHE[command_name] then
    return true, COMMAND_CACHE[command_name].data
  end
  return false
end

function mpp_solar:is_in_cache(command_name)
  local com_data = COMMAND_CACHE[command_name]
  if com_data == nil then
    return true
  end
  if com_data.updated + 60 < os.time() then
    return true
  end
  return false
end

function mpp_solar:crc16(pck)
  local index
  local crc = 0
  local da
  local t_da
  local crc_ta = {
    0x0000,
    0x1021,
    0x2042,
    0x3063,
    0x4084,
    0x50a5,
    0x60c6,
    0x70e7,
    0x8108,
    0x9129,
    0xa14a,
    0xb16b,
    0xc18c,
    0xd1ad,
    0xe1ce,
    0xf1ef,
  }

  for i = 1, #pck do
    t_da = crc >> 8
    da = t_da >> 4
    crc = (crc << 4) & 0xFFFF
    index = (da ~ (string.byte(pck, i) >> 4)) + 1
    crc = crc ~ crc_ta[index]
    t_da = crc >> 8
    da = t_da >> 4
    crc = (crc << 4) & 0xFFFF
    index = (da ~ (string.byte(pck, i) & 0x0F) & 0xFFFF) + 1
    crc = crc ~ crc_ta[index]
  end

  local b_crc_low = crc & 0xFF
  local b_crc_high = (crc >> 8) & 0xFF

  if b_crc_low == 0x28 or b_crc_low == 0x0D or b_crc_low == 0x0A then
    b_crc_low = b_crc_low + 1
  end
  if b_crc_high == 0x28 or b_crc_high == 0x0D or b_crc_high == 0x0A then
    b_crc_high = b_crc_high + 1
  end

  crc = (b_crc_high & 0xFFFF) << 8
  crc = crc + b_crc_low

  return crc
end

MA_VOLTAGE_PERIOD = 10
MA_VOLTAGE_TABLE = {}

function mpp_solar:get_battery_voltage()
  local voltage, err = mpp_solar:run_qpigs_command(9)
  if err then
    MA_VOLTAGE_TABLE = {}
    return nil, err
  end

  mpp_solar:add_voltage_to_table(tonumber(voltage))
  return mpp_solar:get_ma_voltage()
end

function mpp_solar:add_voltage_to_table(voltage)
  if #MA_VOLTAGE_TABLE == MA_VOLTAGE_PERIOD then
    table.remove(MA_VOLTAGE_TABLE, 1)
  end
  MA_VOLTAGE_TABLE[#MA_VOLTAGE_TABLE + 1] = voltage
end

function mpp_solar:get_ma_voltage()
  local function sum(a, ...)
    if a then
      return a + sum(...)
    else
      return 0
    end
  end
  return sum(table.unpack(MA_VOLTAGE_TABLE)) / #MA_VOLTAGE_TABLE
end

function mpp_solar:run_qpigs_command(index)
  local qpigs_data_len = 17
  if not (0 < index and index < qpigs_data_len + 1) then
    return nil, 'QPIGS wrong index ' .. index
  end

  local data = mpp_solar:run_command('QPIGS')
  if not data then
    return nil, 'QPIGS command was not successful'
  end

  local qpigs_list = split(data, ' ')
  return qpigs_list[index]
end

function split(str, sep)
  if sep == nil then
    sep = '%s'
  end

  local t = {}
  for part in string.gmatch(str, '([^' .. sep .. ']+)') do
    table.insert(t, part)
  end

  return t
end

return mpp_solar
