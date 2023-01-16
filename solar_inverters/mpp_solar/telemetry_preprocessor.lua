function preprocess_telemetry(telemetry)
    telemetry["ac_out_active_power_total"] = telemetry["ac_out_active_power_1"]+telemetry["ac_out_active_power_2"]+telemetry["ac_out_active_power_3"]
    telemetry["pv_input_power_total"] = telemetry["pv_input_power_1"]+telemetry["pv_input_power_2"]+telemetry["pv_input_power_3"]
    
    return telemetry
end