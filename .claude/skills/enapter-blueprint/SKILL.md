---
name: enapter-blueprint
description: Enapter Blueprint skill covering Lua script, manifest, profiles, publishing to Marketplace. Use for any Enapter Blueprint development task.
references:
  - lua-script
  - manifest
  - profiles
---

# Enapter Blueprint Skill

Consolidated skill for writing Enapter Blueprints. Use decision trees below to find the appropriate information, then load detailed references.

## Workflow

1. Gather information from device's manual/documentation/developer's input
2. Write manifest.yml
3. Write Lua script(s)
4. If publishing to Enapter Marketplace: use `publishing/` reference to meet all requirements


## Quick Decision Trees

### "I need to write Lua script"

```
Need to write Lua script?
├─ General script structure → lua-script/
├─ Device communicates via Modbus protocol → modbus/
├─ Device communicates via serial protocol → serial/
├─ Device communicates via CAN bus protocol → can/
├─ Device has/is relay → relay/
├─ Device has analog inputs → analogin/
├─ Device has analog outputs → analogout/
├─ Device has digital inputs → digitalin/
├─ Device has digital outputs → digitalout/
```

### "I need to write a device manifest file"

```
Need to write manifest?
├─ General manifest structure → manifest/
├─ Device profiles → profiles
```

### "I need to adjust my blueprint to implement Enapter Profiles"

```
Need blueprint to implement profiles?
├─ How to use profiles in manifest → profiles/README.md
├─ Find available profiles and their fields → profiles/catalog.md
```

### "I need to publish my blueprint to Enapter Marketplace"

```
Need to publish blueprint to Enapter Marketplace?
├─ Publishing requirements and device listing → publishing/
```

### "I need to migrate blueprint v1 to version v3"

```
Need to migrate blueprint to v3?
├─ Step-by-step migration guide → migration-to-v3/
```