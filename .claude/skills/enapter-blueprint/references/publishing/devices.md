# Enapter Blueprint Adding Blueprint Option Reference

Every blueprint in Enapter Marketplace requires its own _blueprint option_.

Generate entry in `.marketplace/devices/devices.yml` for blueprint registration.

## Vendor validation

The `vendor` field in the device entry **must** match an existing `id` in `.marketplace/vendors/vendors.yml`. Before adding a device entry:

1. Read `.marketplace/vendors/vendors.yml` and check if the vendor ID already exists.
2. If the vendor ID does NOT exist, add a new vendor entry to `.marketplace/vendors/vendors.yml`:

```yaml
- id: <vendor-id-kebab-case>
  display_name: <Vendor Display Name>
  icon_url: https://raw.githubusercontent.com/Enapter/marketplace/main/.marketplace/vendors/icons/<vendor-id>.png
  website: <vendor website URL>
```

> **CI will fail** if the vendor ID in `devices.yml` is not found in `vendors.yml`.

## Generated entry format

```yaml
- id: <vendor>-<model-kebab-case>
  display_name: <display_name from manifest>
  description: <description from manifest>
  icon: <icon from manifest>
  vendor: <vendor id from .marketplace/vendors/vendors.yml>
  category: <parent directory name>
  blueprint_options:
    - blueprint: <category>/<blueprint_directory>
      display_name: Lua API V3 Version
      description: <description>
      verification_level: ready_for_testing
```

## Example

```yaml
- id: efoy-h2-cabinet-n-series
  display_name: EFOY H2 Cabinet N-Series
  description: Indoor cabinet solutions for EFOY Hydrogen fuel cells
  icon: enapter-fuel-cell
  vendor: efoy
  category: fuel_cells
  blueprint_options:
    - blueprint: fuel_cells/efoy_h2_cabinet_n_series_v3
      display_name: Lua API V3 Version
      description: Indoor cabinet solutions for EFOY Hydrogen fuel cells (Lua API V3)
      verification_level: ready_for_testing
```