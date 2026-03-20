# Lua API Analog Input Reference

Available on: ENP-AI4-50V (voltage, 4 ports), ENP-AI4-20MA (current, 4 ports), ENP-AI6 M2 (6 voltage + 2 current + 2 temperature ports).

> Hardware ports must be configured before use.

## `analogin.new`

```lua
-- @param connection_uri string  e.g. "port://ai-1"
-- @return object|nil, string|nil
function analogin.new(connection_uri)
end
```

## `client:get_volts`

Returns voltage in Volts. **Not available on ENP-AI4-20MA.**

```lua
-- @return number|nil, string|nil
function client:get_volts()
end
```

```lua
local client, _ = analogin.new('port://ai-1')
local volts, err = client:get_volts()
if err ~= nil then
  enapter.log('Unable to get voltage: ' .. err, 'error')
end
```

## `client:get_amps`

Returns current in Amperes. **Not available on ENP-AI4-50V.**

```lua
-- @return number|nil, string|nil
function client:get_amps()
end
```

## `client:get_temperature`

Returns temperature in degrees Celsius. **Only available on ENP-AI6 M2.** Port must be configured for temperature reading.

```lua
-- @return number|nil, string|nil
function client:get_temperature()
end
```
