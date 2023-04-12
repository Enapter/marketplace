local MA = {}
MA.period = 10
MA.table = {}

function MA:add_to_table(voltage)
  if #MA.table == MA.period then
    table.remove(MA.table, 1)
  end
  MA.table[#MA.table + 1] = voltage
end

function MA:get_value()
  local function sum(a, ...)
    if a then
      return a + sum(...)
    else
      return 0
    end
  end
  return sum(table.unpack(MA.table)) / #MA.table
end

return MA
