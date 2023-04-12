local SinexcelModbusRtu = {}

function SinexcelModbusRtu.new(addr, baudrate, data_bits, parity, stop_bits)
  assert(type(addr) == 'number', 'addr (arg #1) must be number, given: ' .. inspect(addr))
  assert(
    type(baudrate) == 'number',
    'baudrate (arg #2) must be number, given: ' .. inspect(baudrate)
  )
  assert(
    type(data_bits) == 'number',
    'data_bits (arg #3) must be number, given: ' .. inspect(data_bits)
  )
  assert(type(parity) == 'string', 'parity (arg #4) must be number, given: ' .. inspect(parity))
  assert(
    type(stop_bits) == 'number',
    'stop_bits (arg #5) must be number, given: ' .. inspect(stop_bits)
  )

  local self = setmetatable({}, { __index = SinexcelModbusRtu })
  self.addr = addr
  self.baudrate = baudrate
  self.data_bits = data_bits
  self.parity = parity
  self.stop_bits = stop_bits
  return self
end

function SinexcelModbusRtu:connect()
  rs485.init(self.baudrate, self.data_bits, self.parity, self.stop_bits)
end

function SinexcelModbusRtu:read_holdings(address, number)
  assert(type(address) == 'number', 'address (arg #1) must be number, given: ' .. inspect(address))
  assert(type(number) == 'number', 'number (arg #1) must be number, given: ' .. inspect(number))

  local registers, err = self.modbus:read_holdings(self.addr, address, number, 1000)
  if err and err ~= 0 then
    enapter.log('read error: ' .. err, 'error')
    if err == 1 then
      -- Sometimes timeout happens and it may break underlying Modbus client,
      -- this is a temporary workaround which manually reconnects.
      self:connect()
    end
    return nil
  end

  return registers
end

function SinexcelModbusRtu:read_u32(address)
  local reg = self:read_holdings(address, 2)
  if not reg then
    return
  end

  -- NaN for U32 values
  if reg[1] == 0xFFFF and reg[2] == 0xFFFF then
    return nil
  end

  local raw = string.pack('>I2I2', reg[1], reg[2])
  return string.unpack('>I4', raw)
end

function SinexcelModbusRtu:read_i16(address)
  local reg = self:read_holdings(address, 1)
  if not reg then
    return
  else
    return reg[1]
  end
end

return SinexcelModbusRtu
