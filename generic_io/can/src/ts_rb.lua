local ts_rb = {
  head = 1,
  tail = 1,
}

local function append_data(data, value)
  if data == nil then
    return { value }
  end
  table.insert(data, value)
  return data
end

function ts_rb:push_data(ts, data)
  if self.head_ts == nil then
    self.head_ts = ts
    self.head_index = 1
  end

  local ts_index = ts - self.head_ts
  local push_into_past = ts_index < 0
  if push_into_past then
    return
  end

  if ts >= self.head_ts + self.limit then
    local new_head_ts = ts - self.limit + 1
    self.head_index = self.head_index + new_head_ts - self.head_ts
    if self.head_index > self.limit then
      self.head_index = 1 + (self.head_index - 1) % self.limit
    end
    self.head_ts = new_head_ts
    ts_index = self.limit - 1
  end

  local push_index = ts_index + self.head_index
  if push_index > self.limit then
    push_index = push_index - self.limit
  end

  if not self.data[push_index] then
    self.data[push_index] = { ts = ts, data = { data } }
  elseif self.data[push_index].ts ~= ts then
    self.data[push_index] = { ts = ts, data = { data } }
  else
    self.data[push_index].data = append_data(self.data[push_index].data, data)
  end
end

function ts_rb:get_all_since(ts)
  if self.head_ts == nil then
    return {}
  end

  local index = ts - self.head_ts
  if index < 0 then
    ts = self.head_ts
    index = 0
  end

  if index > self.limit then
    return {}
  end

  local count = self.limit - index
  index = index + self.head_index

  local data_seen = {}
  local data = {}
  for i = 0, count - 1 do
    local vv = self.data[1 + (index + i - 1) % self.limit]
    if vv and vv.ts == ts + i then
      for _, v in ipairs(vv.data) do
        if not data_seen[v] then
          data_seen[v] = true
          data = append_data(data, v)
        end
      end
    end
  end

  return data
end

return {
  new = function(limit)
    local o = { limit = limit, data = {} }
    setmetatable(o, { __index = ts_rb })
    return o
  end,
}
