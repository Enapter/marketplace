# Migrating Blueprints from V1 to V3

Use this guide when user needs rewrite blueprint v1 to v3.

## Summary of Changes

| Area | V1 | V3 |
|------|----|----|
| Spec field | `blueprint_spec: device/1.0` | `blueprint_spec: device/3.0` |
| Hardware binding | `communication_module.product: ENP-RL6` | `runtime.requirements: [relay]` |
| Entrypoint | `function main() … end; main()` | `function enapter.main() … end` (called automatically) |
| Config | Lua `require('enapter.ucm.config')` | Manifest `configuration:` + `configuration.read()` |
| Error handling | `result ~= 0` + `err_to_str(result)` | `err ~= nil` (errors are strings) |
| Hardware API | Function-based `di7.is_closed(1)` | OO `channel:get_state()` |
| Enum colors | Hex `"#ffeedd"` | Named `green`, `red`, `yellow`, etc. |
| Units | Arbitrary strings | UCUM codes (`Cel` not `C`, `W` not `watt`) |
| Metadata | `vendor:`, `verification_level:` fields | Removed — managed by Marketplace |

## Step-by-Step

### 1. Update spec and metadata

```yaml
# before
blueprint_spec: device/1.0
vendor: Enapter
verification_level: verified

# after
blueprint_spec: device/3.0
category: electrolysers   # see manifest reference for valid categories
```

Remove `vendor` field.

### 2. Replace `communication_module` with `runtime`

```yaml
# before
communication_module:
  product: ENP-RL6
  lua:
    file: firmware.lua

# after
runtime:
  type: lua
  options:
    file: firmware.lua
```

Remove `product`. Hardware capabilities are expressed via `requirements` (e.g. `- relay`, `- rs485`, `- modbus`).

### 3. Use declarative configuration

Remove `read_configuration`/`write_configuration` commands, `require('enapter.ucm.config')`, `config.init()`, and `enapter-ucm` Luarocks dependency.

```yaml
# manifest
configuration:
  connection:
    display_name: Connection
    access_level: owner
    parameters:
      conn_str:
        display_name: Connection String
        description: e.g. port://rs485
        type: string
        format: connection_uri
        required: true
```

```lua
-- lua
function reconnect()
  if conn then return end
  if not configuration.is_all_required_set('connection') then return end
  local cfg, err = configuration.read('connection')
  if err then return end
  conn, _ = modbus.new(cfg.conn_str)
end
```

### 4. Use `enapter.main()` entrypoint

```lua
-- before
function main()
  scheduler.add(1000, send_telemetry)
end
main()

-- after
function enapter.main()
  scheduler.add(1000, send_telemetry)
end
-- no manual call needed
```

### 5. Migrate hardware APIs to OO style

```lua
-- before (V1)
local state, result = di7.is_closed(1)
if result ~= 0 then
  enapter.log('Error: ' .. di7.err_to_str(result), 'error')
end

-- after (V3)
local di1, err = digitalin.new('port://di-1')
local state, err = di1:get_state()
if err ~= nil then
  enapter.log('Error: ' .. err, 'error')
end
```

Common module migrations:

| V1 | V3 |
|----|----|
| `di7` | `digitalin` |
| `rl6` | `relay` or `digitalout` |
| `ai4` | `analogin` |
| `ao4` | `analogout` |
| `rs232`, `rs485` | `serial` |
| `can` | `can` |
| `modbus` | `modbus` |

### 6. Update enum colors

```yaml
# before
color: "#00ff00"

# after
color: green
```

Recommended status colors:

| Situation | Color |
|-----------|-------|
| Normal / idle | `green-lighter` |
| Active / running | `green` |
| Ramp up/down | `green-dark`, `cyan-dark` |
| Warning | `yellow` |
| Error | `red` |
| Fatal error | `red-darker` |
| Maintenance | `pink-darker` |

### 7. Update units to UCUM

```yaml
# before
unit: watt
unit: celsius

# after
unit: W
unit: Cel   # NOT "C" — that means Coulomb
```

Optionally add `auto_scale` for automatic UI scaling:

```yaml
telemetry:
  power:
    type: float
    unit: W
    auto_scale: [W, kW, MW]
```

See the UCUM units table in [manifest/patterns.md](../manifest/patterns.md).

### 8. Declare profiles (optional)

```yaml
implements:
  - sensor.ambient_temperature

telemetry:
  ambient_temperature:
    type: float
    unit: Cel
    display_name: Ambient Temperature
```

See [profiles catalog](../profiles/catalog.md) for available profiles.

### 9. Enhance alerts metadata

```yaml
alerts:
  communication_failed:
    severity: error
    display_name: Communication Failed
    description: Failed to read data from device
    troubleshooting:
      - Check physical connections
      - Verify device is powered on
```
