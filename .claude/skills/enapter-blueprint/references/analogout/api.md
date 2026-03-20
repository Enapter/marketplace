# Lua API Analog Output Reference

Available on: ENP-AO4 (voltage, 4 ports), ENP-AO6 M2 (voltage + current, 6 ports).

## `analogout.new`

```lua
-- @param connection_uri string  e.g. "port://ao-1"
-- @return object|nil, string|nil
function analogout.new(connection_uri)
end
```

## `client:set_volts`

Sets the output voltage in Volts.

```lua
-- @param voltage number
-- @return string|nil
function client:set_volts(voltage)
end
```

## `client:set_amps`

Sets the output current in Amperes. **Not available on ENP-AO4.**

```lua
-- @param amperage number
-- @return string|nil
function client:set_amps(amperage)
end
```
