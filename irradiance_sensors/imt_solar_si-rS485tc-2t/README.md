# IMT Solar Si-RS485TC-2T

This _Enapter Device Blueprint_ integrates **IMT Solar Si-RS485TC-2T** - irradiance sensor with [ModBus RTU](https://developers.enapter.com/docs/reference/ucm/modbus) over [RS-485 communication interface](https://developers.enapter.com/docs/reference/ucm/rs485).

Use [Enapter ENP-RS485](https://handbook.enapter.com/modules/ENP-RS485/ENP-RS485.html) module for physical connection. See [connection instructions](https://handbook.enapter.com/modules/ENP-RS485/ENP-RS485.html#connection-example) in the module manual.

## RS-485 Communication Interface Parameters

- Baud rate: `9600` bps;
- Data bits: `8`;
- Parity: `N` (no parity);
- Stop bits: `1`.

## References

- [IMT Solar Si Series data sheet](https://www.imt-solar.com/fileadmin/docs/en/products/Si-Sensor_202108_E.pdf)
- [Description MODBUS protocol for IMT Solar Si-RS485 sensors](https://www.imt-solar.com/fileadmin/docs/en/products/Specification_Si-RS485_MODBUS.pdf)
