# :blue_book: Enapter Device Blueprints

This is the collection of device blueprints for integration of your energy devices into [Enapter platform](https://developers.enapter.com). Once integrated, you can monitor and control your devices using mobile app or Web dashboards. You can also automate your devices interoperation with Lua scripting.

Walk through [the tutorial](https://developers.enapter.com/docs/) to learn about the blueprint concept and development workflow.

<p align="center"><img height="300" width="auto" src=".assets/intro-light.png#gh-light-mode-only"></p>
<p align="center"><img height="300" width="auto" src=".assets/intro-dark.png#gh-dark-mode-only"></p>

## Quick Overview

Top-level directories represent energy and industrial device types. Each directory contains a number of blueprints for specific device models.

The blueprint is an entity containing all aspects pertaining to device integration. It consists of two files:

- [`manifest.yml`](https://developers.enapter.com/docs/reference) describes your device interfaces (telemetry it sends, commands it executes, alerts it raises),
- `firmware.lua` implements these interfaces on a specific hardware using [Lua](https://www.lua.org) programming language and high-level platform APIs.

There are two types of hardware that can run your blueprint:

- a physical [Enapter UCM](https://handbook.enapter.com/modules/modules.html) that implements communication over [RS-485](https://handbook.enapter.com/modules/ENP-RS485/ENP-RS485.html), [CAN](https://handbook.enapter.com/modules/ENP-CAN/ENP-CAN.html), and other standards,
- a [virtual UCM](https://handbook.enapter.com/software/software.html#💎-virtual-ucm) - a software part of [Enapter Gateway 2.X](https://handbook.enapter.com/software/software.html#📡-enapter-gateway) (runs on Intel-based server) that implements communication over a local network (Ethernet) or by using direct USB connection (serial communication).

Regardless of an underlying hardware, UCM provides a runtime for Lua execution and exposes APIs for [Enapter Cloud connection](https://developers.enapter.com/docs/reference/ucm/enapter) and physical connections and protocols (e.g. [6-channel relay](https://developers.enapter.com/docs/reference/ucm/rl6), [RS-485](https://developers.enapter.com/docs/reference/ucm/rs485) serial communication, [Modbus RTU](https://developers.enapter.com/docs/reference/ucm/modbus), [Modbus TCP](https://developers.enapter.com/docs/reference/vucm/modbustcp), etc).

## How To Use These Blueprints

1. Select a UCM suitable for communicating with your target device.
2. Provision your UCM to Enapter Cloud using the mobile app or run new virtual UCM on Enapter Gateway.
3. Follow one of the options below to upload a blueprint to the UCM.

### Using [Web IDE](https://developers.enapter.com/docs/tutorial/what-you-need#web-ide)

1. Drag-n-drop the blueprint files into the IDE or copy and paste its contents.
2. Press "Select Device" and choose your UCM
3. Press "Upload to" to upload the blueprint.

### Using [Enapter CLI](https://developers.enapter.com/docs/tutorial/what-you-need#command-line-interface)
Write

1. Follow the steps described in [the tutorial](https://developers.enapter.com/docs/tutorial/what-you-need#command-line-interface) to get the CLI tool and your API access token.
2. Switch the current directory to the desired blueprint.
3. Execute the command `enapter-cli devices upload --hardware-id UCMID --blueprint-dir .`. Substitute `UCMID` with your UCM ID. 

After uploading the blueprint, your device data will appear on the device page in Enapter Cloud and Mobile application.

## Blueprints Development

We welcome any contributions when it comes to integrating new devices into the system, whether it's development efforts or testing the blueprints on your hardware.

### Note About Dot-Fields

`manifest.yml` is validated against [the specification](https://cloud.enapter.com/schemas/json-schemas/blueprints/device/v1/schema.json). Though not every aspect of the manifest yet ready to be fixed in the specification. Some in-progress features are backed by YAML fields that start with a dot (e.g. `.cloud`). These fields are not documented and ignored in the manifest validation. When the feature is ready, the field will be moved into the main manifest body, and the blueprints will be updated.

### Writing Blueprint README

Please follow this simple checklist for every blueprint README file:

- Level 1 header should contain vendor and full model or product family.
- Intro paragraph should briefly describe the device.
- Make sure that blueprint's use-case is clear.
- Some blueprints may require physical connection schematics. You can add it as a picture to the README file or as a link to a PDF file. Place the file into the blueprint directory.
- List the hardware needed for the pysical connection. This may be Enapter UCM model, communication interface converter, etc.
- Device pictures and vendor logos are always welcome, but we ask you to respect the author of said pictures and to follow copyright and licencing guidelines.
- References should be given to the device vendor page, manual, API documentation, etc.

### Linters

Blueprint files are validated using [`yamllint`](https://yamllint.readthedocs.io/en/stable/) and [`luacheck`](https://luacheck.readthedocs.io/en/stable/) linters. The configuration can be found in `.yamllint.yml` and `.luacheckrc` files respectively.

Run the linters locally before creating a pull request:

```bash
luacheck .
yamllint .
markdownlint .
```

### Lua Codestyle

- Document with [LDoc](https://stevedonovan.github.io/ldoc/).
- Use 2 spaces for indentation.
- Use `snake_case` for variables and functions.
- Use `CamelCase` for OOP class names.
- Use `UPPER_CASE` for constants. Put top-level constants at the beginning of the file.
- Use `is_` when naming boolean functions, e.g. `is_between()`.
- Use single quotes `'` over double `"` quotes. Use double quotes when string contains single quotes already.
- Use parenthesis in function calls (`local a = myfun('any')`). Though it's ok to omit it for `require` (`local a = require 'rules'`).
- No spaces in concatenation operator (`'some'..var..' ok'`).
- No spaces around function args declaration (`function hello(a, b)`).
- Typecheck in critical places (`assert(type(myvar) == 'string')`).

Some more good parts are available in [LuaRocks style guide](https://github.com/luarocks/lua-style-guide).
