# CAN Patterns

## Usage in `reconnect` pattern

The surrounding code can be found in [lua-script](../lua-script/patterns.md#reconnect-pattern) reference.

```lua
function reconnect()
  -- the rest of the code listed in ../lua-script/patterns.md

  client, err = can.new(conn_cfg.conn_str)
  if not client then
    enapter.log('connect: client creation failed: ' .. err, 'error')
    return
  end
end
```

## Choosing `monitor` vs `queue`

| | `client:monitor` | `client:queue` |
|---|---|---|
| Use when | Only the **latest** value per ID matters | **All** messages must be processed (e.g. counters, events) |
| Memory | Fixed (1 value per ID) | Bounded by `size` parameter |
| On overflow | Silently overwrites old value | Drops oldest or newest per policy |

## Reading data in `send_telemetry`

```lua
local monitor  -- initialized in reconnect()

function reconnect()
  -- ...
  client, err = can.new(conn_cfg.conn_str)
  if client then
    monitor, err = client:monitor({ 0x100, 0x101 })
  end
end

function send_telemetry()
  if not monitor then return end

  local data, err = monitor:pop({ 0x100, 0x101 })
  if err then
    enapter.log('monitor pop: ' .. err, 'error')
    return
  end

  enapter.send_telemetry({
    voltage = parse_voltage(data[1]),
    current = parse_current(data[2]),
  })
end
```
