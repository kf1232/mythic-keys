# party-ui

## Summary

Main Key window: movable, resizable shell with tabs, refresh control, and layout orchestration. Delegates tab content to `party-complete`, `teleport-bar`, and `ready-check` modules.

## Namespace

- `Key.PartyUI`

## Files

| File | Role |
|------|------|
| `party-ui.lua` | Panel shell, tabs, resize, refresh cooldown, UI trigger handlers |

## Depends on (TOC order)

- `ui/ui.lua`, `keystones/keystones.lua`, `teleport-bar/`, `party-complete/party-complete-pane.lua`, `ready-check/ready-check-ui.lua`

## Public API

- **Panel:** `TogglePanel()`, `EnsureFrame()`, `IsShown()`, `Refresh()`, `RefreshReadyOnly()`
- **Tabs:** `SetActiveTab(tabId)`, `IsReadyTabActive()`
- **Layout:** `GetContentWidth()`, `CollectMembers()` (delegates to keystones)

## Triggers

**Registers:** (all dispatch `REFRESH_UI` with tab-appropriate context)

- `GROUP_LEFT`, `PLAYER_ENTERING_WORLD`, `KEYSTONE_DATA_CHANGED` — refresh if panel shown
- `PARTY_CHANGED` — immediate refresh when `ctx.immediate`
- `UI_PANEL_OPEN`, `UI_REFRESH_CLICK`, `UI_READY_TOGGLE`, `UI_RESIZE`

**Dispatches:** `UI_PANEL_OPEN`, `UI_REFRESH_CLICK`, `UI_RESIZE`

## Output / Actions

- **Party panel** — `/keyf` window with title bar, close, and resize handle
- **Tab switching** — M+ Completions vs Ready Check; resizes to active tab content
- **Refresh button** — cooldown-gated manual sync (`R` / push bests + ready)
- **Layout pass** — computes frame size from teleport bar, bests viewport, or ready table height

## Logging

- **Code:** `PUI` (reserved — shell does not write log events today)
