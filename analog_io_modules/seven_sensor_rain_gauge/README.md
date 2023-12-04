# Rain Gauge 3S-RG by Seven Sensor Solutions

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **Rain Gauge sensor** - meteorological sensor created to accurately measure the rainfall - via [ModBus RTU](https://go.enapter.com/developers-enapter-modbus) implemented on [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use the `Configure` command in the Enapter mobile or Web app to set up the device communication parameters:
  - Address;
  - Baudrate;
  - Stop bits;
  - Parity;
  - Serial port

### Default values as stated by the manufacturer

    | Metric    |Value |
    |-----------|------|
    | Address   | 1    |
    | Baudrate  | 9600 |
    | Stop bits | 1    |
    | Parity    | N    |

## References

- [Rain Gauge product page](https://go.enapter.com/rain-gauge)
- [Modbus RTU manual](https://go.enapter.com/rain-gauge-user-manual)
