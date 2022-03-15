function main()
    local err = rs232.init(2400, 8, "N", 1)
    if err ~= 0 then
        enapter.log('RS232 init failed: '..rs232.err_to_str(err), 'error')
        enapter.send_telemetry({ status = 'error', alerts = {'init_error'}})
        return
    end

    scheduler.add(30000, send_properties)
    scheduler.add(10000, get_main_metrics)
    scheduler.add(1000, send_telemetry)

    enapter.register_command_handler("set_output_priority", command_set_output_priority)
    enapter.register_command_handler("set_charger_priority", command_set_charger_priority)
end

function send_properties()
    local telemetry = {}
    local result, data = MPPT.run_command_with_cache("QPIRI")
    if result then
        telemetry["model"] = string.sub(data, 28, 31) .. "VA"
    else
        enapter.log("Can not get device model", 'error')
    end
    local result, data = MPPT.run_command_with_cache("QID")
    if result then
        telemetry["serial_num"] = data
    else
        enapter.log("Can not get device serial number", 'error')
    end
    local result, data = MPPT.run_command_with_cache("QVFW")
    if result then
        telemetry["fw_ver"] = data
    else
        enapter.log("Can not get device firmware version", 'error')
    end
    local result, data = MPPT.run_command_with_cache("QPI")
    if result then
        telemetry["protocol_ver"] = data
    else
        enapter.log("Can not get device protocol version", 'error')
    end

    telemetry["connection_scheme"] = get_connection_scheme()

    enapter.send_properties(telemetry)
end

-- throw an alert / connection error status after reading telemetry
function get_main_metrics()
    local r0 = get_battery_voltage()
    local r1 = get_battery_capacity()
    local r2 = get_output_priority()
    local r3 = get_charger_priority()

    if not (r0 and r1 and r2 and r3) then
        enapter.log("Failed to get metrics for rules", "error")
    end

    rules()
end

function send_telemetry()
    local telemetry = {}
    local error_list = {}
    local mpp_commands = {"QPIRI", "QDI", "QFLAG", "QPIGS", "QMOD", "QPIWS"}

    for _, value in pairs(mpp_commands) do
        local result, data = MPPT.run_command(value)
        if result then
            telemetry[value] = data
        else
            table.insert(error_list, value .. "_error")
        end
    end

    local _, data = get_output_mode()
    if data then
	      telemetry["output_mode"] = data
    end
    local max_parallel_number = get_max_parallel_number()
    if max_parallel_number > 0 then
        for i = 0, max_parallel_number-1 do
            local command = "QPGS" .. i
            local result, data = MPPT.run_command(command)
            if result then
                -- if The parallel num whether exist
                if tonumber(string.sub(data,1,1)) == 1 then
                    telemetry[command] = data
                end
            else
                table.insert(error_list, command .. "_error")
            end
        end
    end

    --telemetry["alerts"] = error_list
    telemetry["alerts_quiries"] = error_list
    enapter.send_telemetry(telemetry)

    collectgarbage()
end

function get_connection_scheme()
    local max_parallel_number = get_max_parallel_number()
    local scheme_table = nil
    if max_parallel_number == 0 then
        local result, data = MPPT.run_command_with_cache("QID")
        local serial_num = nil
        if result then serial_num = data end
        local device_table = {sn=serial_num, out_mode="0"}
        scheme_table = {}
        scheme_table["0"] = device_table
        return scheme_table
    else
        for i = 0, max_parallel_number do
            local command = "QPGS" .. i
            local result, data = MPPT.run_command_with_cache(command)
            if result then
            scheme_table = {}
                -- if The parallel num whether exist
                if tonumber(string.sub(data, 1, 1)) == 1 then
                    local sn = string.sub(data, 3, 16)
                    local out_mode = string.sub(data, 109, 109)
                    scheme_table[tostring(i)] = {sn=sn, out_mode=out_mode}
                end
            end
        end
        return scheme_table
    end
end

function set_charger_priority(priority)
    --[[
        Set charger source priority,

        For HS: 00 for utility first, 01 for solar first, 02 for solar and utility, 03 for only solar charging
        --For MS: 00 for utility first, 01 for solar first, 03 for only solar charging
    ]]
    if not (0 <= priority and priority < 4) then
        print("Wrong charger source priority")
        return false
    end

    print("set_charger_priority:" .. priority)
    local result, data = MPPT.run_command("PCP0" .. priority)
    if result then
        if data == "ACK" then
            print("set_charger_priority:" .. priority .. " success")
            return true
        elseif data == "NAK" then
            return false
        else
            print(
                "Charger source priority command has result but it's not ACK or NAK")
            return false
        end
    else
        print("Setting charger source priority was not successful")
        return false
    end
end

function set_output_priority(priority)
    --[[
        Set output source priority
        00 for utility first, 01 for solar first, 02 for SBU priority
    ]]
    if not (0 <= priority and priority < 3) then
        print("Wrong output source priority")
        return false
    end

    print("set_output_priority:" .. priority)
    local result, data = MPPT.run_command("POP0" .. priority)
    if result then
        if data == "ACK" then
            print("set_output_priority:" .. priority .. " success")
            return true
        elseif data == "NAK" then
            return false
        else
            print("Output source priority command has result but it's not ACK or NAK")
            return false
        end
    else
        print("Setting output source priority was not successful")
        return false
    end
end

function get_charger_priority()
    local result, priority = MPPT.run_qpiri_com(18)
    if result then
        return true, tonumber(priority)
    else
        print("Charger source priority was not successful")
        return false
    end
end

function get_max_parallel_number()
    local result, data = MPPT.run_command_with_cache("QPIRI")
    if result then
        local qpiri_list = split(data, " ")
        local parallel_number = qpiri_list[19]
        if parallel_number ~= "-" then
            return tonumber(parallel_number)
        end
    end

    return 0
end

function get_battery_capacity()
    local result, capacity = MPPT.run_qpigs_com(11)
    if result then
        return true, tonumber(capacity)
    else
        print("Battery capacity was not successful")
        return false
    end
end

function get_output_priority()
    local result, priority = MPPT.run_qpiri_com(17)
    if result then
        return true, tonumber(priority)
    else
        print("Output source priority was not successful")
        return false
    end
end

MA_VOLTAGE_PERIOD = 10
MA_VOLTAGE_TABLE = {}

function add_voltage_to_table(voltage)
    if #MA_VOLTAGE_TABLE == MA_VOLTAGE_PERIOD then
        table.remove(MA_VOLTAGE_TABLE, 1)
    end
    print("Adding voltage " .. tostring(voltage) .. " to table")
    MA_VOLTAGE_TABLE[#MA_VOLTAGE_TABLE + 1] = voltage
    print(table.unpack(MA_VOLTAGE_TABLE))
end

function get_ma_voltage()
    local function sum(a, ...)
        if a then return a+sum(...) else return 0 end
    end
    return sum(table.unpack(MA_VOLTAGE_TABLE))/#MA_VOLTAGE_TABLE
end

function get_battery_voltage()
    local result, voltage = MPPT.run_qpigs_com(9)
    if result then
        add_voltage_to_table(tonumber(voltage))
        return true, get_ma_voltage()
    else
        MA_VOLTAGE_TABLE = {}
        print("Battery voltage was not successful")
        return false
    end
end

MPPT = {}

function MPPT.run_command(name)
    local function crc16(pck)
        local index
        local crc = 0
        local da
        local t_da
        local crc_ta = { 0x0000, 0x1021, 0x2042, 0x3063,
             0x4084, 0x50a5, 0x60c6, 0x70e7,
             0x8108, 0x9129, 0xa14a, 0xb16b,
             0xc18c, 0xd1ad, 0xe1ce, 0xf1ef }

        for i = 1, #pck do
            t_da = crc >> 8
            da = t_da >> 4
            crc = (crc << 4) & 0xFFFF
            index = (da ~ (string.byte(pck, i) >> 4)) + 1
            crc = crc ~ crc_ta[index]
            t_da = crc >> 8
            da = t_da >> 4
            crc = (crc << 4) & 0xFFFF
            index = (da ~ (string.byte(pck, i) & 0x0F) & 0xFFFF) + 1
            crc = crc ~ crc_ta[index]
        end

        local b_crc_low = crc & 0xFF
        local b_crc_high = (crc >> 8) & 0xFF

        if b_crc_low == 0x28 or b_crc_low == 0x0D or b_crc_low == 0x0A then
            b_crc_low = b_crc_low + 1
        end
        if b_crc_high == 0x28 or b_crc_high == 0x0D or b_crc_high == 0x0A then
            b_crc_high = b_crc_high + 1
        end

        crc = (b_crc_high & 0xFFFF) << 8
        crc = crc + b_crc_low

        return crc
    end

    local bytes = name
    local crc = crc16(bytes)
    bytes = bytes .. string.char((crc & 0xFF00) >> 8)
    bytes = bytes .. string.char(crc & 0x00FF)
    bytes = bytes .. string.char(0x0D)
    enapter.log("REQUEST "..name..string.byte(string.sub(bytes, -2, -2))..string.byte(string.sub(bytes, -1)))
    rs232.send(bytes)
    local raw_data, result = rs232.receive(2000)
    enapter.log("COMMAND RESPONSE: "..rs232.err_to_str(result))
    if raw_data and string.byte(raw_data, #raw_data) == 0x0d then
        local data = string.sub(raw_data, 1, -4)
        local r_crc = crc16(data)
        if (r_crc & 0xFF00) >> 8 == string.byte(raw_data, -3) and r_crc & 0x00FF == string.byte(raw_data, -2) then
            local com_response = string.sub(data, 2)
            MPPT.add_command_data_to_cache(name, com_response, os.time())
            return true, com_response
        end
    end
    return false
end

COMMAND_CACHE = {}

function MPPT.add_command_data_to_cache(command_name, data, updated)
    COMMAND_CACHE[command_name] = {data=data, updated=updated}
end

function MPPT.get_command_data_from_cache(command_name)
    if COMMAND_CACHE[command_name] then
        return true, COMMAND_CACHE[command_name].data
    end
    return false
end

function MPPT.need_rerun_command(command_name)
    local com_data = COMMAND_CACHE[command_name]
    if com_data == nil then
        return true
    end
    if com_data.updated + 60 < os.time() then
        return true
    end
    return false
end

function MPPT.run_command_with_cache(name)
    if MPPT.need_rerun_command(name) then
        local result, data = MPPT.run_command(name)
        if result then
            MPPT.add_command_data_to_cache(name, data, os.time())
            return true, data
        end
    else
        local result, data = MPPT.get_command_data_from_cache(name)
        if result then
            return true, data
        end
    end
    return false
end

function MPPT.run_qpigs_com(index)
    --[[
        Device general status parameters inquiry
        qpigs_str:
            BBB.B CC.C DDD.D EE.E FFFF GGGG HHH III JJ.JJ KKK OOO TTTT EEEE UUU.U WW.WW PPPPP b7b6b5b4b3b2b1b0

        JJ.JJ (index 9)  - Battery voltage J is an Integer ranging from 0 to 9. The units is V.
        OOO   (index 11) - Battery capacity X is an Integer ranging from 0 to 9. The units is %.
    ]]
    local qpigs_data_len = 17
    if not (0 < index and index < qpigs_data_len + 1) then
        print("QPIGS wrong index")
        return false
    end

    local result, data = MPPT.run_command("QPIGS")
    -- print("QPIGS data: " .. data)
    if result then
        local qpigs_list = split(data, " ")
        return true, qpigs_list[index]
    else
        print("QPIGS command was not successful")
        return false
    end
end

function MPPT.run_qpiri_com(index)
    --[[
        Device Rating Information inquiry
        qpiri_str man
            BBB.B CC.C DDD.D EE.E FF.F HHHH IIII JJ.J KK.K JJ.J KK.K LL.L O PP QQ0 O P Q R SS T U VV.V W X

        P (index 17) - Output source priority
            0: Utility first, 1: Solar first, 2: SBU first
        Q (index 18) - Charger source priority
            For HS Series 0: Utility first, 1: Solar first, 2: Solar + Utility, 3: Only solar charging permitted
        R (index 19) - Parallel max number
            "-" for 3K inverter (single only), 9 for 4K/5K
    ]]
    local qpiri_data_len = 25
    if not (0 < index and index < qpiri_data_len + 1) then
        print("QPIRI wrong index")
        return false
    end

    local result, data = MPPT.run_command("QPIRI")
    -- print("QPIRI data: " .. data)
    if result then
        local qpiri_list = split(data, " ")
        return true, qpiri_list[index]
    else
        print("QPIRI command was not successful")
        return false
    end
end

function split(str, sep)
    if sep == nil then
        sep = "%s"
    end

    local t = {}
    for part in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, part)
    end

    return t
end

function command_set_output_priority(ctx, args)
    local output_priority_table = {
          utility_first = 0,
          solar_first = 1,
          sbu_first = 2
    }

    if args["priority"] then
        if not set_output_priority(output_priority_table[args["priority"]]) then
	          ctx.error("Invalid response from device")
        end
    else
        ctx.error("No arguments")
    end
end

function command_set_charger_priority(ctx, args)
    local charger_priority_table = {
          utility_first = 0,
          solar_first = 1,
          solar_and_utility = 2,
          only_solar = 3
    }

    if args["priority"] then
        if not set_charger_priority(charger_priority_table[args["priority"]]) then
	          ctx.error("Invalid response from device")
	      end
    else
        ctx.error("No arguments")
    end
end

-- For 4K/5K
function get_output_mode()
    --[[
        Get output mode (For 4000/5000)
        Computer: QOPM<CRC><cr>
        Inverter: (nn<CRC><cr>
        nn:
        00: single machine output
        01: parallel output
        02: Phase 1 of 3 Phase output
        03: Phase 2 of 3 Phase output
        04: Phase 3 of 3 Phase output
    ]]
    local result, data = MPPT.run_command_with_cache("QOPM")
    if result then
        return true, tonumber(data)
    else
        print("QOPM command was not successful")
        return false, nil
    end
end

local time = {}

function time.timestamp_to_day_sec(timestamp)
    local sec_in_day = 86400
    return timestamp - math.floor(timestamp / sec_in_day) * sec_in_day
end

function time.stime_to_sec(str)
    -- expected "hh:mm" str format
    local pattern = "(%d+):(%d+)"
    local hours, minutes = string.match(str, pattern)
    return math.floor((hours*3600) + (minutes*60))
end

-- [timestamp_start, timestamp_end] = offset
-- TRANSITION_TABLE = {
--     [{1301187600, 1319936400}] = 7200,
--     [{1319936400, 1332637200}] = 3600
-- }
function time.get_offset_by_timestamp(timestamp)
    -- NEED TABLE or TIMESONE_OFFSET
    local TIMEZONE_OFFSET = 10800 -- 3 hour

    if TIMEZONE_OFFSET then return TIMEZONE_OFFSET end

    --[[for range, offset in pairs(TRANSITION_TABLE) do
        if range[1] <= timestamp and timestamp <= range[2] then
            return offset
        end
    end]]

    error("failed to get offset for current timestamp: " .. tostring(timestamp))
end

function time.is_in_range(start, tail)
    -- expected:
    --    START and TAIL as string: "hh:mm"
    local start_sec = time.stime_to_sec(start)
    local tail_sec = time.stime_to_sec(tail)

    local timestamp = os.time()
    local offset = time.get_offset_by_timestamp(timestamp)
    print("offset for rule time: " .. tostring(offset))

    local now_sec = time.timestamp_to_day_sec(timestamp + offset)
    return is_in_range(start_sec, tail_sec, now_sec)
end

function is_in_range(start, tail, x)
    -- return true if X is in the range [start; tail]
    if start <= tail then
        return start <= x and x <= tail
    else
        return start <= x or x <= tail
    end
end

function rules()
    return
end

main()
