-- MAC Titanator (МАП Титанатор) Battery Inverter
-- Communicates via HTTP REST API provided by the Малина (Raspberry Pi) gateway

local config = require('enapter.ucm.config')
local json = require('json')

local CONFIG_IP = 'ip_address'
local CONFIG_BATTERY_CAPACITY = 'bat_capacity'
local CONFIG_BATTERY_VOLTAGE = 'bat_voltage'
local HTTP_TIMEOUT = 10

-- Operating mode name lookup table
local MODE_NAMES = {
  [0] = 'Off',
  [1] = 'Off Grid Present',
  [2] = 'On Battery',
  [3] = 'On Grid',
  [4] = 'On Grid Charging',
  [10] = 'Forced Generation',
  [11] = 'Tariff Forced Generation',
  [12] = 'Tariff Min',
  [13] = 'Grid Eco',
  [14] = 'Grid Sell',
  [15] = 'Waiting Charge',
  [16] = 'Tariff Grid Eco',
  [17] = 'Tariff Grid Sell',
  [18] = 'Pumping Pmax',
}

-- Cached data from last successful polls
local map_data = {}
local bat_minute = {}
local map_error = 'not_configured'

function main()
  -- config.init() automatically registers write_configuration and
  -- read_configuration commands — do NOT define them manually.
  config.init({
    [CONFIG_IP] = { type = 'string', required = true },
    [CONFIG_BATTERY_CAPACITY] = { type = 'number', required = false },
    [CONFIG_BATTERY_VOLTAGE] = { type = 'string', required = false },
  })

  scheduler.add(30000, send_properties)
  scheduler.add(5000, poll_map)
  scheduler.add(30000, poll_bat)
  scheduler.add(5000, send_telemetry)

  send_properties()
end

function send_properties()
  local props = {
    vendor = 'MicroArt',
    model = 'Titanator 7kW',
  }
  if map_data.fw then
    props.fw = tostring(map_data.fw)
  end
  if map_data._UID then
    props.uid = tostring(map_data._UID)
  end

  local values, err = config.read_all()
  if not err and values then
    if values[CONFIG_BATTERY_CAPACITY] then
      props.battery_capacity = values[CONFIG_BATTERY_CAPACITY]
    end
    if values[CONFIG_BATTERY_VOLTAGE] then
      props.battery_nominal_voltage = tonumber(values[CONFIG_BATTERY_VOLTAGE])
    end
  end

  enapter.send_properties(props)
end

-- Returns the configured IP or nil if not configured / error reading config.
local function get_ip()
  local values, err = config.read_all()
  if err then
    enapter.log('config.read_all error: ' .. tostring(err), 'error')
    return nil
  end
  return values[CONFIG_IP]
end

-- Thin HTTP GET wrapper; returns response, err.
local function http_get(url)
  local client = http.client({ timeout = HTTP_TIMEOUT })
  local request = http.request('GET', url)
  return client:do_request(request)
end

-- Poll /read_json.php?device=map
-- Response contains multiple newline-separated JSON values:
--   line 1 – MAP object
--   line 2 – I2C MPPT controllers array
--   line 3 – BMS cells array
function poll_map()
  local ip = get_ip()
  if not ip then
    map_error = 'not_configured'
    return
  end

  local response, err = http_get('http://' .. ip .. '/read_json.php?device=map')
  if err then
    enapter.log('MAP HTTP error: ' .. tostring(err), 'error', true)
    map_error = 'http_error'
    return
  end
  if response.code ~= 200 then
    enapter.log('MAP HTTP status: ' .. tostring(response.code), 'error', true)
    map_error = 'http_error'
    return
  end

  -- Only the first line contains the MAP object we need.
  local first_line = response.body:match('^([^\n\r]+)')
  if not first_line then
    enapter.log('MAP response has no content', 'error', true)
    map_error = 'http_error'
    return
  end

  local ok, data = pcall(json.decode, first_line)
  if ok and type(data) == 'table' then
    map_data = data
    map_error = nil
  else
    enapter.log('MAP JSON parse error', 'error', true)
    map_error = 'http_error'
  end
end

-- Poll /read_json.php?device=bat
-- Response is a JSON array with two objects:
--   [1] – updated once per minute (capacity, SoC, cycle stats, …)
--   [2] – updated every second   (instantaneous currents, integrals, …)
function poll_bat()
  local ip = get_ip()
  if not ip then
    return
  end

  local response, err = http_get('http://' .. ip .. '/read_json.php?device=bat')
  if err then
    enapter.log('BAT HTTP error: ' .. tostring(err), 'error', true)
    return
  end
  if response.code ~= 200 then
    enapter.log('BAT HTTP status: ' .. tostring(response.code), 'error', true)
    return
  end

  local ok, data = pcall(json.decode, response.body)
  if ok and type(data) == 'table' then
    bat_minute = data[1] or {}
  else
    enapter.log('BAT JSON parse error', 'error', true)
  end
end

-- Safe tonumber: returns nil when v is nil, otherwise tonumber(v).
local function num(v)
  if v == nil then
    return nil
  end
  return tonumber(v)
end

function send_telemetry()
  -- Not configured
  if map_error == 'not_configured' then
    enapter.send_telemetry({ status = 'Not Configured', alerts = { 'not_configured' } })
    return
  end

  -- Connection failed and we have no cached data yet
  if map_error == 'http_error' and next(map_data) == nil then
    enapter.send_telemetry({ status = 'Error', alerts = { 'http_error' } })
    return
  end

  local alerts = {}
  local t = { status = 'Unknown' }

  local mode_num = num(map_data._MODE)
  if mode_num then
    t.status = MODE_NAMES[mode_num] or ('mode_' .. tostring(mode_num))
  end

  t.battery_voltage = num(map_data._Uacc)
  -- Use precise current value (_IAcc_med_A_u16), fall back to coarse (_Iacc)
  t.battery_current = num(map_data._IAcc_med_A_u16) or num(map_data._Iacc)
  -- _P_acc_3ph is the actual battery power (positive = discharging); negate to match
  -- battery_current convention where negative = discharging, positive = charging.
  local p_acc = num(map_data._P_acc_3ph)
  t.battery_power = p_acc and -p_acc or nil
  t.battery_temp = num(map_data._Temp_Grad0)

  -- Battery monitor data (updated once per minute from /device=bat)
  t.battery_soc = num(bat_minute.C_100_remain)
  t.battery_remaining_ah = num(bat_minute.C_Ah_remain)
  t.time_to_go = num(bat_minute.TTG)
  t.solar_power_day = num(bat_minute.mppt_day_E)

  t.grid_voltage = num(map_data._UNET)
  -- Use precise current (_INET_16_4), fall back to coarse (_INET).
  t.grid_current = num(map_data._INET_16_4) or num(map_data._INET)
  t.grid_power = num(map_data._PNET_calc) or num(map_data._PNET)
  t.grid_frequency = num(map_data._TFNET)

  t.output_voltage = num(map_data._UOUTmed)
  t.output_frequency = num(map_data._ThFMAP)
  -- Total power delivered to loads = grid contribution + battery discharge.
  -- grid_power: positive = from grid; battery_power: negative = discharging.
  if t.grid_power and t.battery_power then
    t.output_power = t.grid_power - t.battery_power
  end
  if t.output_power and t.output_voltage and t.output_voltage ~= 0 then
    t.output_current = t.output_power / t.output_voltage
  end

  t.transistor_temp = num(map_data._Temp_Grad2)

  t.mppt_current = num(map_data._I_mppt_avg)
  t.mppt_power = num(map_data._P_mppt_avg)
  t.wind_current = num(map_data._I_MPPT_WIND)
  t.wind_power = num(map_data._P_MPPT_WIND)

  -- Values are stored as integer × 100, divide to get kWh.
  -- _*_B variants include the base accumulated in the gateway on counter wrap.
  local e_net = num(map_data._E_NET_B)
  local e_acc = num(map_data._E_ACC_B)
  local e_charge = num(map_data._E_ACC_CHARGE_B)
  if e_net then
    t.energy_from_grid = e_net / 100
  end
  if e_acc then
    t.energy_from_battery = e_acc / 100
  end
  if e_charge then
    t.energy_to_battery = e_charge / 100
  end

  t.cooler_speed = num(map_data._CoolerSpeed)
  t.relay1 = num(map_data._Relay1)
  t.relay2 = num(map_data._Relay2)

  if map_error == 'http_error' then
    table.insert(alerts, 'http_error')
    t.status = 'Error'
  end

  local f_acc = num(map_data._F_Acc_Over)
  if f_acc and f_acc ~= 0 then
    table.insert(alerts, 'battery_overload')
    t.status = 'error'
  end

  local f_net = num(map_data._F_Net_Over)
  if f_net and f_net ~= 0 then
    table.insert(alerts, 'grid_overload')
    t.status = 'error'
  end

  local rs_err = num(map_data._RSErrSis)
  if rs_err and rs_err ~= 0 then
    table.insert(alerts, 'rs_error')
  end

  local i2c_err = num(map_data._I2C_Err)
  if i2c_err and i2c_err ~= 0 then
    table.insert(alerts, 'i2c_error')
  end

  t.alerts = alerts
  enapter.send_telemetry(t)
end

main()
