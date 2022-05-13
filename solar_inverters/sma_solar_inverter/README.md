# SMA Sunny Boy/Tripower

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates the **SMA Sunny Boy/Tripower** solar inverter via [Modbus TCP API](https://go.enapter.com/developers-modbustcp) implemented on the [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm)

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use `Configure` command in Enapter mobile app or Web to set up SMA Sunny Boy/Tripower communication parameters:
  - _Modbus IP address_, use either static IP or DHCP reservation. Check your network router manual for configuration instructions.
  - _Modbus Unit ID_, can be found in SMA Web interface.

## References

- [SMA Sunny Tripower 17000TL-10 data sheet](https://go.enapter.com/sma-sunny-tripower-17000tl10-datasheet)
- [SMA Sunny Tripower 17000TL-10 Modbus Interface](https://go.enapter.com/sma-modbus-zip)
- [SMA Sunny Tripower 17000TL-10 Parameter List](https://go.enapter.com/sma-paramaters-zip)
- [SMA Sunny Tripower 17000TL-10 SunSpec Modbus Interface](https://go.enapter.com/sma-sunspec-modbus-v22-zip)
