# Enapter Blueprint README Reference

README file gives a quick device overview, which should help user:
- identify the vendor and model(s) of the device(s) that this blueprint can integrate.
- understand the main purpose of the device
- find links to Enapter Developers Documentation.

The file also used to generate the blueprint page on [Enapter Blueprint Marketplace](https://marketplace.enapter.com/), for [example](https://marketplace.enapter.com/device/komfovent-ping2/komfovent_ping2).

## README template

```markdown
# <Device vendor(s)> <Device model(s)>

<Brief and clear device description to understand its purpose, main features and used communication protocol(s)>

## Connect to Enapter EMS
 
### Prerequisites
- You should have an [access to Enapter EMS](https://go.enapter.com/how-to-use-enapter-ems).
- You should have a Lua Runtime:
  - On the Gateway, you already have a Virtual UCM. You can also use a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).
  - In the Cloud you need a [Hardware UCM](https://go.enapter.com/how-to-provision-ucm).
 
### Steps
- Only for devices with Modbus, CAN or other hardware interfaces:
    - Wire your endpoint device with Enapter ENP module or Enapter Gateway PC.
    - Configure [hardware ports](https://go.enapter.com/hardware-ports).
- [Create Lua Device](https://go.enapter.com/how-to-create-lua-device).
- Check the new Lua Device, [configure](https://go.enapter.com/how-to-configure-devices) them if needed.

## References

<One or several links to the device's official product page, documentation, particularly to communication references> 
```

## Workflow

1. Identify the device vendor(s) and model(s).
2. Get device's description from the official website, datasheet or developer.
3. Get at least one reference
4. Use all this information to write the README file.

