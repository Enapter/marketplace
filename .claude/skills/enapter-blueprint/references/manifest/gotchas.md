# Manifest Best Practices & Troubleshooting

## Include required metrics into telemetry field

- `status` - always string, all values must be present in Lua script as well
- `conn_alerts` - always type `alerts`, with `display_name` and `description`

### Never have both `status` and `state` in telemetry

If the device has operational states (e.g. `idle`, `running`, `fault`), encode them as enum values of `status` instead of a separate `state` field. Having both is redundant.

### Correct `conn_alerts` declaration

```yaml
telemetry:
  conn_alerts:
    display_name: Connection Alerts
    description: Alerts indicating connection and configuration issues.
    type: alerts
```

## DO NOT INCLUDE

- `alerts` field in telemetry: this field is automatically added during manifest compilation.
- `lua_api_ver_3` to `requirements`
- `vendor`

## List all alerts

The highest-level field `alerts` must describe alerts both from `telemetry.alerts` and `telemetry.conn_alerts` from Lua script.

## Use only known icons

There are two sources of Enapter Blueprint manifest icons:
- https://handbook.enapter.com/icons.html
- https://go.enapter.com/material-community-icons

Icons from the first group are more preferable. An icon should align with the function of the device. When adding them to manifest, add prefix `enapter-`

### Examples

```yaml
# Add an icon from Enapter icon set
# 1
icon: enapter-dryer-industrial
# 2
icon: enapter-gauge

# Add an icon from community list
icon: play-circle
```


