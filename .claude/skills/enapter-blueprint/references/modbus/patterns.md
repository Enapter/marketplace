# Modbus Patterns & Use Cases

## Usage in `reconnect` pattern

Use it when blueprint should implement device connection logic e.g. read metrics, set device settings, run commands on device.

The surrounding code can be found in [lua-script](../lua-script/patterns.md#reconnect-pattern) reference.

```lua
function reconnect()
  -- the rest of the code listed in ../lua-script/patterns.md

  client, err = modbus.new(conn_cfg.conn_str)
  if not client then
    enapter.log('connect: client creation failed: '.. err, 'error')
    return
  end
end
```

## Read as many registers as possible in one request

```lua
-- Registers map:
-- ## HOLDING
-- 0 (float32): Pressure
-- 2 (float32): Temperature
-- 4 (float32): Humidity
-- 44 (float32): Voltage
-- 56 (float32): Current
-- ## INPUT
-- 100 (uint16): Warning Flag
-- 101 (uint16): Error Flag

-- BAD
for name, reg in pairs(holding_registers) do
    local data, err = client:read_holdings(conn_cfg.address, reg.addr, reg.count, 500)
end
for name, reg in pairs(input_registers) do
    local data, err = client:read_inputs(conn_cfg.address, reg.addr, reg.count, 500)
end

-- GOOD
function fetch_metrics(client)
  local addr = conn_cfg.address
  local queries = {
    { type='holdings', addr=addr, reg=0, count=2, timeout=500 },
    { type='holdings', addr=addr, reg=2, count=2, timeout=500 },
    { type='holdings', addr=addr, reg=4, count=2, timeout=500 },
    { type='holdings', addr=addr, reg=44, count=2, timeout=500 },
    { type='holdings', addr=addr, reg=56, count=2, timeout=500 },
    { type='inputs',  addr=addr, reg=100, count=1, timeout=500 },
    { type='inputs',  addr=addr, reg=101, count=1, timeout=500 },
  }
  return read_data(client, queries)
end

function read_data(client, queries)
  local results, err = client:read(queries)
  if err then
    return nil, err
  elseif not results then
    return nil, 'no results received'
  elseif #results ~= #queries then
    return nil, 'invalid response length (expected: ' .. #queries .. ', got: ' .. #results .. ')'
  end
  return results, nil
end
```

## Properly parse read data

Modbus registers can store data of different types:

| Register | Data Type     | Number of registers |
|----------|---------------|---------------------|
| Holding  | 32-bit float  | 2                   |
| Holding  | 32-bit (u)int | 2                   |
| Input    | 16-bit (u)int | 1                   |
etc.

The stored data can be little-endian (the least-significant byte comes first) or big-endian (most significant byte comes first), so it's **crucial** to parse them according to vendor's modbus map information.

### Examples

```lua
-- Parse 32-float big-endian
function tofloat(register)
  if #register ~= 2 then return nil end
  local raw_str = string.pack("BBBB", register[1]>>8, register[1]&0xff, register[2]>>8, register[2]&0xff)
  return string.unpack(">f", raw_str)
end

-- Parse 32-signed int big-endian
local lsw = data[1]
local msw = data[2]
local packed = string.pack('>I2I2', msw, lsw)
local value = string.unpack('>i4', packed) * scale

-- Parse 16-signed int little-endian
local temperature = string.unpack('<i2', string.sub(data, 2, 3)) / 10

-- Parse 16-bit register, 8 lower bits of which is battery SOC value
local data, err = client:read_holdings(ADDRESS, 256, 1, 1000)
if data then
  telemetry.battery_soc = data[1] & 0xFF
else
  enapter.log('Register 256 reading failed: '..err, 'error')
  alerts = {'communication_failed'}
  status = 'conn_error'
end
```
