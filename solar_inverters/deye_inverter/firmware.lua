-- Serial communication parameters
BAUDRATE = 9600
DATA_BITS = 8
PARITY = 'N'
STOP_BITS = 1
ADDRESS = 1

local deye_modbus

function main()
  local result = rs232.init(BAUDRATE, DATA_BITS, PARITY, STOP_BITS)
  if result ~= 0 then
    enapter.log("RS232 failed: "..result.." "..rs232.err_to_str(result), "error", true)
    enapter.send_telemetry({status = "error", alerts = {"init_error"}})
    return
  end

  deye_modbus = DeyeModbus.new(ADDRESS)
  scheduler.add(30000, send_properties)
  scheduler.add(5000, send_telemetry)
end

function send_properties()
  enapter.send_properties({
    vendor = "Deye",
    -- serial_number = serial_number
  })
end

function send_telemetry()
  local telemetry = {}
  local alerts = {}
  local status = "ok"

  for name, info in pairs(HOLDING_REGISTERS) do
    local data, err = deye_modbus:read_holdings(info.addr, info.factor)
    if data then
      telemetry[name] = data
    else
      enapter.log('Register ' .. info.addr .. ' failed: ' .. err, 'error')
    end
  end

  if #telemetry == 0 then
    alerts = {'communication_failed'}
    status = 'no_data'
  end

  telemetry['alerts'] = alerts
  telemetry['status'] = status

  enapter.send_telemetry(telemetry)
end

-- function slice(tbl, first, last, step)
--   local sliced = {}

--   for i = first or 1, last or #tbl, step or 1 do
--     sliced[#sliced+1] = tbl[i]
--   end

--   return sliced
-- end

-- function tofloat(registers)
--   local raw_str
--   local ok, err = pcall(function()
--     raw_str = string.pack("BBBB", registers[1]>>8, registers[1]&0xff, registers[2]>>8, registers[2]&0xff)
--   end)
--   if not ok then
--     enapter.log("Converting of registers to float value failed: "..err)
--     return nil
--   end
--   return string.unpack(">f", raw_str)
-- end

-- function toint32(registers)
--   local raw_str
--   local ok, err = pcall(function()
--     raw_str = string.pack("BBBB", registers[1]>>8, registers[1]&0xff, registers[2]>>8, registers[2]&0xff)
--   end)
--   if not ok then
--     enapter.log("Converting of registers to float value failed: "..err)
--     return nil
--   end
--   return string.unpack(">I2", raw_str)
-- end

---------------------
-- Deye Modbus API --
---------------------

DeyeModbus = {}

function DeyeModbus.new(modbus_address)
  assert(type(modbus_address) == 'number', 'modbus_address (arg #5) must be number, given: '..type(modbus_address))

  local self = setmetatable({}, { __index = DeyeModbus })
  self.modbus_adress = modbus_address
  return self
end

function DeyeModbus:read_holdings(register, factor, fn)
  local TIMEOUT = 1000
  local COUNT = 1
  local data, err = modbus.read_holdings(ADDRESS, register, COUNT, TIMEOUT)
  if data then
    if fn then
      return fn(data * factor)
    else
      return data * factor
    end
  else
    return nil, modbus.err_to_str(err)
  end
end

HOLDING_REGISTERS = {
  -- address = {
  --   addr = 40000,
  --   factor = 1
  -- },
  total_battery_charge = {
    addr = 514,
    factor = 0.1
  },
  total_battery_discharge = {
    addr = 515,
    factor = 0.1
  },
  day_gridbuy_power = {
    addr = 520,
    factor = 0.1
  -- },
  -- day_gridsell_power = {
  --   addr = 521,
  --   factor = 0.1
  -- },
  -- day_load_power = {
  --   addr = 526,
  --   factor = 0.1
  -- },
  -- battery_voltage = {
  --   addr = 587,
  --   factor = 0.01
  -- },
  -- battery_output_power = {
  --   addr = 590,
  --   factor = 1
  -- },
  -- battery_output_current = {
  --   addr = 591,
  --   factor = 1
  -- },
  -- inner_grid_power_a = {
  --   addr = 604,
  --   factor = 1
  -- },
  -- inner_grid_power_b = {
  --   addr = 605,
  --   factor = 1
  -- },
  -- inner_grid_power_c = {
  --   addr = 606,
  --   factor = 1
  -- },
  -- total_active_power_side_to_side = {
  --   addr = 607,
  --   factor = 1
  -- },
  -- grid_frequency = {
  --   addr = 609,
  --   factor = 1
  -- },
  -- out_of_grid_power_a = {
  --   addr = 616,
  --   factor = 1
  -- },
  -- out_of_grid_power_b = {
  --   addr = 617,
  --   factor = 1
  -- },
  -- out_of_grid_power_c = {
  --   addr = 618,
  --   factor = 1
  -- },
  -- total_out_of_grid_power = {
  --   addr = 619,
  --   factor = 1
  -- },
  -- grid_power_a = {
  --   addr = 622,
  --   factor = 1
  -- },
  -- grid_power_b = {
  --   addr = 623,
  --   factor = 1
  -- },
  -- grid_power_c = {
  --   addr = 624,
  --   factor = 1
  -- },
  -- total_grid_power = {
  --   addr = 625,
  --   factor = 1
  -- },
  -- inverter_output_power_a = {
  --   addr = 633,
  --   factor = 1
  -- },
  -- inverter_output_power_b = {
  --   addr = 634,
  --   factor = 1
  -- },
  -- inverter_output_power_c = {
  --   addr = 635,
  --   factor = 1
  -- },
  -- total_inverter_output_power = {
  --   addr = 636,
  --   factor = 1
  -- },
  -- load_power_a = {
  --   addr = 650,
  --   factor = 1
  -- },
  -- load_power_b = {
  --   addr = 651,
  --   factor = 1
  -- },
  -- load_power_c = {
  --   addr = 652,
  --   factor = 1
  -- },
  -- total_load_power = {
  --   addr = 653,
  --   factor = 1
  -- },
}

main()
