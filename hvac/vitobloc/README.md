# Viessmann Vitobloc 200

This Enapter Device Blueprint integrates Viessmann Vitobloc 200/300 - combined heat and power units for natural gas and LPG operation via Modbus TCP implemented on [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).

## Connect to Enapter

- Sign up to the Enapter Cloud using the Web or mobile app (iOS, Android).
- You will need to set up this device via Vitogate, more info can be found here [here](https://go.enapter.com/vitogate_300) and [here](https://go.enapter.com/vitogate_product_info).
- Use [Enapter Gateway](https://go.enapter.com/handbook-gateway-setup) to run Virtual UCM.
- Create [Enapter Virtual UCM](https://go.enapter.com/handbook-vucm).
- [Upload](https://go.enapter.com/developers-upload-blueprint) this blueprint to Enapter Virtual UCM.
- Use the `Set Up Connection` command in the Enapter mobile or Web app to set up the Viessmann Vitobloc 200 communication parameters:
  - _Modbus IP address_, use either static IP or DHCP reservation. Check your network router manual for configuration instructions.
  - _Modbus Unit ID_, can be found ___.

## References

- [Viessmann Vitobloc 200 product page](https://go.enapter.com/vitobloc_product_range)
- [Viessmann Vitobloc 200 Modbus documentation, DE](https://go.enapter.com/vitobloc_modbus)
- [Viessmann Vitobloc 200 operating instructions, EN](https://go.enapter.com/vitobloc_instructions)
