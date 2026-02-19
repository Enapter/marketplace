# Enapter Profiles Reference

Source: https://github.com/Enapter/profiles

## What Are Profiles?

Profiles are standardized device interface contracts. Implementing a profile signals to the Enapter Cloud that a blueprint exposes a well-known set of telemetry/properties under standardized field names, enabling cross-device features (dashboards, comparisons, integrations).

## When to Implement a Profile

Implement a profile when integrating a device that fits a standard device category (power meter, inverter, battery, sensor). Do NOT implement a profile if the device is non-standard or niche — define all telemetry/properties directly in the manifest instead.

## How to Add a Profile to a Manifest

Use the `implements` field in `manifest.yml`. The identifier maps from file path by replacing `/` with `.` and dropping the `.yml` extension:

```
energy/power_meter/ac/3_phase.yml  →  energy.power_meter.ac.3_phase
energy/hybrid_inverter/1_phase.yml →  energy.hybrid_inverter.1_phase
sensor/ambient_temperature.yml     →  sensor.ambient_temperature
```

Example manifest snippet:

```yaml
blueprint_spec: device/3.0
display_name: My Power Meter

implements:
  - energy.power_meter.ac.3_phase

telemetry:
  status:
    type: string
    display_name: Connection Status
    enum:
      ok:
        display_name: OK
        color: green
  # Fields from the profile still need to be declared here
  ac_frequency:
    type: float
    unit: Hz
    display_name: AC Frequency
  ac_l1_voltage:
    type: float
    unit: V
    display_name: L1 Voltage
  # ... (all fields from implemented libs)
```

> **Important**: Implementing a profile does NOT automatically inject telemetry/property fields into the manifest. You must still declare them explicitly in `telemetry:` and `properties:`. The profile declaration is a semantic contract, not a template substitution.

## Profile vs. Lib Components

- **Device profiles** (`energy/`, `sensor/`): Pre-composed combinations for common device types. Use these as-is.
- **Lib components** (`lib/`): Granular building blocks. Mix and match only if the device doesn't fit any device profile, or if you need additional optional lib components beyond a device profile.

## Catalog

See [catalog.md](./catalog.md) for the full list of available device profiles and lib components with their telemetry/property fields.

## Updating the Catalog

Run the update script to regenerate `catalog.md` from the latest GitHub data:

```bash
.claude/skills/enapter-blueprint/scripts/update_profiles.py
```
