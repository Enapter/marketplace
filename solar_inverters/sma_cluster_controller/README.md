# SMA Sunny Tripower

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates the **SMA Sunny Tripower** solar inverter via [Modbus TCP API](https://go.enapter.com/developers-modbustcp) implemented on the [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).

## Supported SMA Sunny Tripower Models

```txt
STP 15000TL-30 (STP 15000TL-30)
STP 17000TL-30 (STP 17000TL-30)
STP 20000TL-30 (STP 20000TL-30)
STP 25000TL-30 (STP 25000TL-30)
STP3.0-3AV-40 (STP3.0-3AV-40)
STP33-US-41 (STP33-US-41)
STP50-40 (STP50-40)
STP50-41 (STP50-41)
STP50-JP-40 (STP50-JP-40)
STP50-JP-41 (STP50-JP-41)
STP50-US-40 (STP50-US-40)
STP50-US-41 (STP50-US-41)
STP62-US-41 (STP62-US-41)
Sunny Tripower 10.0 (STP10.0-3AV-40)
Sunny Tripower 10.0 SE (STP10.0-3SE-40)
Sunny Tripower 4.0 (STP4.0-3AV-40)
Sunny Tripower 5.0 (STP5.0-3AV-40)
Sunny Tripower 5.0 SE (STP5.0-3SE-40)
Sunny Tripower 6.0 (STP6.0-3AV-40)
Sunny Tripower 6.0 SE (STP6.0-3SE-40)
Sunny Tripower 8.0 (STP8.0-3AV-40)
Sunny Tripower 8.0 SE (STP8.0-3SE-40)
```

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Install [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use `Configure` command in Enapter mobile app or Web to set up SMA Sunny Tripower communication parameters:
  - _Modbus IP address_, use either static IP or DHCP reservation. Check your network router manual for configuration instructions.
  - _Modbus Unit ID_, can be found in SMA Web interface, default value is `3`.

## References

- [SMA Sunny Tripower manuals](https://my.sma-service.com/s/article/Sunny-Tripower-Manuals?language=en_US)
- [SMA Sunny Tripower Modbus parameters and measured values](https://www.sma.de/en/products/product-features-interfaces/modbus-protocol-interface)
- [SMA Modbus interface](https://files.sma.de/downloads/EDMx-Modbus-TI-en-16.pdf)
