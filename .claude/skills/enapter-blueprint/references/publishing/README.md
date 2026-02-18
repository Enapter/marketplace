# Enapter Blueprint Publishing Reference

## Main Requirements

A blueprint which should be published on Enapter Blueprint Marketplace must meet the following requirements:

- a valid manifest.yml
- a valid Lua script(s)
- a descriptive and concise README.md describing main features of a device, hints (as links to Enapter Developers Documentation) about how to connect device to Enapter EMS and configure it.
- a new blueprint option in [devices.yml](.marketplace/devices/devices.yml) with `display_name` and `description`.
- the `vendor` field in devices.yml must match an existing vendor `id` in `.marketplace/vendors/vendors.yml`. If the vendor does not exist, add it to vendors.yml first.

## Workflow

1. Device manifest reference → ../lua-script/manifest/
2. Lua script reference → ../lua-script/
3. Enapter Blueprint README reference → how_to_readme.md
4. Add a new blueprint option → devices.md
5. Add suitable profiles to manifest.yml → ../profiles/