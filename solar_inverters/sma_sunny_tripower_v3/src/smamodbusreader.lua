local SmaModbusReader = {}

function SmaModbusReader.new(modbus_client, unit_id)
  local self = setmetatable({}, { __index = SmaModbusReader })
  self.modbus = modbus_client
  self.unit_id = unit_id
  self.has_error = false
  return self
end

function SmaModbusReader:read_holdings(address, count)
  local registers, err = self.modbus:read_holdings(self.unit_id, address, count, 1000)
  if err ~= nil then
    self.has_error = true
    enapter.log('read holdings error, register ' .. address .. ': ' .. err, 'error', true)
    return
  end
  return registers
end

function SmaModbusReader:query(queries)
  local results, err = self.modbus:read(queries)
  if not results then
    self.has_error = true
    enapter.log('no data received', 'error', true)
    results = {}
  end

  function results.get(index)
    if not results then
      return
    end
    if #results < index then
      return
    end
    return results[index]
  end

  if err then
    self.has_error = true
    enapter.log('failed to query: ' .. err, 'error', true)
    results = {}
    return
  end

  if #queries ~= #results then
    self.has_error = true
    enapter.log('invalid response length (expected: ' .. #queries .. ', got: ' .. #results .. ')', 'error', true)
    return
  end

  for i, _ in ipairs(results) do
    local err = self:check_query_result(results, i)
    if err then
      self.has_error = true
      enapter.log(err, 'error', true)
    end
  end

  return results
end

function SmaModbusReader:check_query_result(results, num)
  local res = results[num]
  if res.errmsg ~= nil then
    return 'reading query error ' .. num .. ': ' .. res.errmsg
  end

  if res.data == nil then
    return 'reading query error' .. num .. ': data is missing'
  end
  return nil
end

function SmaModbusReader:parse_u32_enum(data, start)
  return self:parse_u32(data, start)
end

function SmaModbusReader:parse_u32_fix0(data, start)
  return self:parse_u32(data, start)
end

function SmaModbusReader:parse_u32_fix1(data, start)
  local v = self:parse_u32(data, start)
  if not v then
    return nil
  end
  return v / 10
end

function SmaModbusReader:parse_u32_fix2(data, start)
  local v = self:parse_u32(data, start)
  if not v then
    return nil
  end
  return v / 100
end

function SmaModbusReader:parse_u32_fix3(data, start)
  local v = self:parse_u32(data, start)
  if not v then
    return nil
  end
  return v / 1000
end

local function get_u32(reg1, reg2)
  return string.unpack('>I4', string.pack('>I2I2', reg1, reg2))
end

function SmaModbusReader:parse_u32(data, start)
  if not validate_u32_registers(data, start) then
    return
  end
  return get_u32(data[start], data[start + 1])
end

function SmaModbusReader:read_u32_enum(address)
  return self:read_u32(address)
end

function SmaModbusReader:read_u32_fix0(address)
  return self:read_u32(address)
end

function SmaModbusReader:read_u32_fix1(address)
  local v = self:read_u32(address)
  if not v then
    return nil
  end
  return v / 10
end

function SmaModbusReader:read_u32_fix2(address)
  local v = self:read_u32(address)
  if not v then
    return nil
  end
  return v / 100
end

function SmaModbusReader:read_u32_fix3(address)
  local v = self:read_u32(address)
  if not v then
    return nil
  end
  return v / 1000
end

function SmaModbusReader:read_u32(address)
  local data, err = self:read_holdings(address, 2)
  if err then
    self.has_error = true
    enapter.log('failed to read register ' .. address .. ': ' .. err, 'error', true)
    return
  end
  if not validate_u32_registers(data, address) then
    return
  end
  return get_u32(data[1], data[2])
end

function validate_u32_registers(data, start)
  if not data then
    return
  end

  if data[start] == 0xFFFF and data[start + 1] == 0xFFFF then
    enapter.log('registers ' .. start .. '-' .. (start + 1) .. ' contain NaN value for uint32', 'warning', true)
    return false
  end

  if data[start] == 0x00FF and data[start + 1] == 0xFFFD then
    enapter.log('registers ' .. start .. '-' .. (start + 1) .. ' contain NaN value for enum', 'warning', true)
    return false
  end
  return true
end

function SmaModbusReader:parse_s32_fix0(data, start)
  return self:parse_s32(data, start)
end

function SmaModbusReader:parse_s32_fix1(data, start)
  local v = self:parse_s32(data, start)
  if not v then
    return nil
  end
  return v / 10
end

function SmaModbusReader:parse_s32_fix2(data, start)
  local v = self:parse_s32(data, start)
  if not v then
    return nil
  end
  return v / 100
end

function SmaModbusReader:parse_s32_fix3(data, start)
  local v = self:parse_s32(data, start)
  if not v then
    return nil
  end
  return v / 1000
end

local function validate_s32_registers(data, start)
  if not data then
    return false
  end
  if data[start] == 0x8000 and data[start + 1] == 0 then
    return false
  end
  return true
end

local function get_s32(reg1, reg2)
  return string.unpack('>i4', string.pack('>I2I2', reg1, reg2))
end

function SmaModbusReader:parse_s32(data, start)
  if not validate_s32_registers(data, start) then
    return
  end
  return get_s32(data[start], data[start + 1])
end

function SmaModbusReader:read_s32_fix0(address)
  return self:read_s32(address)
end

function SmaModbusReader:read_s32_fix1(address)
  local v = self:read_s32(address)
  if not v then
    return nil
  end
  return v / 10
end

function SmaModbusReader:read_s32_fix2(address)
  local v = self:read_s32(address)
  if not v then
    return nil
  end
  return v / 100
end

function SmaModbusReader:read_s32_fix3(address)
  local v = self:read_s32(address)
  if not v then
    return nil
  end
  return v / 1000
end

function SmaModbusReader:read_s32(address)
  local data, err = self:read_holdings(address, 2)
  if err then
    self.has_error = true
    enapter.log('failed to read register ' .. address .. ': ' .. err, 'error', true)
    return
  end
  if not validate_s32_registers(data, address) then
    return
  end
  return get_s32(data[1], data[2])
end

function SmaModbusReader:read_u64(address)
  local reg, err = self:read_holdings(address, 4)
  if err then
    self.has_error = true
    enapter.log('failed to read register ' .. address .. ': ' .. err, 'error', true)
    return
  end

  local raw = string.pack(
    'BBBBBBBB',
    reg[1] >> 8,
    reg[1] & 0xff,
    reg[2] >> 8,
    reg[2] & 0xff,
    reg[3] >> 8,
    reg[3] & 0xff,
    reg[4] >> 8,
    reg[4] & 0xff
  )

  return string.unpack('>I8', raw)
end

function SmaModbusReader:read_u64_fix0(address)
  return self:read_u64(address)
end

return SmaModbusReader
