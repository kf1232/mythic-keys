# minimap

## Summary

Quick access to the party panel from the World Map minimap. Provides a draggable button whose position is saved between sessions; left click opens the party list, right click opens the debug console when that module is loaded.

## Namespace

- `Key.Minimap` — button frame and init
- `Key.MinimapLog` — dev logging helper (dev TOC only)

## Files

| File | Role |
|------|------|
| `minimap-button.lua` | Draggable minimap button, saved angle in `KeyDB.minimap` |
| `minimap-logging.lua` | Click/drag/snapshot logging (dev only) |

## Depends on (TOC order)

- `api-access/minimap.lua`, `party-ui/party-ui.lua`, `ui/ui.lua`

## Public API

- **Minimap:** `Init()`, `CreateButton()`, `button`

## Triggers

**Registers:** `ADDON_LOADED` — create minimap button

## Output / Actions

- **Minimap button** — Key icon orbiting the minimap with standard tracking-border styling
- **Open party list** — left click toggles the main Key window (`/keyf`)
- **Open debug console** — right click opens `/keyf debug` when the debug module is present
- **Drag to reposition** — button moves around the minimap edge; angle persists in saved variables
- **Tooltip** — hover text describing click actions

## Logging

- **Code:** `MINI`
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.MINIMAP, status, payload, { source = "FunctionName" })`
- **Module helper:** `minimap-logging.lua` (`Log`, `LogClick`, `LogSnapshot`, …)
- **Example line:** `[12:34:56] MINI/LogClick (debug) click LeftButton -> toggle party list`
