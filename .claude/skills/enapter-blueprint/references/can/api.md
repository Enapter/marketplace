# Lua API CAN Reference

Available on: ENP-CAN, ENP-RS-CAN-USB M2, Virtual UCM (Arrakis Mk3/Mk4 with CAN module, or any PC via Generic IO).

> Hardware CAN ports must be configured before use.

## `can.new`

```lua
-- @param connection_uri string  e.g. "port://can-1"
-- @return object|nil, string|nil
function can.new(connection_uri)
end
```

## Constants

- `can.DROP_OLDEST` — when queue is full, drop the oldest entry
- `can.DROP_NEWEST` — when queue is full, discard the incoming entry

## `client:send`

```lua
-- @param id   number CAN message ID
-- @param data string Data to send
-- @return string|nil
function client:send(id, data)
end
```

```lua
local err = client:send(0x213, 'Hello World')
if err ~= nil then
  enapter.log('CAN send error: ' .. err, 'error')
end
```

## `client:monitor`

Returns the **most recent** value per ID. Use when only the latest reading matters.

```lua
-- @param ids table List of CAN message IDs to monitor
-- @return object|nil, string|nil
function client:monitor(ids)
end
```

```lua
local monitor, err = client:monitor({ 0x400, 0x213, 0x317 })
```

## `client:queue`

Buffers **all** incoming messages per ID. Use when historical data matters.

```lua
-- @param ids    table
-- @param size   number                       Max messages stored per ID
-- @param policy can.DROP_OLDEST|can.DROP_NEWEST
-- @return object|nil, string|nil
function client:queue(ids, size, policy)
end
```

```lua
local queue, err = client:queue({ 0x213, 0x317 }, 10, can.DROP_OLDEST)
```

## `monitor:pop`

Returns latest stored values for the given IDs and clears the monitor. Result index matches input index; nil if no data received yet.

```lua
-- @param ids table
-- @return table|nil, string|nil
function monitor:pop(ids)
end
```

```lua
local data, err = monitor:pop({ 0x213, 0x317, 0x239 })
-- data[1] -> 0x213, data[2] -> 0x317, data[3] -> 0x239
```

## `queue:pop`

Returns all stored values for a single ID and clears that queue entry.

```lua
-- @param id number
-- @return table|nil, string|nil
function queue:pop(id)
end
```

## `queue:drops_count`

Returns the number of dropped packets for a given ID.

```lua
-- @param id number
-- @return number|nil, string|nil
function queue:drops_count(id)
end
```
