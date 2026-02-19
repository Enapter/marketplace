# Lua Script Patterns & Use Cases

## Recommended code structure

Create only one `main.lua` file containing all device logic. However, it is acceptable to store device-specific data in a separate file.

## Reference Examples

Use ONLY blueprints with a `blueprint_spec: device/3.0` as a reference.

## `reconnect` pattern

Use it when blueprint should implement device connection logic e.g. read metrics, set device settings, run commands on device.

```lua
local client = nil
local conn_cfg = nil

function enapter.main()
  reconnect()
  configuration.after_write('connection', function()
    client = nil
    conn_cfg = nil
  end)

  scheduler.add(1000, reconnect)
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)

  -- if applicable, register command handlers
  enapter.register_command_handler('some_device_command', cmd_some_device_command)
end

function reconnect()
  if client then
    return
  end

  if not configuration.is_all_required_set('connection') then
    return
  end

  local config, err = configuration.read('connection')
  if err ~= nil then
    enapter.log('read configuration: ' .. err, 'error')
    return
  end
  conn_cfg = config

  client, err = <appropriate comm protocol lib>.new(conn_cfg.conn_str)
  if not client then
    enapter.log('connect: client creation failed: '.. err, 'error')
    return
  end
end

function send_properties()
  -- read device properties (e.g. serial number, firmware version, etc.)
  -- OR send constants like vendor and model
  -- using enapter.send_properties()

end

function send_telemetry()
  -- device is not configured, set the according connection alert
  if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', conn_alerts = { 'not_configured' } })
    return
  end

-- device is not connected, set the according connection alert
  if not client then
    enapter.send_telemetry({ status = 'conn_error', conn_alerts = { 'communication_failed' } })
    return
  end

  -- read device data
  -- parse it according to device documentation
  -- put parsed data into `telemetry` table under names from manifest
  -- call enapter.send_telemetry(telemetry)
end

function cmd_some_device_command(ctx, args)
  -- use ctx lib for command logs, error responses
  -- check required arguments presence
end

-- other helper functions

```

## Handle device data reading

```lua
  local data, err = <some device client read method>
  if err then
    enapter.log('Failed to read data: ' .. err, 'error')
    return { status = 'conn_error', conn_alerts = { 'communication_failed' }, alerts = {} }
  end
```

## Handle device commands

```lua
function cmd_some_device_command(ctx, args)
  if not args.arg_name then
    ctx.error('Missing argument: arg_name')
  end

  if not client then
    reconnect()
  end

  if not client then
    ctx.error('Device connection not initialized')
  end

  -- some command logic

  if err then
    ctx.error('Failed: ' .. tostring(err))
  else
    -- telling user how device state has changed
    ctx.log(<some msg>)
  end
end
```

## Function Ordering by Abstraction Level

- Scheduler/command handlers call functions → put them first
- Those functions call other functions → put them next
- Lowest-level utility functions → put them last
- No forward references needed (function calls come after definitions)


## Use conn_alerts along with alerts

When device can send its own alerts/errors/warnings (e.g. there is a dedicated Modbus register for that), it's useful to separate these alerts from device connection issues.

1. `communication_failed` and `not_configured` are always connection issues, so they belong to `conn_alerts` array:

```lua
function send_telemetry()
 if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', conn_alerts = { 'not_configured' } })
    return
  end

  if not client then
    enapter.send_telemetry({ status = 'error', conn_alerts = { 'communication_failed' } })
    return
  end

  -- ....
  -- Example: parse data from signal register
  for _, reg in pairs(INT_REGISTERS) do
    local signals = reg.parser(data[reg.adrr - START_REG + 1] or 0)
    for _, signal in ipairs(signals) do
      table.insert(alerts, signal)
    end
  end

  telemetry.status = 'ok'
  telemetry.alerts = alerts
  telemetry.conn_alerts = conn_alerts

  enapter.send_telemetry(telemetry)
end
```

2. When one of connection alerts is active, `alerts` state is unknown:

```lua
  local data, err := client:read_holdings(conn_cfg.address, 0, 2, 1000)
  if err then
    conn_alerts = { 'communication_failed' }
    alerts = nil
    enapter.log('Failed to read from register 0: '.. err, 'error')
  end
  
  -- some code

  enapter.send_telemetry(
    { 
      status = status,
      conn_alerts = conn_alerts,
      alerts = alerts
    }
  )
```