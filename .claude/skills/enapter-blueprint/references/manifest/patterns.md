# Manifest Patterns

## File Name

Blueprint manifest should ALWAYS have name `manifest.yml`.

## Reference Examples

Use ONLY blueprints with a `blueprint_spec: device/3.0` as a reference.

## Check manifest against the schema

Always check the manifest against the [schema](schema.json).

## Use `implemented_profiles`

If user wants integrate their device with different parts of the Enapter platform (e.g. using Enpter Rules) and ensure its interoperability across different device vendors and models, use of [Enapter Device profiles](../profiles).


## Use `configuration`

Mandatory when the blueprint should implement device connection logic e.g. read metrics, set device settings, run commands on device. See [the configuration guide](./configuration.md) for use cases and best practices.


## Use only UCUM-compliant units

Use units from the [UCUM](https://ucum.org/) standard. Common examples:

| Quantity | Unit symbol |
|---|---|
| Power | `W`, `kW`, `MW` |
| Energy | `Wh`, `kWh`, `MWh` |
| Voltage | `V` |
| Current | `A` |
| Frequency | `Hz` |
| Temperature (Celsius) | `Cel` |
| Pressure (Pascal) | `Pa`, `kPa`, `bar` |
| Percentage | `%` |
| Apparent power | `VA` |
| Reactive power | `VAR` |
| Resistance | `Ohm` |
| Capacity | `Ah` |

> **Note**: Do NOT use `C` for Celsius (it means Coulomb) — use `Cel`. Do NOT use `F` for Fahrenheit (it means Farad). Set `allow_unit_c: true` or `allow_unit_f: true` in the manifest if unavoidable.


## Validation Checklist

Before finalizing the manifest:

- [ ] `display_name` is concise and descriptive (3-50 chars)
- [ ] `icon` exists (either `enapter-*` or valid Material Community icon)
- [ ] `runtime.requirements` includes only used protocols (no `lua_api_ver_3`)
- [ ] `implements` references known profiles only, or is empty with documentation note
- [ ] `telemetry.status` defined with proper enum and colors from recommendations
- [ ] **NO both `status` AND `state`** - never have both fields in telemetry (merge state into status enum)
- [ ] `telemetry.conn_alerts` defined with `type: alerts`
- [ ] All numeric telemetry has `type` and `unit`
- [ ] Command arguments do NOT have `unit` field
- [ ] All alerts have `severity` and `display_name`
- [ ] Command groups exist for all referenced commands
- [ ] All command `group` references exist in `command_groups`