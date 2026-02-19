# Lua Script Best Practices & Troubleshooting

## Lua script name

It must be always `main.lua` and declared as `main.lua` in manifest.yml respectively.

## Include required metrics into telemetry

- `status` - always string, all values must be desribed in manifest
- `alerts` - empty array means 'no active alerts', nil array means 'unknown state of alerts' (usually when it's not possible to read data from device)
- `conn_alerts` - empty array means 'no active connection alerts', nil array means 'unknown state of connection alerts'

## Do not call `enapter.main` in the end

This method is always called automatically, no need to call it manually.

## Periods for scheduling telemetry and properties

- properties - send every 30 seconds
- telemetry - send every second

## Log errors

User should be notified about unexpected behavior via `enapter.log('<Error message>', 'error')

## Send Telemetry Pattern
1. Check `conn_cfg` exists (not configured) → send status with `not_configured` alert
2. Check `client` exists (disconnected) → send status with `communication_failed` alert
3. Read real-time data from device via appropriate protocol
4. If read succeeds, populate `telemetry` table with all values
5. If read fails:
   - Log error with context
   - Set `status = 'conn_error'`
   - Set `alerts = { 'communication_failed' }` (reset alerts, not add)
6. Finalize telemetry object with status, alerts, and conn_alerts
7. Call `enapter.send_telemetry(telemetry)`

**Key points:**
- Always include `status` field (required in manifest)
- Always include `conn_alerts` field (required in manifest, type: alerts)
- Use separate variables: `alerts` for device state, `conn_alerts` for communication
- If any communication error occurs, set `status = 'conn_error'`
- Log errors with context (which register, which device, etc.)

## Command Handler Pattern
1. Function name: `cmd_<command_name>` matching manifest command name
2. Signature: `function cmd_name(ctx, args)`
3. Validate required arguments first: `if not args.param then ctx.error('...') end`
4. Type coercion for numeric arguments: `tonumber(args.power)`
5. Ensure connection exists, attempt reconnect if needed
6. Execute command via protocol client
7. Use `ctx.error(message)` for failures
8. Use `ctx.log(message)` for success messages
9. **Register in `enapter.main()`** with `enapter.register_command_handler()`

**Command Handler Best Practices:**
- Always validate arguments before using
- Check connection is available
- Log meaningful messages (include values, units in user-friendly format)
- Use `ctx.error()` for user-facing error messages (these appear in UI)
- Use `enapter.log()` for debug messages (developer-facing)