# Manifest Reference

## Blueprint Metadata

Every manifest has several lop-level fields which describe the blueprint itself.

```yaml
blueprint_spec: device/3.0

display_name: H2 Sensor
description: Integrates H2 sensor over Modbus using ENP-RS485.
icon: enapter-gauge
vendor: sma

license: MIT
author: enapter
contributors:
  - anataty
  - nikitug
support:
  url: "https://enapter.com/support"
  email: "support@enapter.com"
```

<YamlKey required title="blueprint_spec" id="blueprint_spec">

The version of the blueprint specification. This reference describes version `device/3.0`. The `device/1.0` is described [here](https://developers.enapter.com/reference/blueprint/manifest).

</YamlKey>

<YamlKey required title="display_name" id="display_name">

The name of your blueprint. Usually it's equal to the name of the device which you are integrating.

</YamlKey>

<YamlKey title="description" id="description">

The details about the device integration. May contain most important information about physical connections, device versions, etc. It will be shown next to the blueprint name on some screens in the UI.

</YamlKey>

<YamlKey title="implements" id="implements">

The list of Enapter profiles which this blueprint implements. [Available profiles](https://github.com/Enapter/profiles) are published on GitHub.

</YamlKey>

<YamlKey title="category" id="category">

The category of the device. It is used to group devices in the Cloud UI. The list of available categories:
* hydrogen-storage
* electrolysers
* solar-generators
* fuel-cells
* water-treatment
* battery-systems
* power-meters
* hvac
* electric-vehicles
* control
* data-providers
* sensors

</YamlKey>

<YamlKey title="icon" id="icon">

The icon to be used for the device in the UI. Must be either one from the [community list of icons](https://static.enapter.com/rn/icons/material-community.html) or [Enapter icon set](https://handbook.enapter.com/icons.html) (prepend an icon name with `enapter-`).

</YamlKey>

<YamlKey title="license" id="license">

The license type. You may [use any license](https://choosealicense.com/) you want. [MIT](https://choosealicense.com/licenses/mit/) is usually a good choice.

</YamlKey>

<YamlKey title="author" id="author">

The name of the blueprint author. Should be a valid GitHub username.

</YamlKey>

<YamlKey title="contributors" id="contributors">

A list of developers who contributed to this blueprint. Items should be valid GitHub usernames.

</YamlKey>

<YamlKey title="support" id="support">

The contact information. Contains a web address and an email of a responsible person or organisation able to provide help with this blueprint.

</YamlKey>

## Runtime

Every device integration defined in the blueprint should be run something. Top-level `runtime` section describes how to run this device.

```yaml
runtime:
  type: lua
  requirements:
    - modbus
  options:
    file: main.lua
```

<YamlKey required title="type" id="runtime-time">

The type of the runtime which is used to run the device integration.
- `lua` — the device required a runtime to run Lua scripts.
- `embeded` — the device is work bye themself, used by standalone devices and Enapter's hardware (UCM, electrolyser etc).

</YamlKey>

<YamlKey title="requirements" id="runtime-requirements">

A list of runtime requirements. Each item is a string which describes a requirement. <!-- See [Lua development guide](https://to.do) for the list of available requirements and its meanings.-->

</YamlKey>

### Options
`options` key in the `runtime` section is a map whose keys are describe type-specific options. At now only `lua` runtime has options. The following reference describes the options for the `lua` runtime type.

<YamlKey title="file" conflicts="dir" id="runtime-lua-options-file">

Lua script which will be uploaded to the runtime. The file must be placed into the same directory as a `manifest.yml`.

</YamlKey>

<YamlKey title="dir" conflicts="file" id="runtime-lua-options-dir">

The directory with Lua scripts. It must contain `main.lua` file as an entrypoint.

</YamlKey>

<YamlKey title="luarocks" conflicts="rockspec" id="runtime-lua-options-luarocks">

External dependencies list. Each row should be a [Luarocks](https://luarocks.org/) package. We strongly recommend to specify versions for your dependencies to avoid breaking changes. For example, `lua-string ~> 1.2` means "get lua-string package with version >= 1.2 and < 1.3". See [Rockspec dependencies format](https://github.com/luarocks/luarocks/blob/main/docs/rockspec_format.md) to learn more.

</YamlKey>

<YamlKey title="rockspec" conflicts="luarocks" id="runtime-lua-options-rockspec">

[Rockspec](https://github.com/luarocks/luarocks/blob/main/docs/creating_a_rock.md) file which will be used to resolve dependencies.

</YamlKey>

<YamlKey title="allow_dev_luarocks" id="runtime-lua-options-allow_dev_luarocks">

If set to `true` it is allowed to use luarocks dev packages.

</YamlKey>

<YamlKey title="amalg_mode" id="runtime-lua-options-amalg_mode">

Mode to use for amalgamation. The following modes are supported:

- isolate
- nodebug

Specify `isolate` mode if you want to disable smart dependency resolver and amalgamate all provided Lua modules<!-- (see [troubleshooting section for complex Lua scripts](https://to.do))-->:

```yaml
amalg_mode: isolate
```

Specify `nodebug` mode if you want to exclude debug information from amalgamated file<!--  (see [troubleshooting section for complex Lua scripts](https://to.do))-->:

```yaml
amalg_mode: nodebug
```

To specify more than one mode use yaml arrays syntax:

```yaml
amalg_mode:
  - isolate
  - nodebug
```

</YamlKey>


## Properties

Top-level `properties` section is a map whose keys are _property_ names, and values are property definitions.

```yaml
properties:
  serial_number:
    display_name: Serial Number
    description: "1XXXX" are produced in Italy, "2XXXX" – in China.
    type: integer
  model:
    display_name: Device Model
    type: string
    enum:
      - AnySen M12
      - AnySen MP20
```

<YamlKey required title="display_name" id="property-display_name">

Display name which will be shown to the users in the UI.

</YamlKey>

<YamlKey title="description" id="property-description">

The more detailed description about the property. It will be shown next to the property display name on some screens in the UI.

</YamlKey>

<YamlKey required title="type" id="property-type">

Property type declaration, such as `string`, `integer`, etc. If a Lua script will send wrong type for the property, its value will be ignored. See the [types chapter](#type-declarations) below for the details.

</YamlKey>

<YamlKey title="enum" id="property-enum">

Enumeration limits possible property values. If a Lua script sends some value which is not in the enumeration set, the value will be ignored. See the [enums chapter](#enumerations) below for the details.

</YamlKey>

<YamlKey title="unit" id="property-unit">

The unit of measurement which will be used to represent the value on the dashboards and the UI. Only applicable to the numeric types (`integer` and `float`). To learn more about available units and usage examples, see the [units documentation](/docs/units/introduction).

</YamlKey>

<YamlKey title="allow_unit_c" id="property-allow_unit_c">

Allow to use C unit symbol as Coulomb. It's frequently missused for Celsius and this option allows to disable validation warning. More details can be found in the [units documentation](/docs/units/introduction#allow-ambiguous-units).

</YamlKey>

<YamlKey title="allow_unit_f" id="property-allow_unit_f">

Allow to use F unit symbol as Farad. It's frequently missused for Fahrenheit and this option allows to disable validation warning. More details can be found in the [units documentation](/docs/units/introduction#allow-ambiguous-units).

</YamlKey>

<YamlKey title="auto_scale" id="property-auto_scale">

Specifies the units to which the property value can be scaled within the UI. See [units autoscale note](/docs/units/introduction#autoscale) for more details.

```yaml
unit: W
auto_scale: [W, kW, MW]
```

</YamlKey>

<YamlKey title="implements" id="property-implements">

The list of Enapter profiles which this property implements. If property has same name as implmented profile, it is not necessary to specify it. <!-- See [profiles usage guide](http://to.do) for more details.-->

```yaml
implements:
  - energy.inverter.nameplate.inverter_nameplate_capacity
```

</YamlKey>

<YamlKey title="aliases" id="property-aliases">

Extra names which can be used to refer to the same property. Aliases are useful for backward compatibility, when you want to keep the old name of the property but also want to use a new name.

</YamlKey>

<YamlKey title="access_level" id="property-access_level" defval="readonly">

Defines the access level required to read the property value. The access level is a string which can be one of the following:
* readonly
* user
* owner
* installer
* vendor
* system

</YamlKey>

## Telemetry

Top-level `telemetry` section is a map whose keys are _telemetry attribute_ names, and values are telemetry attribute definitions.

```yaml
telemetry:
  voltage:
    display_name: Battery Amperage
    description: The value is read from a shunt.
    type: float
    unit: A
  mode:
    display_name: Run Mode
    type: string
    enum:
      - stopped
      - running
```

<YamlKey required title="display_name" id="telemetry-display_name">

Display name which will be shown to the users in the UI.

</YamlKey>

<YamlKey title="description" id="telemetry-description">

The more detailed description about the telemetry attribute. It will be shown next to the attribute display name on some screens in the UI.

</YamlKey>

<YamlKey required title="type" id="telemetry-type">

Telemetry attribute type declaration, such as `string`, `integer`, etc. If a Lua script will send wrong type for the attribute, its value will be ignored. See the [types chapter](#type-declarations) below for the details.

</YamlKey>

<YamlKey title="json_schema" id="telemetry-json_schema">

JSON schema or path to file with it of telemetry attribute with json type.

</YamlKey>

<YamlKey title="enum" id="telemetry-enum">

Enumeration limits possible telemetry attribute values. If a Lua script sends some value which is not in the enumeration set, the value will be ignored. See the [enums chapter](#enumeration) below for the details.

</YamlKey>

<YamlKey title="unit" id="telemetry-unit">

The unit of measurement which will be used to represent the value on the dashboards and the UI. Only applicable to the numeric types (`integer` and `float`). To learn more about available units and usage examples, see the [units documentation](/docs/units/introduction).

</YamlKey>

<YamlKey title="allow_unit_c" id="telemetry-allow_unit_c">

Allow to use C unit symbol as Coulomb. It's frequently missused for Celsius and this option allows to disable validation warning. More details can be found in the [units documentation](/docs/units/introduction#allow-ambiguous-units).

</YamlKey>

<YamlKey title="allow_unit_f" id="telemetry-allow_unit_f">

Allow to use F unit symbol as Farad. It's frequently missused for Fahrenheit and this option allows to disable validation warning. More details can be found in the [units documentation](/docs/units/introduction#allow-ambiguous-units).

</YamlKey>

<YamlKey title="auto_scale" id="telemetry-auto_scale">

Specifies the units to which the telemetry attrubute value can be scaled within the UI.

```yaml
unit: W
auto_scale: [W, kW, MW]
```

</YamlKey>

<YamlKey title="implements" id="telemetry-implements">

The list of Enapter profiles which this telemetry attribute implements. If the telemetry attribute has same name as implmented profile, it is not necessary to specify it. <!-- See [profiles usage guide](http://to.do) for more details.-->

```yaml
implements:
  - energy.inverter.ac.1_phase.ac_l1_voltage
```

</YamlKey>

<YamlKey title="aliases" id="telemetry-aliases">

Extra names which can be used to refer to the same telemetry attribute. Aliases are useful for backward compatibility, when you want to keep the old name but also want to use a new name.

</YamlKey>

<YamlKey title="access_level" id="telemetry-access_level" defval="readonly">

Defines the access level required to read the telemetry attribute value. The access level is a string which can be one of the following:
* readonly
* user
* owner
* installer
* vendor
* system

</YamlKey>

### Device Status

`status` attribute should only be used to indicate overall device status. This status will be shown next to the device name on some screens.

<div className="row desktop-screenshots">
  <div className="col">
    <img
      src={require('../images/device-status.png')}
      alt="Device status indicator on devices list page"
      className="!w-80"
      />
    Device status indicator on devices list page
  </div>
</div>

It must be `string` with declared `enum` values, otherwise manifest validation will fail. It's also strongly recommended set color for each status. Let's take an example of car engine:

```yaml
telemetry:
  status:
    display_name: Device Status
    type: string
    enum:
      error:
        display_name: Error
        color: red
      fatal:
        display_name: Fatal
        color: red-darker
      expert:
        display_name: Expert
        color: pink-dark
      maintenance:
        display_name: Maintenance
        color: pink-darker
      idle:
        display_name: Idle
        color: green-lighter
      steady:
        display_name: Steady
        color: green
```

#### Recomendation of Colors Usage

We are strongly recommend to use the following colors for the device status. With this approach users will be able to quickly understand the device status of the different implementations.

| Usage | Color name | Statuses example |
|-------|------------|------------------|
| normal operations, idle | green-lighter | idle, OK, powered, operating, online |
| active action | green | steady, charging |
| pre- or post- action | green-dark, green-darker, cyan-dark, cyan-darker | rump up, rump down |
| warning | yellow | warning, overheated, low level |
| error | red | error, gas leakage, fault |
| fatal error | red-darker | fatal error, sensor damaged |
| maintenance | pink-darker | maintenance mode, service mode |

#### Available Colors

<ColorTable />

### Reserved Attributes

`alerts` and `alert_details` attributes are reserved for [alerts](#alerts) integration and should not be declared in the manifest by the user, otherwise validation will fail. Instead `alerts` and `alert_details` attributes is automatically added to every manifest.

## Alerts

Top-level `alerts` section is a map whose keys are _alert_ names, and values are alert definitions.

When any alert is active on a connected device, a Lua script running on the UCM passes that alert names in the `alerts` telemetry attribute. Enapter Cloud then takes alerts metadata (like name and description) from the manifest declaration.

If alert is sent by the UCM, but not declared in the manifest, then it will still be shown to the user with default severity `error`.

```yaml
alerts:
  overcurrent:
    severity: warning
    code: W115
    display_name: High Current
    description: Current is very high, stop some loads to prevent overload shut-off.
```

<YamlKey required title="severity" id="alert-severity">

Alert severity, one of: `error`, `warning`, `info`.

You can use your own meanings for different severity levels. As a general approach try to follow the convention:

- `error` – the device is not operational due to error,
- `warning` – the device is operational but requires user attention,
- `info` – the device may require user attention.

</YamlKey>

<YamlKey title="code" id="alert-code">

Vendor-specific alert code, which may be useful, for example, for checking in the device manual.

</YamlKey>

<YamlKey title="grace_period" id="alert-grace_period">

Period in duration format (1m, 2m30s) when soft fail become hard fail. If empty grace period is equal zero and all alerts are raised as hard. This is useful for failures which are not critical in a short time, but become dangerous after a while.

</YamlKey>

<YamlKey required title="display_name" id="alert-display_name">

Display name which will be shown to the users in the UI.

</YamlKey>

<YamlKey title="description" id="alert-description">

The details about the alert. It may explain alert conditions or suggest a resolution instruction. It will be shown on the alert screen.

</YamlKey>

### Troubleshooting

```yaml
alerts:
  WH_10:
    severity: warning
    display_name: Lost Modbus safety heartbeat communication
    description: Modbus communication between the Electrolyser and the Modbus master device has been lost. Please check that the Ethernet cable is properly installed, the connection is established, and the Modbus master is operational.
    component:
      - Ethernet
      - Modbus TCP
    condition:
      - Heartbeat packet was not received in time
    troubleshooting:
      - Please check that the Ethernet cable is properly installed, the connection is established, and the Modbus master is operational.
```

<YamlKey title="troubleshooting" id="alert-troubleshooting">

Troubleshooting steps to show in UIs.

</YamlKey>

<YamlKey title="telemetry" id="alert-telemetry">

Telemetry attributes that are related to the alert.

</YamlKey>

<YamlKey title="components" id="alert-components">

Device components that are related to the alert.

</YamlKey>

<YamlKey title="conditions" id="alert-conditions">

Conditions which may cause the alert raising.

</YamlKey>

## Commands

Top-level `commands` section is a map whose keys are _command_ names, and values are command definitions.

Command handler must be declared in the UCM Lua script under the same name.

```yaml
commands:
  beep:
    display_name: Beep
    group: checks
    ui:
      icon: alarm-light-outline
      quick_access: true
```

<YamlKey required title="display_name" id="command-display_name">

Display name which will be shown to the users in the UI.

</YamlKey>

<YamlKey title="description" id="command-description">

The details about the command. It will be shown on the command execution screen.

</YamlKey>

<YamlKey required title="group" id="command-group">

Group name, which references the group declared in the [`command_groups`](#command-groups) section.

Every command must be placed into a group. The grouping only affects the user interfaces, and does not affect the logic of the system.

</YamlKey>


<YamlKey title="implements" id="command-implements">

The list of Enapter profiles which this command implements. If command has same name as implmented profile, it is not necessary to specify it. <!-- See [profiles usage guide](http://to.do) for more details.-->

```yaml
implements:
  - lib.device.power.power_on
```

</YamlKey>

<YamlKey title="aliases" id="command-aliases">

Extra names which can be used to refer to the same command. Aliases are useful for backward compatibility, when you want to keep the old name of the command but also want to use a new name.

</YamlKey>

<YamlKey title="access_level" id="command-access_level" defval="user">

Defines the access level required to execute the command. The access level is a string which can be one of the following:
* readonly
* user
* owner
* installer
* vendor
* system

</YamlKey>

<YamlKey title="ui.icon" id="command-icon">

The icon will be shown next to the command name in the UI. Must be one from the [full list of available icons](https://static.enapter.com/rn/icons/material-community.html).

</YamlKey>

<YamlKey title="ui.mobile_quick_access" id="command-mobile_quick_access">

import RemoteSvg from "/docs/images/remote.svg";

Places the command into a quick access list in the Enapter mobile app. Use the remote control button <RemoteSvg className="remote-control-icon" /> on the device screen to trigger the list.

</YamlKey>

### Confirmation

`confirmation` key in the command definition enables a confirmation message upon command execution.

```yaml {4}
commands:
  configure:
    # ...
    confirmation:
      severity: warning
      title: Changing Configuration
      description: Make sure to reboot the device after configuration process is over.
```

<YamlKey required title="severity" id="command-confirmation-severity">

Confirmation severity, one of: `info`, `warning`. Severity only affects the UI of the confirmation message.

</YamlKey>

<YamlKey required title="title" id="command-confirmation-title">

The title of the confirmation message box.

</YamlKey>

<YamlKey title="description" id="command-confirmation-description">

The message body which will be shown to the user upon the command execution.

</YamlKey>

### Arguments {#command-arguments}

`arguments` key in the command definition is a map whose keys are _argument_ names, and values are argument definitions.

Command arguments are asked upon the command execution. The _arguments form_ is generated automatically based on the argument types and expected values. Arguments are then passed to the command handler in the Lua script.

```yaml {4}
commands:
  switch_mode:
    # ...
    arguments:
      mode:
        display_name: Mode to Switch to
        description: Select device operation mode. "charger" mode requires grid connection.
        required: true
        type: string
        enum:
          - inverter
          - charger
          - pass-through
        default: inverter
      voltage:
        display_name: Target Voltage
        type: float
        min: 23.0
        max: 25.5
```

<YamlKey required title="display_name" id="command-argument-display_name">

Display name which will be shown in the arguments form.

</YamlKey>

<YamlKey title="description" id="command-argument-description">

A more detailed description of the argument. It will be shown next to the argument field in the arguments form.

</YamlKey>

<YamlKey title="required" id="command-argument-required">

Defines if the argument is required for command execution. If `required` field is not set, the argument is considered optional by default.

</YamlKey>

<YamlKey required title="type" id="command-argument-type">

Command argument type declaration, such as `string`, `integer`, etc. See the [types chapter](#type-declarations) below for the details.

Type defines which input field will be used for the argument in the arguments form. For example, `integer` type will show numerical keyboard in the mobile application.

</YamlKey>

<YamlKey title="format" id="command-argument-format">

Format of string command argument. It gets some hints to show more convenient UI instead of simple text field.

</YamlKey>

<YamlKey title="json_schema" id="command-argument-json_schema">

JSON schema or path to file with it of command argument with json type.

</YamlKey>

<YamlKey title="sensitive" id="command-argument-sensitive">

Sensitive command arguments will be hidden in command logs to protect sensitive data.

</YamlKey>


<YamlKey title="enum" id="command-argument-enum">

Enumeration limits possible argument values. See the [enums chapter](#enumerations) below for the details.

The values are offered to the user in the arguments form as a select field.

</YamlKey>

<YamlKey title="default" id="command-argument-default">

Defines default value of the argument. It will be used in the arguments form as a default value of an input field.

</YamlKey>

<YamlKey title={['min', 'max']} id="command-argument-minmax">

Validates a passed argument value with minimum and maximum thresholds. It could only be applied to numerical argument types.

Validation happens on the UI side only upon the arguments form submission. If the validation is critical for the proper command functionality, additionally check the argument value in UCM Lua script.

</YamlKey>

### Response {#command-response}
`response` key in the command definition is a map whose keys are _response_ names, and values are success response definitions. This definition is a documentation and not validated by the Enapter Cloud.

```yaml {5}
commands:
    get_status:
        group: status
        display_name: Status
        response:
            live_sessions:
                required: true
                type: integer
            uptime:
                required: true
                type: string
                format: datetime
```

<YamlKey title="required" id="command-response-required">

Defines if the response value will be present in every success reponse.

</YamlKey>

<YamlKey required title="type" id="command-response-type">

Command response field type declaration, such as `string`, `integer`, etc. See the [types chapter](#type-declarations) below for the details.

</YamlKey>

<YamlKey title="format" id="command-response-format">

Format of string command response field. It gets some hints about data representation.

</YamlKey>

<YamlKey title="json_schema" id="command-response-json_schema">

JSON schema for json-type command response value. It can be filename or schema directly.

</YamlKey>

### Values Prepopulation {#command-prepopulation}

Prepopulation mechanism reads the values for the argument form from another command first, then pre-populates it into the form fields, and allows the user to change it before form submission.

The usage of this feature is similar to the [configuration](#configuration), but applies to commands. And commands can have a quick access from the mobile app without going through interfaces to massive settings for changing one simple setting.

```yaml {8}
commands:
  set_production_rate:
    # ...
    populate_values_command: read_production_rate
```

<YamlKey title="populate_values_command" id="command-populate_values_command">

The name of the command which should be used for reading the values for the arguments form pre-population. This "read" command should return a Lua table with the same keys as the arguments in the write command, see the example below.

</YamlKey>

#### Example

We are implementing the `set_production_rate` command which allows user to change the production rate. The `read_production_rate` command returns the current production rate value from the device.

```yaml {8}
commands:
  read_production_rate:
    display_name: Read Configuration
    group: config
  set_production_rate:
    display_name: Write Configuration
    group: config
    populate_values_command: read_production_rate
    arguments:
      voltage_threshold:
        display_name: Voltage Threshold
        type: float
```

The `read_config` command on the UCM should return the corresponding `voltage_threshold` argument value.

```lua
function read_config_command(ctx, args)
  return {
    voltage_threshold = 12.5 -- read actual value
  }
end

enapter.register_command_handler("read_config", read_config_command)
```

:::note Types
The types of the returned values from the Lua script should conform to the types of the arguments declared in the manifest.
:::

### Groups {#command-groups}

Top-level `command_groups` key is a map whose keys are _command group_ names, and values are group definitions.

```yaml
command_groups:
  checks:
    display_name: Checks
```

<YamlKey required title="display_name" id="command-group-display_name">

Display name which will be shown as a heading of the commands group on the commands screen.

</YamlKey>

<YamlKey title="description" id="command-group-description">

A more detailed description of the command group.

</YamlKey>

<YamlKey title="ui.icon" id="command-group-icon">

The icon will be shown next to the command group name in the UI. Must be one from the [full list of available icons](https://static.enapter.com/rn/icons/material-community.html).

</YamlKey>

## Units
Units section describes custom units are used to represent the values of properties and telemetry attributes in a human-readable form. See [units documentation](/docs/units/introduction#custom-units) for more details.

<YamlKey title="symbol" id="units-symbol">
The unit symbol, which will be used to represent the value in the UI.
</YamlKey>

<YamlKey title="display_name" id="units-display_name">
The unit text representation.
</YamlKey>


## Configuration {#configuration}
Top-level `configuration` section describes the configuration parameters which are required for the device to work properly. Configuration splits into buckets, which are used to group configuration parameters into logical groups. See [configuration documentation](/docs/configuration) for more details.

```yaml
configuration:
    network:
      display_name: Network
      description: Network settings for the device.
      parameters:
        uri:
          display_name: Connection URI
          type: connection_uri
          required: true
          description: URI to connect to the device.
        address:
          display_name: Modbus Adress
          type: integer
          default: 1
```

<YamlKey required title="display_name" id="configuration-display_name">

Display name which will be shown to the users in the UI.

</YamlKey>

<YamlKey title="description" id="configuration-description">

The details about the configuration section.

</YamlKey>

<YamlKey title="access_level" id="configuration-access_level" defval="user">

Defines the access level required to read/write the configuration. The access level is a string which can be one of the following:
* readonly
* user
* owner
* installer
* vendor
* system

</YamlKey>

<YamlKey title="ui.icon" id="configuration-icon">

The icon will be shown next to the configuration bucket name in the UI. Must be one from the [full list of available icons](https://static.enapter.com/rn/icons/material-community.html).

</YamlKey>

### Configuration Parameters {#configuration-parameters}
`parameters` key in the configuration bucket is a list of configuration parameters. Each parameter is a map with the following keys.

<YamlKey required title="display_name" id="configuration-parameter-display_name">

Display name which will be shown in the UI.

</YamlKey>

<YamlKey title="required" id="configuration-parameter-required">

Defines if the parameter is required to device properly working.

</YamlKey>

<YamlKey required title="type" id="configuration-parameter-type">

Configuration parameter type declaration, such as `string`, `integer`, etc. See the [types chapter](#type-declarations) below for the details.

Type defines which input field will be used in the UI. For example, `integer` type will show numerical keyboard in the mobile application.

</YamlKey>

<YamlKey title="format" id="configuration-parameter-format">

Format of string configuration parameter. It gets some hints to show more convenient UI instead of simple text field.

</YamlKey>

<YamlKey title="sensitive" id="configuration-parameter-sensitive">

Sensitive configuration parameters will be hidden when get configuration to protect sensitive data.

</YamlKey>

<YamlKey title="default" id="configuration-parameter-default">

Defines default value of the parameter. It will be used in Lua script if parameter is not set.

</YamlKey>

## Type Declarations

Several manifest declarations necessitate type information, including [property](#properties), [telemetry attribute](#telemetry), [command argument](#command-arguments), [command response](#command-response). These declarations are composed of two keys.

<YamlKey required title="type" id="types-type">

Can be `integer`, `float`, `string`, `boolean`, `json`.
- `json` type isnot available for properties.
- if `json` type is used, `json_schema` must be provided.

</YamlKey>

<YamlKey title="enum" id="types-enum">

Enumeration limits possible values and must conform to the declared type. `integer`, `float`, `string` types support enum declaration.

</YamlKey>

## Enumerations

Enumeration can be presented in two forms: only values and with metainfo.


### Only Values Enum
This form is used for simple enumerations, when you need to describe only values:
```yaml
    enum:
      - stopped
      - running
```

### Enum with Metainfo
This form is used for more complex description of enumeration, when you need to specify additional information about each value, such as `display_name`, `description` and `color`.

```yaml
    enum:
      stopped:
        display_name: Stopped
        descripion: The device is stopped and not operational.
        color: green-lighter
      running:
        display_name: Running
        description: The device is running and operational.
        color: green
```

### Enumerations and YAML Types
YAML has numeric, string, and boolean built-in types.

When you use `1` as a value it's an integer, and when you use `"1"` – it's a string.

```yaml
type: integer
enum:
  - 1
  - "2" # error: it's a string, but type must be integer
```

Type coercion between integers and floats is handled automatically.

```yaml
type: float
enum:
  - 1.0
  - 2 # ok: integer will be coerced into float
```

Boolean types can be specified in YAML as `true`, `false`, `yes`, `no` values (note - without quotes), while, for example, `"true"` is a string.

```yaml
type: string
enum:
  - 1 # error: it's an integer, but type must be string
  - no # error: it's a boolean equal to false, use "no" instead
  - "2"
```

