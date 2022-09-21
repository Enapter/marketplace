-- Default values of serial communication parameters
BAUDRATE = 9600
DATA_BITS = 8
PARITY = 8
STOP_BITS = 1

function main()
    local result = rs232.init(BAUDRATE, DATA_BITS, PARITY, STOP_BITS)
    if result ~= 0 then
        enapter.log("RS232 init failed: "..rs232.err_to_str(result))
        return
    end

    scheduler.add(30000, properties)
    scheduler.add(1000, send_telemetry)
end

function properties()
    enapter.send_properties({ vendor = "Bart", model = "LAB-DMM2" })
end

function send_telemetry()
    local telemetry = {}
    local status = 'ok'
    local alerts = {}

    local request = "p000" .. string.char(0x0D) .. string.char(0x0A)
    local result = rs232.send(request)
    if result ~= 0  then
        enapter.log("Send request failed: "..rs232.err_to_str(result))
        enapter.send_telemetry({ status = 'error', alerts = {'send_failed'} })
        return
    end

    local data, result = rs232.receive(2000)
    if not data then
        enapter.log("No response from device: "..rs232.err_to_str(result))
        enapter.send_telemetry({ status = 'error', alerts = {'no_response'} })
        return
    end

    local pressure = get_pressure(data)
    if pressure ~= nil then
        telemetry.pressure = pressure
    else
        status = 'error'
        table.insert(alerts, 'no_data')
    end

    telemetry.status = status
    telemetry.alerts = alerts
    enapter.send_telemetry(telemetry)
end

function get_pressure(data)
    local pressure = string.match(data, "%p%d+.%d+")
    if pressure then
        return tonumber(pressure)
    end
    return nil
end

main()
