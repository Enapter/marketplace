-- Bart LAB-DM2 Digital Pressure Gauge
-- Communication: RS232 ASCII protocol
-- Protocol: $<CMD><ID>?<CR> -> $<ID><DATA><CR>
-- Default device ID: "00"

local CR = '\r'

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

  local cl, cl_err = serial.new(conn_cfg.conn_str)
  if not cl then
    enapter.log('connect: client creation failed: ' .. cl_err, 'error')
    return
  end
  client = cl
end

function send_properties()
  enapter.send_properties({ vendor = 'Bart', model = 'LAB-DM2' })
end

function send_telemetry()
  if not conn_cfg then
    enapter.send_telemetry({ status = 'ok', alerts = { 'not_configured' } })
    return
  end

  if not client then
    enapter.send_telemetry({ status = 'error', alerts = { 'communication_failed' } })
    return
  end

  local value, err = read_measurement()
  if err then
    enapter.log('read measurement: ' .. err, 'error')
    client = nil
    enapter.send_telemetry({ status = 'error', alerts = { 'communication_failed' } })
    return
  end

  enapter.send_telemetry({ status = 'ok', pressure = value })
end

-- Sends a reading command and returns the raw response string (without CR).
-- Command format: $<cmd><device_id>?<CR>
-- e.g. $DA00?<CR>
function send_command(cmd)
  local device_id = conn_cfg.device_id or '00'
  local request = '$' .. cmd .. device_id .. '?' .. CR

  local data, err = client:transaction(function()
    local flush_err = client:flush()
    if flush_err then
      return nil, 'flush: ' .. flush_err
    end
    local write_err = client:write(request)
    if write_err then
      return nil, 'write: ' .. write_err
    end
    return client:read(32, 500)
  end)

  if err then
    return nil, err
  end
  if not data then
    return nil, 'no data received'
  end

  local response = data:match('([^' .. CR .. ']+)')
  if not response then
    return nil, 'empty response'
  end
  if response:sub(1, 1) ~= '$' then
    return nil, 'unexpected response: ' .. response
  end

  return response, nil
end

-- Reads the measurement value from the device.
-- Command: $DA<ID>?<CR>
-- Response: $<ID><sign><6digits><Ndigits><CR>
--   where 6digits = integer part, Ndigits = fractional part (0..5 chars, per decimal point setting)
-- e.g. $00+001234567 -> +1234.567
function read_measurement()
  local response, err = send_command('DA')
  if err then
    return nil, err
  end

  -- Parse: $II S NNNNNN UUU
  -- $II  = $ + 2-char device ID
  -- S    = sign (+ or -)
  -- NNNNNN = 6-digit integer part
  -- UUU  = 0..5 fractional digits (length depends on decimal point position setting)
  local sign, int_part, dec_part = response:match('^%$%w%w([%+%-])(%d%d%d%d%d%d)(%d*)$')
  if not sign then
    return nil, 'parse error: ' .. response
  end

  local value
  if dec_part ~= '' then
    value = tonumber(int_part .. '.' .. dec_part)
  else
    value = tonumber(int_part)
  end

  if sign == '-' then
    value = -value
  end

  return value, nil
end
