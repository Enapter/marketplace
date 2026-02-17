# H2SYS ACS 1000

The H2SYS ACS 1000 is an air-cooled hydrogen fuel cell system designed to provide reliable DC power from hydrogen gas. It communicates over CAN bus at 500 kbps.

## Connect to Enapter EMS

### Prerequisites

- You should have an [access to Enapter EMS](https://go.enapter.com/how-to-use-enapter-ems).
- You should have a Lua Runtime:
  - On Gateway you already have a Virtual UCM, also you can use a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).
  - In Cloud you need a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).

### Steps

- Wire the H2SYS ACS 1000 CAN bus interface to the Enapter ENP module or Enapter Gateway PC.
- Configure [hardware ports](https://go.enapter.com/hardware-ports).
- [Create Lua Device](https://go.enapter.com/how-to-create-lua-device).
- Check the new Lua Device, [configure](https://go.enapter.com/how-to-configure-devices) the CAN connection string (e.g. `port://can-1`).

## References

- [H2SYS Website](https://www.h2sys.fr)
