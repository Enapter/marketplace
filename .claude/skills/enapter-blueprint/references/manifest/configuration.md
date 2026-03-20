# Device Configuration

After years of writing Enapter Blueprints, we decided to stop forcing users to write the boilerplate code for the configuration interface in Lua scripts and added a new feature to the manifest. All you have to do is declare configuration parameters in dedicated group(s).

## Best Practices for Configuration

1. Set `access_level` thoughtfully — control who can modify which settings to prevent accidental or unauthorized changes.
2. Use `default` values sparingly — only set a default when the value makes sense for most users or devices.
3. Group related settings — use multiple configuration groups to organize settings logically and improve usability.

## Configuration Use Cases

### Connection Parameters

[Connection URI](/docs/interacting-with-hardware#connection-uri), device [Modbus](https://en.wikipedia.org/wiki/Modbus) address, or unit ID — any parameters required to connect to your device should be included in the `configuration` section.

Tips: use descriptive `display_name` values, set suitable types, use `format: connection_uri` for URIs, mark `required` parameters.

```yaml
configuration:
  connection:
    display_name: Connection
    description: Device connection parameters
    access_level: owner
    parameters:
      address:
        display_name: Modbus Address
        description: Device address in range 1-247
        type: integer
        required: true
      conn_str:
        display_name: Connection String
        description: e.g. port://rs485 or port://rs232
        type: string
        format: connection_uri
        required: true
```

> **Note on `conn_str`**: The description should be a short example URI like `e.g. port://rs485` or `e.g. port://rs232`. Communication parameters (baud rate, data bits, parity, stop bits) are configured directly on the UCM hardware module, **not** in the connection string. Do **not** embed parameters like `?baud=9600&data_bits=8` in the example.

> **Note on device addressing**: Any parameter that uniquely identifies a device on a shared bus (Modbus address, unit ID, serial device ID) must be in the `configuration` section — never hardcoded. This allows users to connect multiple devices of the same model.

### Device-Specific Information

Some device characteristics should be explicitly set by the user. For this purpose, the `configuration` section is also well-suited.

Write clear descriptions to explain the parameters.

#### Functional Settings

```yaml
configuration:
  device_info:
    display_name: Pressure Sensor Properties
    description: To be set by the user
    access_level: user
    parameters:
      calib_slope:
        display_name: Calibration Slope
        description: "`k` in the calibration line equation `Pressure = k * Current + b`"
        type: float
        required: true
      calib_intercept:
        display_name: Calibration Intercept
        description: "`b` in the calibration line equation `Pressure = k * Current + b`"
        type: float
        required: true
```

#### Hardware Settings

```yaml
configuration:
  relay:
    display_name: Relay Settings
    description: Relay channels for power and start
    access_level: owner
    parameters:
      power_relay:
        display_name: Power Contact Channel
        description: The number of a relay channel to which an FC power contact is connected.
        type: integer
        required: true
      start_relay:
        display_name: Start Contact Channel
        description: The number of a relay channel to which an FC start contact is connected.
        type: integer
        required: true
```

#### Third-Party API Credentials

When setting any credentials, use the `sensitive` option to protect confidential data.

```yaml {15}
configuration:
  tasmota:
    display_name: Tasmota Account Settings
    description: Account credentials required to connect to the Tasmota device
    access_level: owner
    parameters:
      username:
        display_name: Tasmota Username
        type: string
        required: true
      password:
        display_name: Tasmota Password
        type: string
        required: true
        sensitive: true
```