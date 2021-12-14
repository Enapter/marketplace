# SMA Sunny Island

This [Enapter Device Blueprint](https://github.com/Enapter/wip-marketplace#blue_book-enapter-device-blueprints) integrates **SMA Sunny Island** battery inverter via [Modbus TCP](https://developers.enapter.com/docs/reference/vucm/modbustcp) implemented on [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).

## Connect to Enapter

- Sign up to Enapter Cloud using [Web](https://cloud.enapter.com/) or mobile app ([iOS](https://apps.apple.com/app/id1388329910), [Android](https://play.google.com/store/apps/details?id=com.enapter&hl=en)).
- Use [Enapter Gateway](https://handbook.enapter.com/software/gateway/2.0.0/setup/) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://handbook.enapter.com/software/software.html#%F0%9F%92%8E-virtual-ucm).
- [Upload](https://developers.enapter.com/docs/tutorial/uploading-blueprint/) this blueprint to Enapter Virtual UCM.
- Use `Configure` command in Enapter mobile app or Web to set up SMA Sunny Island communication parameters:
  - _Modbus IP address_, use either static IP or DHCP reservation. Check your network router manual for configuration instructions.
  - _Modbus Unit ID_, can be found in SMA Web interface. Find out how to configure it in [references](#references).

## References

- [Modbus Unit ID information (page 9)](https://files.sma.de/downloads/EDMx-Modbus-TI-en-15.pdf)
- [User Interface instructions (page 104)](https://files.sma.de/downloads/SI44M-80H-13-BE-en-13.pdf)
