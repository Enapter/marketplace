# Lua API Digital Input Reference

Available on: ENP-DI7 (7 ports), ENP-DI10 M2 (10 ports), Virtual UCM (Arrakis Mk3/Mk4 with DIO module, 4 ports; or any PC via Generic IO).

## `digitalin.new`

```lua
-- @param connection_uri string  e.g. "port://di-1"
-- @return object|nil, string|nil
function digitalin.new(connection_uri)
end
```

## Constants

- `digitalin.LOW` — input is open
- `digitalin.HIGH` — input is closed

## `client:get_state`

Returns current state (`digitalin.HIGH` or `digitalin.LOW`).

```lua
-- @return digitalin.HIGH|digitalin.LOW, string|nil
function client:get_state()
end
```

```lua
local di, _ = digitalin.new('port://di-1')
local state, err = di:get_state()
if state == digitalin.HIGH then
  -- input is closed / active
end
```

## `client:read_counter`

Returns the current impulse count. **Only available on Arrakis Mk3/Mk4 virtual UCM.**

```lua
-- @return number|nil, string|nil
function client:read_counter()
end
```

## `client:reset_counter`

Resets impulse counter to zero. **Not available on Arrakis Mk3/Mk4.**

```lua
-- @return string|nil
function client:reset_counter()
end
```
