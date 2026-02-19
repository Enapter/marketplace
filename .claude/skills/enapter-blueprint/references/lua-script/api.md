# Lua API Reference

This is a summary of the most commonly used V3 Lua APIs. For full docs see https://v3.developers.enapter.com/reference/blueprint/lua/

## Core APIs (always used)

- **`enapter`** — telemetry, properties, logging, command handlers: https://v3.developers.enapter.com/reference/blueprint/lua/enapter
- **`scheduler`** — periodic task scheduling: https://v3.developers.enapter.com/reference/blueprint/lua/scheduler
- **`configuration`** — read/write device configuration: https://v3.developers.enapter.com/docs/configuration

## Command Context (`ctx`)

Passed as first argument to every command handler:
- `ctx.error(message)` — return a user-facing error
- `ctx.log(message)` — emit a success log visible in the UI

## Device Communication

Choose one based on the device protocol:
- **Modbus** → see [modbus/api.md](../modbus/api.md)
- **Serial** → see [serial/api.md](../serial/api.md)
- **CAN** → see [can/api.md](../can/api.md)
- **HTTP** → see [http/api.md](../http/api.md)

## Other

- **`storage`** — persistent key/value store: https://v3.developers.enapter.com/reference/blueprint/lua/storage
- **`json`** — JSON encode/decode: https://v3.developers.enapter.com/reference/blueprint/lua/json
- **`system`** — delays, system info: https://v3.developers.enapter.com/reference/blueprint/lua/system
- **`datetime`** — date/time utilities: https://v3.developers.enapter.com/reference/blueprint/lua/datetime
