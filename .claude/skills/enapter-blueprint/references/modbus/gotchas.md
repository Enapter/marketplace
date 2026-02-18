# Modbus Troubleshooting

## Read/write queries should not exceed execution timeout

All functions in Enapter Lua script have execution timeout 5000 ms, so any Modbus request must not take longer.
