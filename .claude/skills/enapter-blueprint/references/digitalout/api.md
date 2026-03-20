# Lua API Digital Output Reference

Available on: ENP-RL6 (6 ports), ENP-RL6 M2 (6 ports), Virtual UCM (Arrakis Mk3/Mk4 with DIO module, 4 ports; or any PC via Generic IO).

> For relay-specific semantics (open/close/impulse) use [`relay`](../relay/api.md) instead.

## `digitalout.new`

```lua
-- @param connection_uri string  e.g. "port://do-1"
-- @return object|nil, string|nil
function digitalout.new(connection_uri)
end
```

## Constants

- `digitalout.LOW` — output is open
- `digitalout.HIGH` — output is closed

## `client:set_state`

Sets the output state.

```lua
-- @param state digitalout.HIGH|digitalout.LOW
-- @return string|nil
function client:set_state(state)
end
```

```lua
local do1, _ = digitalout.new('port://do-1')
local err = do1:set_state(digitalout.HIGH)
if err ~= nil then
  enapter.log('set_state failed: ' .. err, 'error')
end
```

## `client:get_state`

Returns current state (`digitalout.HIGH` or `digitalout.LOW`).

```lua
-- @return digitalout.HIGH|digitalout.LOW, string|nil
function client:get_state()
end
```
