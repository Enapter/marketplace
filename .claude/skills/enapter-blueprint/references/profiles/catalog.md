# Enapter Profiles Catalog

Auto-generated from https://github.com/Enapter/profiles
Run `.claude/skills/enapter-blueprint/scripts/update_profiles.py` to refresh.

## Table of Contents

- [Device Profiles](#device-profiles)
  - [Energy Devices](#energy-devices)
  - [Sensors](#sensors)
- [Lib Components](#lib-components)
  - [lib.device](#libdevice)
  - [lib.energy.battery](#libenergybattery)
  - [lib.energy.inverter](#libenergyinverter)
  - [lib.energy.power_meter](#libenergypowermeter)
  - [lib.energy.pv](#libenergypv)
  - [lib.sensor](#libsensor)

---

## Device Profiles

Use these identifiers directly in `implements:` in your manifest.

### Energy Devices

| Identifier | Display Name | Implements (lib components) |
|---|---|---|
| `energy.battery` | Battery/BMS Profile | device.nameplate, battery.electrical, battery.nameplate, battery.soc |
| `energy.battery_inverter.1_phase` | Single-Phase Battery Inverter | device.nameplate, battery.electrical, battery.nameplate, battery.soc, inverter.ac.1_phase, inverter.ac.power, inverter.grid.power, inverter.load.power, inverter.nameplate, inverter.status |
| `energy.battery_inverter.3_phase` | Three-Phase Battery Inverter | device.nameplate, battery.electrical, battery.nameplate, battery.soc, inverter.ac.3_phase, inverter.ac.power, inverter.grid.power, inverter.load.power, inverter.nameplate, inverter.status |
| `energy.hybrid_inverter.1_phase` | Single-Phase Hybrid Inverter | device.nameplate, battery.electrical, battery.nameplate, battery.soc, inverter.ac.1_phase, inverter.ac.power, inverter.grid.power, inverter.load.power, inverter.nameplate, inverter.status, pv.power |
| `energy.hybrid_inverter.3_phase` | Three-Phase Hybrid Inverter | device.nameplate, battery.electrical, battery.nameplate, battery.soc, inverter.ac.3_phase, inverter.ac.power, inverter.grid.power, inverter.load.power, inverter.nameplate, inverter.status, pv.power |
| `energy.power_meter.ac.1_phase` | Single-Phase Power Meter | device.nameplate, power_meter.ac.1_phase, power_meter.total, power_meter.power |
| `energy.power_meter.ac.3_phase` | Three-Phase Power Meter | device.nameplate, power_meter.ac.3_phase, power_meter.total, power_meter.power |
| `energy.pv_charge_controller` | PV Charge Controller | device.nameplate, battery.electrical, battery.nameplate, battery.soc, pv.power |
| `energy.pv_inverter.1_phase` | Single-Phase PV Inverter | device.nameplate, inverter.ac.1_phase, inverter.ac.power, inverter.nameplate, inverter.status, pv.power |
| `energy.pv_inverter.3_phase` | Three-Phase PV Inverter | device.nameplate, inverter.ac.3_phase, inverter.ac.power, inverter.nameplate, inverter.status, pv.power |

### Sensors

| Identifier | Display Name | Implements (lib components) |
|---|---|---|
| `sensor.ambient_temperature` | Ambient Temperature Profile | device.nameplate, sensor.temperature.ambient |
| `sensor.hydrogen` | Hydrogen Concentration Sensor Profile | device.nameplate, sensor.gas.lel |
| `sensor.solar_irradiance` | Solar Irradiance Profile | device.nameplate, sensor.solar_irradiance |

---

## Lib Components

Granular building blocks. Use only when no device profile fits or for extending a device profile.

### lib.device

| Identifier | Display Name | Telemetry / Properties |
|---|---|---|
| `lib.device.nameplate` | Device Nameplate | **properties**: `vendor` (string), `model` (string), `serial_number` (string) |

### lib.energy

| Identifier | Display Name | Telemetry / Properties |
|---|---|---|
| `lib.energy.battery.electrical` | Battery Electrical Measurements | `battery_voltage` (V), `battery_current` (A), `battery_power` (W) |
| `lib.energy.battery.energy` | Battery Energy Statistics | `battery_charged_energy_total` (Wh), `battery_discharged_energy_total` (Wh) |
| `lib.energy.battery.limits` | Battery Charge/Discharge Limits | `battery_max_charge_current` (A), `battery_max_discharge_current` (A) |
| `lib.energy.battery.nameplate` | Battery Nameplate | **properties**: `battery_nameplate_capacity` (float), `battery_type` (enum: lead_based, lithium_based, nickel_based, flow, sodium_based, other) |
| `lib.energy.battery.soc` | Battery State of Charge | `battery_soc` (%) |
| `lib.energy.battery.soh` | Battery State of Health | `battery_soh` (%) |
| `lib.energy.battery.temperature` | Battery Temperature | `battery_temperature` (Cel) |
| `lib.energy.inverter.ac.1_phase` | Single Phase Inverter | `ac_frequency` (Hz), `ac_l1_power` (W), `ac_l1_voltage` (V), `ac_l1_current` (A) |
| `lib.energy.inverter.ac.3_phase` | Three Phase Inverter | `ac_frequency` (Hz), `ac_l1_voltage` (V), `ac_l1_current` (A), `ac_l1_power` (W), `ac_l2_voltage` (V), `ac_l2_current` (A), `ac_l2_power` (W), `ac_l3_voltage` (V), `ac_l3_current` (A), `ac_l3_power` (W) |
| `lib.energy.inverter.ac.current` | Total AC Current | `ac_total_current` (A) |
| `lib.energy.inverter.ac.energy.today` | Inverter Energy Statistics - Today | `ac_energy_today` (Wh) |
| `lib.energy.inverter.ac.energy.total` | Inverter Energy Statistics - Total | `ac_energy_total` (Wh) |
| `lib.energy.inverter.ac.power` | Total AC Power | `ac_total_power` (W) |
| `lib.energy.inverter.grid.charge.enabled` | Grid Charging/Feed-in Configutaion Status | **properties**: `grid_charge_enabled` (boolean), `grid_feed_in_enabled` (boolean) |
| `lib.energy.inverter.grid.mode` | Grid Connection Mode | **properties**: `grid_mode` (enum: grid_tied, off_grid) |
| `lib.energy.inverter.grid.power` | Grid Power | `grid_total_power` (W) |
| `lib.energy.inverter.grid.status` | Grid Connection Status | `grid_status` |
| `lib.energy.inverter.load.power` | Inverter Load Power | `load_total_power` (W) |
| `lib.energy.inverter.nameplate` | Inverter Nameplate Profile | **properties**: `inverter_nameplate_capacity` (integer) |
| `lib.energy.inverter.residual_current` | Inverter Residual Current Profile | `residual_current` (A) |
| `lib.energy.inverter.status` | Inverter Status Profile | `status` |
| `lib.energy.inverter.temperature` | Inverter Temperature Profile | `inverter_heatsink_temperature` (Cel), `inverter_internal_temperature` (Cel) |
| `lib.energy.power_meter.ac.1_phase` | Single-Phase AC Power Meter | `ac_frequency` (Hz), `ac_l1_power` (W), `ac_l1_voltage` (V), `ac_l1_current` (A) |
| `lib.energy.power_meter.ac.3_phase` | Three-Phase AC Power Meter | `ac_frequency` (Hz), `ac_l1_voltage` (V), `ac_l1_current` (A), `ac_l1_power` (W), `ac_l2_voltage` (V), `ac_l2_current` (A), `ac_l2_power` (W), `ac_l3_voltage` (V), `ac_l3_current` (A), `ac_l3_power` (W) |
| `lib.energy.power_meter.current` | Current Measurement | `total_current` (A) |
| `lib.energy.power_meter.energy.today` | Energy Statistics Profile - Today | `energy_today` (Wh) |
| `lib.energy.power_meter.energy.total` | Energy Statistics Profile - Total | `energy_total` (Wh) |
| `lib.energy.power_meter.power` | Power Measurement | `total_power` (W) |
| `lib.energy.power_quality.power_factor.1_phase` | Single-Phase Power Factor Measurement | `ac_l1_power_apparent` (VA), `ac_l1_power_reactive` (VAR), `ac_l1_power_factor` |
| `lib.energy.power_quality.power_factor.3_phase` | Three-Phase Power Factor Measurement | `ac_l1_power_apparent` (VA), `ac_l1_power_reactive` (VAR), `ac_l1_power_factor`, `ac_l2_power_apparent` (VA), `ac_l2_power_reactive` (VAR), `ac_l2_power_factor`, `ac_l3_power_apparent` (VA), `ac_l3_power_reactive` (VAR), `ac_l3_power_factor` |
| `lib.energy.power_quality.power_factor.totals` | Power Factor | `ac_power_factor`, `ac_total_power_apparent` (VA), `ac_total_power_reactive` (VAR) |
| `lib.energy.pv.1_string` | 1-String PV Generation | `pv_s1_voltage` (V), `pv_s1_current` (A), `pv_s1_power` (W) |
| `lib.energy.pv.2_string` | 2-String PV Generation | `pv_s1_voltage` (V), `pv_s1_current` (A), `pv_s1_power` (W), `pv_s2_voltage` (V), `pv_s2_current` (A), `pv_s2_power` (W) |
| `lib.energy.pv.3_string` | 3-String PV Generation | `pv_s1_voltage` (V), `pv_s1_current` (A), `pv_s1_power` (W), `pv_s2_voltage` (V), `pv_s2_current` (A), `pv_s2_power` (W), `pv_s3_voltage` (V), `pv_s3_current` (A), `pv_s3_power` (W) |
| `lib.energy.pv.4_string` | 4-String PV Generation | `pv_s1_voltage` (V), `pv_s1_current` (A), `pv_s1_power` (W), `pv_s2_voltage` (V), `pv_s2_current` (A), `pv_s2_power` (W), `pv_s3_voltage` (V), `pv_s3_current` (A), `pv_s3_power` (W), `pv_s4_voltage` (V), `pv_s4_current` (A), `pv_s4_power` (W) |
| `lib.energy.pv.current` | Total PV Current | `pv_total_current` (A) |
| `lib.energy.pv.power` | Total PV Power Profile | `pv_total_power` (W) |
| `lib.energy.pv.stats.energy.today` | PV Energy Statistics - Today | `pv_energy_today` (Wh) |
| `lib.energy.pv.stats.energy.total` | PV Energy Statistics - Total | `pv_energy_total` (Wh) |
| `lib.energy.pv.throttling` | PV Throttling | `pv_throttled` |

### lib.firmware

| Identifier | Display Name | Telemetry / Properties |
|---|---|---|
| `lib.firmware.version` | Firmware Version Profile | **properties**: `firmware_version` (string) |

### lib.location

| Identifier | Display Name | Telemetry / Properties |
|---|---|---|
| `lib.location.coordinates` | Location Coordinates Profile | **properties**: `latitude` (float), `longitude` (float) |

### lib.sensor

| Identifier | Display Name | Telemetry / Properties |
|---|---|---|
| `lib.sensor.gas.lel` | Gas concentration in %LEL | `gas_lel` (%LEL) |
| `lib.sensor.gas.ppm` | Gas Concentration in ppm | `gas_ppm` ([ppm]) |
| `lib.sensor.solar_irradiance` | Solar Irradiance | `solar_irradiance` (W/m2) |
| `lib.sensor.temperature.ambient` | Ambient Temperature | `ambient_temperature` (Cel) |
