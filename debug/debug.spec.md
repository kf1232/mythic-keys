# debug

## Summary

Developer-only tools: the debug console, cached state dumps, and click-hit tracing. Loaded from `mythic-keys.toc` only; not included in the public `keys.toc` release manifest.

## Output / Actions

- **Debug console** — scrollable log window (`/keyf debug`) with Clear, Dump, and Select All
- **State dump** — writes group caches (keystones, bests, ready, sync payloads) into the log
- **Click tracing** — logs which UI layer received mouse events when click debug is enabled
- **Module snapshots** — Dump triggers minimap, teleport bar, party complete, and consumable diagnostics

## Logging

- **Code:** `DBUG` (console and data dump), `CLIK` (click tracing)
- **Write API:** `KeyLog:WriteEvent(KeyLog.FEATURE.DEBUG, status, payload, { source = "FunctionName" })`
- **Module helpers:** `debug-ui.lua`, `debug-data.lua`, `click-debug.lua`
- **Example lines:**
  - `[12:34:56] DBUG/ShowConsole (info) Debug console opened.`
  - `[12:34:56] DBUG/DumpToLog (info) --- Key data dump ---`
  - `[12:34:56] CLIK/teleport.slot1.shell (debug) [click] teleport.slot1.shell — mouse down (LeftButton)`
