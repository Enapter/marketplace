# Enapter Blueprint Manifest Skill Reference

Use this skill when writing/rewriting Enapter Blueprint Manifest.

## Overview

Manifest file is an essential part of any device blueprint. It describes the device in a few core concepts:

1. `properties`
    - device metadata which does not change during normal device operation. "Firmware version", "Device model", and "Serial number" fit this well.
2. `telemetry`
    - device sensors data and internal state which must be tracked during device operation. Examples are "Engine temperature" and "Connection status".
3. `alerts`
    - alerts that the device can raise during operation. An example is "Engine overheating".
4. `commands`
    - commands which can be performed on the device. An example is "Turn on engine".
5. `configuration`
    - configuration parameters which needed to deice works. Examples are "Connection URI", "Modbus Address".
 
## Core Concepts

- The file is based on YAML standard.
- File name must be manifest.yml.
- `manifest.yml` must satisfy [the v3 schema](./schema.json).
- The telemetry metrics, properties and alerts must be the same as in a corresponding Lua script.
- The commands must be same as (first argument of `enapter.register_command_handler`) in a corresponding Lua script.
- The configuration groups AND paramaters must be the same as in a corresponding Lua script.

## Reading Order

1. Check [api.md](./api.md) for manifest reference
2. See [patterns.md](./patterns.md) for preferable patterns.
3. Read [configuration.md](./configuration.md) for device configuration use cases and best practices.
4. Read [style.md](./style.md) for manifest's YAML style guide.
5. Read [gotchas.md](./gotchas.md) for troubleshooting.

