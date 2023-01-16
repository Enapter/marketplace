local mpp_solar = require("mpp_solar")
local parser = require("parser")

function main()
    local err = rs232.init(mpp_solar.baudrate, mpp_solar.data_bits, mpp_solar.parity, mpp_solar.stop_bits)
    if err ~= 0 then
        enapter.log('RS232 init failed: '..rs232.err_to_str(err), 'error')
        enapter.send_telemetry({ status = 'error', alerts = {'init_error'}})
        return
    end

    scheduler.add(30000, send_properties)
    scheduler.add(1000, send_telemetry)

    enapter.register_command_handler("set_output_priority", command_set_output_priority)
    enapter.register_command_handler("set_charger_priority", command_set_charger_priority)
end

local max_parallel_number = 0

function send_properties()
    local telemetry = {}
  
    max_parallel_number = parser:get_max_parallel_number()

    local result, data = mpp_solar:run_with_cache(MPP.device_rating_info)
    if result then
        telemetry["model"] = string.sub(data, 28, 31) .. "VA"
    else
        enapter.log("Can not get device model", 'error')
    end
    local result, data = mpp_solar:run_with_cache(MPP.firmware_version)
    if result then
        telemetry["fw_ver"] = data
    else
        enapter.log("Can not get device firmware version", 'error')
    end
    local result, data = mpp_solar:run_with_cache(MPP.device_protocol_id)
    if result then
        telemetry["protocol_ver"] = data
    else
        enapter.log("Can not get device protocol version", 'error')
    end

    local scheme = parser:get_connection_scheme(max_parallel_number)
    if max_parallel_number == 0 then
        telemetry["serial_num"] = scheme["0"]["sn"]
        telemetry["output_mode"] = parser:get_output_mode(scheme["0"]["out_mode"])
    elseif max_parallel_number > 0 then
        for num = 1, tonumber(tablelength(scheme)) do
            telemetry["serial_num"..num] = scheme[num]["sn"]
            telemetry["output_mode"..num] = parser:get_output_mode(scheme[num]["out_mode"])
        end
    end

    enapter.send_properties(telemetry)
end

function send_telemetry()


    local rules_available = true

    local data = parser:get_data_list(MPP.device_rating_info)
    if data then
      parser:map_device_rating_info(data)
    else
      rules_available = false
    end

    local data = mpp_solar:run_command(MPP.device_mode)
    if data then
      local status = parser:map_device_mode(data)
      telemetry["status"] = status
    else
      rules_available = false
    end

    local data = mpp_solar:run_command(MPP.device_warning_status)
    if data then
      parser:map_device_warning_status(data)
    end

    if not rules_available then
        table.insert(alerts, "rules_unavailable")
    end

    telemetry["alerts"] = alerts
    enapter.send_telemetry(telemetry)
    telemetry = {}
    alerts = {}

    if max_parallel_number == 0 then
        local data = parser:get_data_list(MPP.device_general_status_params)
        if data then
          parser:map_device_general_status_params(data)
        end
    else
        for num = 1, max_parallel_number do
            local data = parser:get_data_list(MPP.parallel_info..tostring(num))
            if data then
                telemetry = {}
                parser:map_parallel_info(data, tostring(num))
                enapter.send_telemetry(telemetry)
            end
        end
    end

    telemetry = {}

    -- telemetry["alerts"] = alerts
    -- enapter.send_telemetry(telemetry)
    -- telemetry = {}
    -- alerts = {}

    -- collectgarbage()
end

function set_charger_priority(priority)
    if not (0 <= priority and priority < 4) then
        return false, "Invalid priority value"
    end

    local data = mpp_solar:run_command("PCP0" .. priority)
    if data then
        if data == "ACK" then
            return true
        elseif data == "NAK" then
            return false, "Response: NAK"
        else
            return false, "Response neither ACK or NAK"
        end
    else
        return false, "No response from device"
    end
end

function set_output_priority(priority)
    if not (0 <= priority and priority < 3) then
        return false, "Invalid priority value"
    end

    local data = mpp_solar:run_command("POP0" .. priority)
    if data then
        if data == "ACK" then
            return true
        elseif data == "NAK" then
            return false, "Response: NAK"
        else
            return false, "Response neither ACK or NAK"
        end
    else
        return false, "No response from device"
    end
end

function command_set_output_priority(ctx, args)
    local priorities = {}
    priorities["Utility First"] = 0
    priorities["Solar First"] = 1
    priorities["SBU"] = 2

    if args["priority"] then
        local result, err = set_output_priority(priorities[args["priority"]])
        if not result then
	          ctx.error(err)
        end
    else
        ctx.error("No arguments")
    end
end

function command_set_charger_priority(ctx, args)
    local priorities = {}
    priorities["Utility first"] = 0
    priorities["Solar first"] = 1
    priorities["Solar and utility"] = 2
    priorities["Only solar"] = 3

    if args["priority"] then
        local result, err = set_charger_priority(priorities[args["priority"]])
        if not result then
	          ctx.error(err)
	      end
    else
        ctx.error("No arguments")
    end
end

function tablelength(T)
    local count = 0
    for i, v in ipairs(T) do
        count = count + 1
    end
    return count
end

main()
