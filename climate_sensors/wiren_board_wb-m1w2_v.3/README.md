# Wiren Board WB-M1W2 v.3 Temperature Measurement Module

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates the **Wiren Board WB-M1W2 v.3 Temperature Measurement Module** — a compact device with a Modbus (RS-485) interface and inputs for connecting DS18B20 temperature sensors via 1-Wire.

The blueprint works with Modbus registers for WB-M1W2 v.3 firmware version 4.6.0 or higher.

## Connect to Enapter

- Sign in to your Energy Management System using the web or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Configure your RS-485 hardware device. Go to **Device Settings → Hardware Ports** and set:
  - Baud rate: 9600 b/s
  - Data bits: 8
  - Stop bits: 2
  - Parity: None
- Create a Lua device with this blueprint on a runtime device that supports the Modbus Lua API.
- Go to the created Lua device **Device Settings → Connection Configuration** and set the following parameters:
  - _Modbus Connection URI_ — defines how to connect to WB-M1W2 v.3 for Modbus communication.
  - _Modbus Unit ID_ — printed on the back of the WB-M1W2 v.3.
  - _Modbus Timeout_ — time after which Modbus commands fail and a connection alert is raised (default: 500 ms).
  - _1-Wire Bus Input_ — select which of the two 1-Wire inputs to use for data reading.

## References

- [Wiren Board WB-M1W2 v.3 Temperature Measurement Module](https://wirenboard.com/en/product/WB-M1W2/).
