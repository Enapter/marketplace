# Lua API Modbus Reference

## `modbus.new`

```lua
-- @param connection_uri string Connection URI
-- @return table|nil, string|nil
function modbus.new(connection_uri)
end
```

Returns a new [modbus client](#client-object).

Use `port` schema for Modbus RTU. Use `tcp` schema for Modbus TCP. On Virtual UCM you may also use `gio` schema for Generic IO.

On failure, it returns nil and an error message string.

#### Example

```lua
-- Create Modbus TCP client with server at 192.168.1.110:5678
local modbus_tcp, err = modbus.new("tcp://192.168.1.110:5678")
if err ~= nil then
  enapter.log("Can not create Modbus TCP connection: " .. err, "error")
end
-- Create Modbus RTU client over serial port rs485
local modbus_rtu, err = modbus.new("port://rs485")
if err ~= nil then
  enapter.log("Can not create Modbus RTU connection:  " .. err, "error")
end
```

## `client` Object

### `client:read_coils`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param start_register number Number of the first register to read
-- @param registers_count number Number of registers to read
-- @param timeout number Time to wait for the response in milliseconds
-- @return table|nil, string|nil
function client:read_coils(unit_id, start_register, registers_count, timeout)
end
```

Reads coil registers, Modbus function `0x01`. Returns Lua table with register contents.

On failure, it returns nil and an error message string.

#### Example

```lua {2}
-- Read two coil registers (numbers 215 and 216) of unit 1 with 500-ms timeout
local registers, err = client:read_coils(1, 215, 2, 500)
if err ~= nil then
  enapter.log("Error reading Modbus: " .. err, "error")
else
  enapter.log("Coils: " .. tostring(registers[1]) .. " " .. tostring(registers[2]))
end
```

### `client:read_discrete_inputs`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param start_register number Number of the first register to read
-- @param registers_count number Number of registers to read
-- @param timeout number Time to wait for the response in milliseconds
-- @return table|nil, string|nil
function client:read_discrete_inputs(unit_id, start_register, registers_count, timeout)
end
```

Reads discrete input registers, Modbus function `0x02`. Returns Lua table with register contents.

On failure, it returns nil and an error message string.

#### Example

```lua {2}
-- Read two discrete input registers (numbers 220 and 221) of unit 1 with 500-ms timeout
local registers, err = client:read_discrete_inputs(1, 220, 2, 500)
if err ~= nil then
  enapter.log("Error reading Modbus: " .. err, "error")
else
  enapter.log("Discrete input: " .. tostring(registers[1]) .. " " .. tostring(registers[2]))
end
```

### `client:read_holdings`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param start_register number Number of the first register to read
-- @param registers_count number Number of registers to read
-- @param timeout number Time to wait for the response in milliseconds
-- @return table|nil, string|nil
function client:read_holdings(unit_id, start_register, registers_count, timeout)
end
```

Reads holding registers, Modbus function `0x03`. Returns Lua table with register contents.

On failure, it returns nil and an error message string.

#### Example

```lua {2}
-- Read two holding registers (numbers 230 and 231) of unit 1 with 500-ms timeout
local registers, err = client:read_holdings(1, 230, 2, 500)
if err ~= nil then
  enapter.log("Error reading Modbus: " .. err, "error")
else
  enapter.log("Holding: " .. tostring(registers[1]) .. " " .. tostring(registers[2]))
end
```

### `client:read_inputs`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param start_register number Number of the first register to read
-- @param registers_count number Number of registers to read
-- @param timeout number Time to wait for the response in milliseconds
-- @return table|nil, string|nil
function client:read_inputs(unit_id, start_register, registers_count, timeout)
end
```

Reads input registers, Modbus function `0x04`. Returns Lua table with register contents.

On failure, it returns nil and an error message string.

#### Example

```lua {2}
-- Read two input registers (numbers 240 and 241) of unit 1 with 500-ms timeout
local registers, err = client:read_inputs(1, 240, 2, 500)
if err ~= nil then
  enapter.log("Error reading Modbus: " .. result, "error")
else
  enapter.log("Input: " .. tostring(registers[1]) .. " " .. tostring(registers[2]))
end
```

### `client:write_coil`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param register number Register number to write to
-- @param value number Value to write
-- @param timeout number Time to wait for the response in milliseconds
-- @return string|nil
function client:write_coil(unit_id, register, value, timeout)
end
```

Writes coil register, Modbus function `0x05`.

Returns nil if the value is written successfully, otherwise returns an error message string.

#### Example

```lua {2}
-- Write value 0 to coil register 503 of unit 1 with 500-ms timeout
local err = client:write_coil(1, 503, 0, 500)
if err ~= nil then
  enapter.log("Error writing Modbus: " .. err, "error")
end
```

### `client:write_holding`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param register number Register number to write to
-- @param value number Value to write
-- @param timeout number Time to wait for the response in milliseconds
-- @return string|nil
function client:write_holding(unit_id, register, value, timeout)
end
```

Writes holding register, Modbus function `0x06`.

Returns `nil` if the value is written successfully, otherwise returns an error message string.

#### Example

```lua {2}
-- Write value 12 to holding register 610 of unit 1 with 500-ms timeout
local err = client:write_holding(1, 610, 12, 500)
if err ~= nil then
  enapter.log("Error writing Modbus: " .. err, "error")
end
```

### `client:write_multiple_coils`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param start_register number Number of the first register to write to
-- @param values table Array of values to write to registers
-- @param timeout number Time to wait for the response in milliseconds
-- @return string|nil
function client:write_multiple_coils(unit_id, start_register, values, timeout)
end
```

Writes the sequence of coil registers, Modbus function `0x0F`. The `values` table must contain integer values to be written to the registers.

Returns nil if values are written successfully, otherwise returns an error message string.

#### Example

```lua {3}
-- Write zeroes to coil registers 700 and 701 of unit 1 with 500-ms timeout
local values = {0, 0}
local err = client:write_multiple_coils(1, 700, values, 500)
if err ~= nil then
  enapter.log("Error writing Modbus: " .. err, "error")
end
```

### `client:write_multiple_holdings`

```lua
-- @param unit_id number Unit ID of Modbus device
-- @param start_register number Number of the first register to write to
-- @param values table Array of values to write to registers
-- @param timeout number Time to wait for the response in milliseconds
-- @return string|nil
function client:write_multiple_holdings(unit_id, start_register, values, timeout)
end
```

Writes the sequence of holding registers, Modbus function `0x10`. The `values` table must contain integer values to be written to the registers.

Returns nil if values are written successfully, otherwise returns an error message string.

#### Example

```lua {4}
-- Write values to holding registers 800 and 801 of unit 1 with 500-ms timeout
-- Values 14 and 15 will be written to registers 800 and 801, respectively
local values = {14, 15}
local err = client:write_multiple_holdings(1, 800, values, 500)
if err ~= nil then
  enapter.log("Error writing Modbus: " .. err, "error")
end
```

### `client:read`

```lua
-- @param queries table Table of read queries, each specifying type, unit ID, start register, and count
-- @return table|nil, string|nil
function client:read(queries)
end
```

Reads multiple registers in a single operation. Each query in the `queries` table must specify:

- `type`: Register type (`"inputs"`, `"coils"`, `"holdings"`, or `"discrete_inputs"`).
- `addr`: Unit ID of the Modbus device.
- `reg`: Starting register number.
- `count`: Number of registers to read.
- `timeout`: Response timeout in milliseconds.

On success, returns a table containing the results with the same length as queries. The i-th result corresponds directly to the i-th query. Each result entry either contains a `data` field with the values read, or `errcode` and `errmsg` fields if the request failed.

On failure, it returns nil and an error message string.

#### Example

```lua {8}
function read_telemetry()
  -- Read two input registers (starting at 0) and two coil registers (starting at 6) from unit 1
  local queries = {
    { type="inputs", addr=1, reg=0, count=2, timeout=500 },
    { type="coils",  addr=1, reg=6, count=2, timeout=500 },
  }

  local results, err = client:read(queries)
  if err ~= nil then
    enapter.log("Modbus read error: " .. err, "error")
    return { status = "modbus_error" }
  end

  for i, result in ipairs(results) do
    if result.errmsg then
      enapter.log("Register " .. queries[i].reg .. ": " .. result.errmsg, "error")
      return { status = "modbus_error" }
    end
  end

  return {
    status = "ok",
    volts = parse_volts(results[1].data),
    state = parse_state(results[2].data),
  }
end
```

### `client:write`

```lua
-- @param queries table Table of write queries, each specifying type, unit ID, register, and value(s)
-- @return table|nil, string|nil
function client:write(queries)
end
```

Writes multiple registers in a single operation. Each query in the `queries` table must specify:

- `type`: Register type (`"holding"`, `"coil"`, `"multiple_holdings"`, or `"multiple_coils"`).
- `addr`: Unit ID of the Modbus device.
- `reg`: Starting register number.
- `value`: Value to write (for single registers).
- `values`: Table of values to write (for multiple registers).
- `timeout`: Write timeout in milliseconds.

On success, returns a table containing the results of write operations with the same length as queries. The i-th result corresponds directly to the i-th query. Each result entry  either is empty or contains `errcode` and `errmsg` fields if the request failed.

On failure, it returns nil and an error message string.

#### Example

```lua {6}
-- Write a single holding register and multiple coil registers on unit 1
local queries = {
  { type="holding",        addr=1, reg=0, value=2,      timeout=500 },
  { type="multiple_coils", addr=1, reg=6, values={4,5}, timeout=500 },
}
local results, err = client:write(queries)
if err ~= nil then
  enapter.log("Modbus write error: " ..  err, "error", true)
else
  for i, result in ipairs(results) do
    if result.errmsg then
      enapter.log("Register " .. tostring(queries[i].reg) .. ": " .. result.errmsg, "error")
    end
  end
end
```

## Byte Order

A Modbus register is composed of two bytes. Typically, the register value is transferred in Big-Endian byte order. However, the most modern CPUs, including the one in Enapter Gateway, use Little-Endian byte order. Given this, the UCM automatically performs endianness conversion, under the assumption that the Modbus server transfers values in Big-Endian order. Consequently, there is no need for you to manually perform this conversion.

Let's take an example. Imagine you have the register number `112` which holds unsigned integer value `4660` (it may be 46.6 &#8451;), which is equal to `0x1234` hexadecimal (two bytes — `0x12` and `0x34`). The value is transferred as `0x3412` (`13330` decimal), but when you read it:

```lua
-- Create Modbus TCP connection object
local client = modbus.new("tcp://192.168.1.110:502")
-- Read the value of the register 112
local registers, err =  client:read_holdings(1, 112, 1, 1000)
if not err then
  value = registers[1]
  enapter.log("Register value: " .. tostring(value))
end
```

You'll get this logged as expected without any conversions:

```text
Register value: 4660
```
