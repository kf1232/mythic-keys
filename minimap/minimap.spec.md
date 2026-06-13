# minimap

## Summary

Quick access to the party panel from the World Map minimap. Provides a draggable button whose position is saved between sessions; left click opens the party list, right click opens the debug console when that module is loaded.

## Output / Actions

- **Minimap button** — Key icon orbiting the minimap with standard tracking-border styling
- **Open party list** — left click toggles the main Key window (`/keyf`)
- **Open debug console** — right click opens `/keyf debug` when the debug module is present
- **Drag to reposition** — button moves around the minimap edge; angle persists in saved variables
- **Tooltip** — hover text describing click actions

## Logging

- **Code:** `MINI`
- **Write API:** `KeyLog:WriteEvent(KeyLog.FEATURE.MINIMAP, status, payload, { source = "FunctionName" })`
- **Module helper:** `minimap-logging.lua` (`Log`, `LogClick`, `LogSnapshot`, …)
- **Example line:** `[12:34:56] MINI/LogClick (debug) click LeftButton -> toggle party list`
