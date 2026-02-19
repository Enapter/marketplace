# Manifest Style Guide

## Naming Conventions

- Use `snake_case` for all field names (telemetry keys, property keys, alert names, command names, argument names, configuration group/parameter names).
- Use `display_name` values in **Title Case** (e.g. `Battery Voltage`, not `battery voltage`).
- Alert names should be lowercase snake_case matching their meaning (e.g. `communication_failed`, `overtemperature`).

## Ordering Convention

Recommended top-level key order in `manifest.yml`:

```yaml
blueprint_spec: device/3.0
display_name: ...
description: ...
icon: ...
category: ...
license: MIT
author: ...
contributors: ...   # optional
support: ...

implements: ...     # optional, profiles

runtime: ...

configuration: ...  # if device needs connection config

properties: ...
telemetry: ...
alerts: ...
commands: ...       # optional
command_groups: ... # if commands are present

.cloud: ...         # optional, UI hints
```

## Telemetry Field Conventions

- Always declare a `status` field with an explicit enum.
- Always declare `conn_alerts` as type `alerts` (not telemetry directly).
- Use consistent enum keys matching Lua script values exactly.

## YAML Conventions

- Use 2-space indentation.
- Prefer block scalars (`|`) for multi-line descriptions.
- Avoid unnecessary quoting — only quote strings containing YAML special characters (`:`, `#`, `{`, etc.).
- Boolean values: use `true`/`false`, not `yes`/`no`.
