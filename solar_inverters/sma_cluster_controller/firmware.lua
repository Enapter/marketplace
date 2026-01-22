local smamodbus = require('enapter.sma.modbustcp')
local config = require('enapter.ucm.config')

ADDRESS_CONFIG = 'address'
UNIT_ID_CONFIG = 'unit_id'

-- global SMA Modbus TCP connection, initialized below
sma = nil

function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_realtime_telemetry)

  config.init({
    [ADDRESS_CONFIG] = { type = 'string', required = true },
    [UNIT_ID_CONFIG] = { type = 'number', required = true }
  })
end

function send_properties()
  local properties = {}

  local sma, _ = connect_sma()
  if sma then
    properties.serial_num = sma:read_u32_fix0(30057)
    properties.fw_ver = parse_firmware_version(sma:read_u32_fix0(30059))
  end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
  else
    for name, val in pairs(values) do
      properties[name] = val
    end
  end

  enapter.send_properties(properties)
end

function send_realtime_telemetry()
  local sma, err = connect_sma()
  if not sma then
    if err == 'cannot_read_config' then
      enapter.send_telemetry({ status = 'error', alerts = {'cannot_read_config'} })
    elseif err == 'not_configured' then
      enapter.send_telemetry({ status = 'warning', alerts = {'not_configured'} })
    end
    return
  end

  local telemetry = {
    active_power = sma:read_s32_fix0(30775),
    reactive_power = sma:read_s32_fix0(30805),
    total_energy = sma:read_u64_fix0(30513),
    energy_fed_today = sma:read_u64_fix0(30517),
    ambient_temp = sma:read_s32_fix1(34609),
    pv_temp = sma:read_s32_fix1(34621),
    external_total_irradiation = sma:read_u32_fix0(34623),
    status = 'ok',
    alerts = {},
  }

  if telemetry.total_energy then
    telemetry.total_energy = telemetry.total_energy / 1000
  end
  if telemetry.energy_fed_today then
    telemetry.energy_fed_today = telemetry.energy_fed_today / 1000
  end

  enapter.send_telemetry(telemetry)
end

function connect_sma()
  if sma then
    return sma, nil end

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: '..tostring(err), 'error')
    return nil, 'cannot_read_config'
  else
    local address, unit_id = values[ADDRESS_CONFIG], values[UNIT_ID_CONFIG]
    if not address or not unit_id then
      return nil, 'not_configured'
    else
      -- Declare global variable to reuse connection between function calls
      sma = smamodbus.new(address, tonumber(unit_id))
      sma:connect()
      return sma, nil
    end
  end
end

function parse_firmware_version(value)
  if not value then return end

  local release_id = value & 0xFF
  local build = (value >> 8) & 0xFF
  local minor = (value >> 16) & 0xFF
  local major = (value >> 24) & 0xFF

  local release
  if release_id == 0 then release = 'N'
  elseif release_id == 1 then release = 'E'
  elseif release_id == 2 then release = 'A'
  elseif release_id == 3 then release = 'B'
  elseif release_id == 4 then release = 'R'
  elseif release_id == 4 then release = 'S'
  else release = tostring(release_id)
  end

  return major..'.'..minor..'.'..build..'.'..release
end

main()
