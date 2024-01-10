# InfraSensing Temperature & Humidity sensor ENV-THUM

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates two **InfraSensing ENV-THUM** RH sensors connected to [InfraSensing SensorGateway](https://go.enapter.com/infrasensing-sensorgateway) using LAN port. They communicate with [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm) via [Modbus TCP](https://go.enapter.com/developers-modbustcp).

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use the `Configure` command in the Enapter mobile or Web app to set up the device communication parameters:
  - IP address (default - `192.168.11.160`)
  - Modbus Unit ID (default - `1`)

## References

- [Temperature & Humidity Sensor product page](https://go.enapter.com/infrasensing-env-thum)
- [Infrasensing SensorGateway: How it works video](https://go.enapter.com/infrasensing-sensorgateway-video)
- [Modbus TCP manual](https://go.enapter.com/infrasensing-modbus-manual)
