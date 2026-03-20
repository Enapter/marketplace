# Serial Patterns & Use Cases

## Usage in `reconnect` pattern

Use it when blueprint should implement device connection logic e.g. read metrics, set device settings, run commands on device.

The surrounding code can be found in [lua-script](../lua-script/patterns.md#reconnect-pattern) reference.

```lua
function reconnect()
  -- the rest of the code listed in ../lua-script/patterns.md

  client, err = serial.new(conn_cfg.conn_str)
  if not client then
    enapter.log('connect: client creation failed: '.. err, 'error')
    return
  end
end
```