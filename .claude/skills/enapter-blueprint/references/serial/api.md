# Lua API Serial Reference

## `serial.new`

```lua
-- @param connection_uri string Connection URI
-- @return serial object|nil, string|nil
function serial.new(connection_uri)
end
```

Creates a new [serial client](#client-object).

Use `port` schema to access hardware ports.

On failure, it returns nil and an error message string.

## `client` Object

### `client:flush`

```lua
-- @return string|nil
function client:flush()
end
```

Clears the input buffer of the serial connection.

On success, the function returns nil. On failure, it returns an error message string.

### `client:read`

```lua
-- @param count number Number of bytes to read
-- @param timeout number Timeout (in milliseconds) to complete the read
-- @return string|nil, string|nil
function client:read(count, timeout)
end
```

Reads exactly `count` bytes from the serial connection or fails after `timeout` milliseconds.

On success, the function returns read data as a string. On failure, it returns nil and an error message string.

#### Example

```lua
-- Read 1024 bytes or timeout after 100 milliseconds
local data, err = client:read(1024, 100)
if err ~= nil then
  enapter.log("Error reading serial data: " .. err, "error")
end
```

### `client:write`

```lua
-- @param data string Data to send over the serial connection
-- @return string|nil
function client:write(data)
end
```

Writes the data to the serial connection.

On success, the function returns nil. On failure, it returns an error message string.

#### Example

```lua
local err = client:write("hello")
if err ~= nil then
  enapter.log("Error writing serial data: " .. err, "error")
end
```

### `client:transaction`

```lua
-- @param action function Function performing serial operations
-- @return any|nil, string|nil
function client:transaction(action)
end
```

Executes a transaction with exclusive access to the serial port. The `action` function can contain multiple operations.

On success, the function returns the result of `action`. On failure, it returns nil and an error message string.

#### Example

```lua
local data, err = client:transaction(function()
  client:flush()
  client:write("hello")
  system.delay(100)
  client:write("world")
  system.delay(1000)
  return client:read(1024)
end)
```

