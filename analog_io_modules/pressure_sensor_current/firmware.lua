local config = require('enapter.ucm.config')

-- Configuration variables must be also defined
-- in `write_configuration` command arguments in manifest.yml
CALIB_SLOPE_CONFIG = 'calib_slope'
CALIB_INTERCEPT_CONFIG = 'calib_intercept'

-- Initiate device firmware. Called at the end of the file.
function main()
  scheduler.add(1000, send_telemetry)

  config.init({
    [CALIB_SLOPE_CONFIG] = { type = 'number', required = true },
    [CALIB_INTERCEPT_CONFIG] = { type = 'number', required = true },
  })
end

function send_telemetry()
  local telemetry = { status = 'ok', alerts = {} }

  local current = ai4.read_milliamps(1)
  telemetry.adc_current = current

  local values, err = config.read_all()
  if err then
    enapter.log('cannot read config: ' .. tostring(err), 'error')
    telemetry.status = 'error'
    telemetry.alerts = { 'cannot_read_config' }
  else
    local slope, intercept = values[CALIB_SLOPE_CONFIG], values[CALIB_INTERCEPT_CONFIG]
    if not slope or not intercept then
      telemetry.alerts = { 'not_configured' }
    else
      telemetry.pressure = current * slope + intercept
    end
  end

  enapter.send_telemetry(telemetry)
end

main()
