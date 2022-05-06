function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
  scheduler.add(120000, set_counters)
end

function send_properties()
  enapter.send_properties(
  {
      vendor = 'Enapter',
      model = 'ENP-DI7',
      description ="This is a blueprint for DI7 that's connected to a RL6"
  })
end

function set_counters()
  for id = 1, 7 do
    di7.set_counter (id, 0)
  end
end 

function send_telemetry ()
  local telemetry = {}
  local alerts = {}
  local status = "ok"

  for id = 1, 7 do
    local di_is_closed, err = di7.is_closed(id)
     if di_is_closed == nil then
       status = "error"
       enapter.log("Reading closed di"..id.." failed: "..di7.err_to_st(err))
	     table.insert(alerts, "DI"..id.."_read_closed_failed")
     else
       telemetry["di"..id.."_closed"] = di_is_closed
     end
     local di_is_opened, err = di7.is_opened(id)
     if di_is_opened == nil then
       status = "error"
       enapter.log("Reading open di"..id.." failed: "..di7.err_to_st(err))
	     table.insert(alerts, "DI"..id.."_read_closed_failed")
     else
       telemetry["di"..id.."_opened"] = di_is_opened
     end
     local counter, reset_time, err = di7.read_counter(id)
     if counter == nil then
	     status = "error"
       enapter.log("Reading counter di"..id.." failed: "..di7.err_to_st(err))
	     table.insert(alerts, "DI"..id.."_read_closed_failed")
     else
       telemetry["di"..id.."_counter"] = counter
       telemetry["di"..id.."_reset_time"] = reset_time
     end
  end
  telemetry["status"] = status
  telemetry["alerts"] = alerts
  telemetry["uptime"] = system.uptime()
  enapter.send_telemetry(telemetry)
end

main()
