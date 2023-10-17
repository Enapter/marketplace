local mpp_solar = require('mpp_solar')

local WATCHPOWER_RULES = 'wp_rules'

local rules = { rules = {}, tz_offsets = {} }

function rules:set(r, tz_offsets)
  local storage_rules = build_storage_rules(r)
  local storage_tz_offsets = build_storage_tz_offsets(tz_offsets)

  local ret = storage.write(WATCHPOWER_RULES, storage_rules .. ';' .. storage_tz_offsets)
  if ret and ret ~= 0 then
    return 'cannot write rules into storage: ' .. storage.err_to_str(ret)
  end

  rules.rules = r
  rules.tz_offsets = tz_offsets
end

function rules:load()
  local storage_value, err = storage_read(WATCHPOWER_RULES)
  if err then
    return 'cannot read rules from storage: ' .. err
  end

  if not storage_value then
    return
  end

  local r, tz_offsets
  for storage_rules, storage_tz_offsets in storage_value:gmatch('(.*);(.*)') do
    if r ~= nil then
      return 'rules from storage are in invalid format'
    end

    r, err = parse_storage_rules(storage_rules)
    if err then
      return 'cannot parse rules from storage: ' .. err
    end

    tz_offsets, err = parse_storage_tz_offsets(storage_tz_offsets)
    if err then
      return 'cannot parse tz_offsets from storage: ' .. err
    end
  end

  rules.rules = r
  rules.tz_offsets = tz_offsets
end

function storage_read(name)
  local v, ret = storage.read(name)
  if ret and ret ~= 0 then
    local err = storage.err_to_str(ret)
    -- FIXME: InternalError is because of a bug in UCM v1.2.1,
    -- should be removed after bug is fixed.
    if err == 'NotFound' or err == 'InternalError' then
      return
    end
    return nil, 'cannot read rules from storage: ' .. err
  end
  return v, nil
end

function build_storage_rules(rr)
  local str = ''
  for i, r in ipairs(rr) do
    if i > 1 then
      str = str .. ' '
    end
    str = str
      .. r.cmd
      .. '|'
      .. tostr_or_empty(r.condition.voltage_min)
      .. '|'
      .. tostr_or_empty(r.condition.voltage_max)
      .. '|'
      .. tostr_or_empty(r.condition.time_min)
      .. '|'
      .. tostr_or_empty(r.condition.time_max)
  end
  return str
end

function tostr_or_empty(v)
  if v ~= nil then
    return tostring(v)
  end
  return ''
end

function parse_storage_rules(storage_rules)
  local r = {}
  for cmd, v_min, v_max, t_min, t_max in
    storage_rules:gmatch('(%w*)|([%d%.]*)|([%d%.]*)|([%d:]*)|([%d:]*)')
  do
    table.insert(r, {
      cmd = cmd,
      condition = {
        voltage_min = tonumber(v_min),
        voltage_max = tonumber(v_max),
        time_min = str_or_nil(t_min),
        time_max = str_or_nil(t_max),
      },
    })
  end
  return r
end

function str_or_nil(s)
  if s == '' then
    return nil
  end
  return s
end

function build_storage_tz_offsets(tz_offsets)
  local str = ''
  for i, to in ipairs(tz_offsets) do
    if i > 1 then
      str = str .. ' '
    end
    str = str .. to.from .. '|' .. to.offset
  end
  return str
end

function parse_storage_tz_offsets(storage_to)
  local tz_offsets = {}
  for from, offset in storage_to:gmatch('([%d%.]+)|([%d%.]+)') do
    table.insert(tz_offsets, { from = tonumber(from), offset = tonumber(offset) })
  end
  return tz_offsets
end

function rules:execute()
  local voltage, err = mpp_solar:get_battery_voltage()
  if err then
    enapter.log('failed to read values for rule execution: ' .. err, 'warning')
  end

  for i, r in ipairs(rules.rules) do
    if rules:check_condition(r.condition, voltage, rules.tz_offsets) then
      mpp_solar:set_value(r.cmd)
      enapter.log('rule #' .. i .. ' is applied')
    end
  end
end

function rules:check_condition(condition, voltage, tz_offsets)
  if condition.time_min and condition.time_max then
    if not is_time_in_range(condition.time_min, condition.time_max, tz_offsets) then
      return false
    end
  end

  if condition.voltage_min and voltage > condition.voltage_min then
    return true
  end

  if condition.voltage_max and voltage < condition.voltage_max then
    return true
  end

  return false
end

function is_time_in_range(start, tail, tz_offsets)
  local start_sec = stime_to_sec(start)
  local tail_sec = stime_to_sec(tail)
  local timestamp = os.time()
  local offset = get_offset_by_timestamp(timestamp, tz_offsets)
  local now_sec = timestamp_to_day_sec(timestamp + offset)
  return is_in_range(start_sec, tail_sec, now_sec)
end

function stime_to_sec(str)
  --[[ expected "hh:mm" str format ]]
  local pattern = '(%d+):(%d+)'
  local hours, minutes = string.match(str, pattern)
  return math.floor((hours * 3600) + (minutes * 60))
end

function get_offset_by_timestamp(timestamp, tz_offsets)
  local offset = 0
  for _, t in ipairs(tz_offsets) do
    if timestamp < t.from then
      return offset
    end
    offset = t.offset
  end

  return offset
end

function timestamp_to_day_sec(timestamp)
  local sec_in_day = 86400
  return timestamp - math.floor(timestamp / sec_in_day) * sec_in_day
end

function is_in_range(start, tail, x)
  --[[ return true if X is in the range [start; tail] ]]
  if start <= tail then
    return start <= x and x <= tail
  else
    return start <= x or x <= tail
  end
end

return rules
