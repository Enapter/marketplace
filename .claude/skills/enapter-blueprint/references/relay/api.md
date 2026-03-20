# Lua API Relay Reference

Available on: ENP-RL6, ENP-RL6 M2, Virtual UCM (Arrakis Mk3/Mk4 with DIO module, or any PC via Generic IO).

> `relay` is a high-level API with human-friendly naming. For low-level digital output control use [`digitalout`](../digitalout/api.md).

## `relay.new`

```lua
-- @param connection_uri string  e.g. "port://rl-1"
-- @return object|nil, string|nil
function relay.new(connection_uri)
end
```

## `client:close`

Closes the relay contact.

```lua
-- @return string|nil
function client:close()
end
```

## `client:open`

Opens the relay contact.

```lua
-- @return string|nil
function client:open()
end
```

## `client:impulse`

Triggers a relay impulse for `duration` milliseconds. **Non-blocking** — returns immediately before the impulse ends.

```lua
-- @param duration number Impulse duration in milliseconds
-- @return string|nil
function client:impulse(duration)
end
```

## `client:is_closed`

Returns `true` if relay is closed, `false` if open. On failure returns `false` and an error string.

```lua
-- @return boolean, string|nil
function client:is_closed()
end
```
