# Enapter Blueprint Lua Script Skill Reference

Use this skill when writing/rewriting Enapter Blueprint Lua script.

## Overview

Lua Script implements logic of a third-party device, that is being integrated into Enapter EMS (Cloud, Gateway).
Enapter Lua API is based on Lua programming language version 5.3.

## Core Concepts

- in **most** cases one Lua file is preferable.
- Lua file must be named `main.lua`
- in case of connection with device use `reconnect` pattern.
- functions must be ordered from the highest level first, followed by the lower-level helpers.

## Reading Order

1. Check [api.md](./api.md) for Lua API reference
2. See [patterns.md](./patterns.md) for preferable coding patterns
3. Read [style.md](./style.md) for Lua style guide
4. Read [gotchas.md](./gotchas.md) for troubleshooting

