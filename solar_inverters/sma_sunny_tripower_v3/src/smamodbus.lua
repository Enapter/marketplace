local SmaModbusTcp = {}

function SmaModbusTcp.new(addr, unit_id)
  local self = setmetatable({}, { __index = SmaModbusTcp })
  self.addr = addr
  self.unit_id = unit_id
  return self
end

function SmaModbusTcp:connect()
  local modbus, err = modbus.new('tcp://' .. self.addr)
  if err ~= nil then
    return err
  end
  self.modbus = modbus
  return nil
end

function SmaModbusTcp:read_holdings(address, number)
  local registers, err = self.modbus:read_holdings(self.unit_id, address, number, 1000)
  if err ~= nil then
    enapter.log('read error: ' .. err, 'error')
    return nil
  end
  return registers
end

function SmaModbusTcp:read_u32(address)
  local reg = self:read_holdings(address, 2)
  if not reg then
    return
  end

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
  if not v then
    return nil
  end
  return v / 10
end

function SmaModbusTcp:read_u32_fix2(address)
  local v = self:read_u32(address)
  if not v then
    return nil
  end
  return v / 100
end

function SmaModbusTcp:read_u32_fix3(address)
  local v = self:read_u32(address)
  if not v then
    return nil
  end
  return v / 1000
end

function SmaModbusTcp:read_s32(address)
  local reg = self:read_holdings(address, 2)
  if not reg then
    return
  end

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
  if not v then
    return nil
  end
  return v / 10
end

function SmaModbusTcp:read_s32_fix2(address)
  local v = self:read_s32(address)
  if not v then
    return nil
  end
  return v / 100
end

function SmaModbusTcp:read_s32_fix3(address)
  local v = self:read_s32(address)
  if not v then
    return nil
  end
  return v / 1000
end

function SmaModbusTcp:read_u64(address)
  local reg = self:read_holdings(address, 4)
  if not reg then
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

function SmaModbusTcp:read_u64_fix0(address)
  return self:read_u64(address)
end

return SmaModbusTcp
