# SMA Sunny Island

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates the **SMA Sunny Island** battery inverter via [Modbus TCP](https://go.enapter.com/developers-modbustcp).

## Supported Models

```txt
Sunny Island 3.0M (SI 3.0M-12)
Sunny Island 4.4M (SI 4.4M-12)
Sunny Island 5.0H (SI5.0H-13)
Sunny Island 6.0H (SI 6.0H-12)
Sunny Island 6.0H (SI6.0H-13)
Sunny Island 8.0H (SI 8.0H-12)
Sunny Island 8.0H (SI8.0H-13)
SI4.4M-13
SI6.0H-11
SI8.0H-11
SI3.0M-11
SI4.4M-11
```

## Connect to Enapter EMS

### Prerequisites

- Access to Enapter EMS
- A Lua Runtime (Virtual UCM on Gateway, or Hardware UCM)

### Steps

- Create a Lua Device in Enapter EMS.
- Go to Configuration and set up the connection parameters:
  - **Modbus Address**: IP address and port of the Sunny Island, e.g. `192.168.14.45:502`. Use either static IP or DHCP reservation.
  - **Modbus Unit ID**: Can be found in the SMA web interface. Default value is `3`.

## References

- [SMA Sunny Island manuals](https://my.sma-service.com/s/article/Sunny-Island-Manuals?language=en_US)
- [SMA Modbus parameters and measured values](https://www.sma.de/en/products/product-features-interfaces/modbus-protocol-interface)
- [SMA Modbus interface](https://files.sma.de/downloads/EDMx-Modbus-TI-en-16.pdf)
