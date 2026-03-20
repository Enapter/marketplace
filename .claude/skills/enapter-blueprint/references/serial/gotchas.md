# Serial Troubleshooting

## Flush buffer before accessing serial port

```lua
client:flush()
client:read(1024) -- or client:write(some_msg)
```

## Transaction should not exceed execution timeout

All functions in Enapter Lua script have execution timeout 5000 ms, so any serial transaction must not take longer.
