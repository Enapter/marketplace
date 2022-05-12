function main()
  scheduler.add(30000, send_properties)
  scheduler.add(1000, send_telemetry)
end

function send_properties()
  enapter.send_properties({ vendor = 'Enapter', model = 'ENP-DI7', description ='Enapter ENP-DI7 with alerts for digital inputs'})
end

function send_telemetry ()
  local telemetry = {}
  local alerts = {}
  local status = "ok"
  for id = 1, 7 do
    local relay_status, err = di7.is_closed(id)
    if relay_status ~= nil then
      telemetry["di"..id.."_closed"] = relay_status
      if relay_status == true then
        table.insert(alerts,"DI"..id.."_closed_alert")
      end
    else
      status = "error"
      enapter.log("Reading closed di"..id.." failed: "..di7.err_to_str(err))
    end
    local counter, reset_time, err = di7.read_counter(id)
    if counter ~= nil then
      telemetry["di"..id.."_counter"] = counter
      telemetry["di"..id.."_reset_time"] = reset_time
    else
      status = "error"
      enapter.log("Reading counter di"..id.." failed: "..di7.err_to_str(err))
    end
  end
  telemetry["status"] = status
  telemetry["alerts"] = alerts
  enapter.send_telemetry(telemetry)
end

main()
