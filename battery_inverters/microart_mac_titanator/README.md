# MicroArt MAC Titanator

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates **MicroArt MAC (MAP) Titanator** battery inverter / UPS via [HTTP REST API](https://go.enapter.com/developers-enapter-http) implemented on [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).

The inverter exposes its data through the built-in **Malina2** (Raspberry Pi-based) gateway which provides a JSON REST interface over Wi-Fi or Ethernet.

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use `Configure` command in Enapter mobile app or Web to set up communication parameters:
  - _IP Address_ — IP address of the Malina2 gateway. Use either static IP or DHCP reservation. Check your router manual for configuration instructions.

## Requirements

- MicroArt MAC (MAP) Titanator inverter with the Malina2 (Малина2) built-in gateway module.
- The Malina2 gateway must be accessible on the local network (Wi-Fi or Ethernet).
- Enapter Gateway on the same network as the Malina2 gateway.

## References

- [MicroArt MAC Titanator product page](https://microart.ru/product/map-748-tit)
- [MAC Titanator datasheet (Russian)](https://microart.ru/files/products/pasport_mac_titanator_2024.pdf)
- [Malina2 HTTP REST API manual (Russian)](https://microart.ru/files/products/malina2.pdf)
