# Bart LAB-DM2

This [Enapter Device Blueprint](https://go.enapter.com/marketplace-readme) integrates the **Bart LAB-DM2** — a digital pressure gauge that communicates via ASCII serial protocol over [RS-232](https://go.enapter.com/developers-enapter-rs232).

## Connect to Enapter EMS

### Prerequisites

- You should have an [access to Enapter EMS](https://go.enapter.com/how-to-use-enapter-ems).
- You should have a Lua Runtime:
  - On Gateway you already have a Virtual UCM, also you can use a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).
  - In Cloud you need a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).

### Steps

- Wire the LAB-DM2 RS-232 port to the Enapter ENP-RS232 module or Enapter Gateway PC.
- Configure [hardware ports](https://go.enapter.com/hardware-ports).
- [Create Lua Device](https://go.enapter.com/how-to-create-lua-device).
- [Configure](https://go.enapter.com/how-to-configure-devices) the Lua Device:
  - **Connection String** — serial port URI, e.g. `port://rs232-1`.
  - **Device ID** — two-character instrument address (default `00`).

## References

- [Bart LAB-DM2 product page](https://go.enapter.com/bart-lab-dm2)
- [Bart LAB-DM2 user manual](https://go.enapter.com/bart-lab-dm2-user-manual)
