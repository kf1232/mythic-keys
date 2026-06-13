# party-ui

## Summary

Main Key window: movable, resizable shell with tabs, refresh control, and layout orchestration. Delegates tab content to `party-complete`, `teleport-bar`, and `ready-check` modules.

## Output / Actions

- **Party panel** — `/keyf` window with title bar, close, and resize handle
- **Tab switching** — M+ Completions vs Ready Check; resizes to active tab content
- **Refresh button** — cooldown-gated manual sync (`R` / push bests + ready)
- **Layout pass** — computes frame size from teleport bar, bests viewport, or ready table height

## Logging

- **Code:** `PUI` (reserved — shell does not write log events today)
