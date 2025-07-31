local config = require('enapter.ucm.config')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
CAN_ID = 'can_id'
local CLIENT
local dtl_temperatures = {}
local dtl_relays = {}
local active_alerts = {}

function can_handler(msg_id, data)
  local client, err = get_can_id()
  if not err then
    -- 100 01 ID 80
    if msg_id == ((0x10 << 24) | (0x01 << 16) | (tonumber(client) << 8) | 0x80) then
      local temperature = string.unpack('<i2', string.sub(data, 2, 3)) / 10
      dtl_temperatures['s' .. string.byte(data, 1) + 1] = temperature
      enapter.log('Sensor ' .. tostring(string.byte(data, 1) + 1) .. ': ' .. tostring(temperature) .. '°C')
    end

    -- 100 02 ID 80
    if msg_id == ((0x10 << 24) | (0x02 << 16) | (tonumber(client) << 8) | 0x80) then
      local signal = string.byte(data, 3)
      dtl_relays['r' .. string.byte(data, 1) + 1] = signal
      enapter.log('Relay ' .. tostring(string.byte(data, 1) + 1) .. ': ' .. tostring(signal))
    end
  end
end

function main()
  config.init({
    [CAN_ID] = { type = 'number', required = true },
  })

  -- Init CAN interface
  local result = can.init(250, can_handler)
  if result ~= 0 then
    enapter.log('CAN failed: ' .. result .. ' ' .. can.err_to_str(result), 'error', true)
  end

  -- Send properties every 30s
  scheduler.add(30000, send_properties)

  -- Send telemetry every 1s
  scheduler.add(1000, send_telemetry)
end

function get_can_id()
  if CLIENT then
    return CLIENT, nil
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local client = values[CAN_ID]
    if not client then
      return nil, 'not_configured'
    else
      CLIENT = client
      return CLIENT, nil
    end
  end
end

function send_properties()
  enapter.send_properties({
    vendor = 'SOREL',
    model = 'MTDC',
  })
end

function send_telemetry()
  local telemetry = {}
  local status = 'Starting'

  active_alerts = {}
  local _, err = get_can_id()
  if err then
    active_alerts = { err }
    status = 'Error'
  else
    local pwm = nil
    if dtl_relays['r1'] then
      pwm = dtl_relays['r1']
    end
    if pwm then
      if pwm > 0 then
        status = 'Loading Storage'
        pwm = pwm * 100 / 255
      elseif pwm == 0 then
        status = 'Idle'
      end
    else
      status = 'Waiting Data'
    end

    telemetry.s1 = dtl_temperatures['s1']
    telemetry.s2 = dtl_temperatures['s2']
    if telemetry.s1 and telemetry.s2 then
      telemetry.dt = telemetry.s1 - telemetry.s2
    end
    telemetry.pump = pwm
  end

  telemetry.alerts = active_alerts
  telemetry.status = status

  enapter.send_telemetry(telemetry)
end

main()
