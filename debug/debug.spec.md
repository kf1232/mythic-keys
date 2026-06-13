# debug

## Summary

Developer-only tools: the debug console, cached state dumps, and click-hit tracing. Loaded from `mythic-keys.toc` only; not included in the public `keys.toc` release manifest.

## Namespace

- `Key.Debug.UI` — debug console window
- `Key.Debug.Data` — addon state dump to log
- `Key.Debug.Click` — click-hit tracing for UI layers

## Files

| File | Role |
|------|------|
| `debug-ui.lua` | `/keyf debug` console, log subscription, open hooks |
| `debug-data.lua` | `/keyf dump` — caches, sync payloads, group summary |
| `click-debug.lua` | `/keyf clickdebug` — rewires frames to log mouse targets |

## Depends on (TOC order)

- `Log.lua`, `cache/cache.lua`, `keystones/`, `ready-check/`, `party-sync/`, `ui/ui.lua`
- Loaded only in `mythic-keys.toc` (after `Core.lua` in dev manifest)

## Public API

- **UI:** `ShowConsole()`, `ClearLog()`, `DumpData()`, `IsShown()`
- **Data:** `DumpToLog()`, `GetGroupSummary()`
- **Click:** `Toggle()`, `Enable()`, `Disable()`, `RewireAll()`, `IsEnabled()`

## Triggers

None registered; invoked via `/keyf` slash commands in `Core.lua`.

## Output / Actions

- **Debug console** — scrollable log window (`/keyf debug`) with Clear, Dump, and Select All
- **State dump** — writes group caches (keystones, bests, ready, sync payloads) into the log
- **Click tracing** — logs which UI layer received mouse events when click debug is enabled
- **Module snapshots** — Dump triggers minimap, teleport bar, party complete, and consumable diagnostics

## Logging

- **Code:** `DBUG` (console and data dump), `CLIK` (click tracing)
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.DEBUG, status, payload, { source = "FunctionName" })`
- **Example lines:**
  - `[12:34:56] DBUG/ShowConsole (info) Debug console opened.`
  - `[12:34:56] DBUG/DumpToLog (info) --- Key data dump ---`
  - `[12:34:56] CLIK/teleport.slot1.shell (debug) [click] teleport.slot1.shell — mouse down (LeftButton)`
