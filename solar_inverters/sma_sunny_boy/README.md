# SMA Sunny Boy

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates the **SMA Sunny Boy** solar inverter via [Modbus TCP API](https://go.enapter.com/developers-modbustcp) implemented on the [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).

## Supported SMA Sunny Boy Models

```txt
Sunny Boy 1.5 (SB1.5-1VL-40)
Sunny Boy 1.5 (SB1.5-1VL-40)
Sunny Boy 2.0 (SB2.0-1VL-40)
Sunny Boy 2.0 (SB2.0-1VL-40)
Sunny Boy 2.5 (SB2.5-1VL-40)
Sunny Boy 2.5 (SB2.5-1VL-40)
Sunny Boy 3.0 (SB3.0-1AV-40)
Sunny Boy 3.0 (SB3.0-1AV-41)
Sunny Boy 3.0 (SB3.0-1AV-41)
Sunny Boy 3.0 (SB3.0-1SP-US-40)
Sunny Boy 3.6 (SB3.6-1AV-40)
Sunny Boy 3.6 (SB3.6-1AV-41)
Sunny Boy 3.6 (SB3.6-1AV-41)
Sunny Boy 3.8 (SB3.8-1SP-US-40)
Sunny Boy 4.0 (SB4.0-1AV-40)
Sunny Boy 4.0 (SB4.0-1AV-41)
Sunny Boy 4.0 (SB4.0-1AV-41)
Sunny Boy 5.0 (SB5.0-1AV-40)
Sunny Boy 5.0 (SB5.0-1AV-41)
Sunny Boy 5.0 (SB5.0-1AV-41)
Sunny Boy 5.0 (SB5.0-1SP-US-40)
Sunny Boy 5.5-JP (SB5.5-LV-JP-41)
Sunny Boy 6.0 (SB6.0-1AV-41)
Sunny Boy 6.0 (SB6.0-1AV-41)
Sunny Boy 6.0 (SB6.0-1SP-US-40)
Sunny Boy 7.0 (SB7.0-1SP-US-40)
Sunny Boy 7.7 (SB7.7-1SP-US-40)
```

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Install [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use `Configure` command in Enapter mobile app or Web to set up SMA Sunny Boy communication parameters:
  - _Modbus IP address_, use either static IP or DHCP reservation. Check your network router manual for configuration instructions.
  - _Modbus Unit ID_, can be found in SMA Web interface, default value is `3`.

## References

- [SMA Sunny Boy manuals](https://my.sma-service.com/s/article/Sunny-Boy-Manuals?language=en_US)
- [SMA Sunny Boy Modbus parameters and measured values](https://www.sma.de/en/products/product-features-interfaces/modbus-protocol-interface)
- [SMA Modbus interface](https://files.sma.de/downloads/EDMx-Modbus-TI-en-16.pdf)
