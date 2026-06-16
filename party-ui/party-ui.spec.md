# party-ui

## Summary

Main Key window: movable, resizable shell with tabs, refresh control, and layout orchestration. Completions tab pane lives in `completions-pane.lua`; tab content delegates to `party-complete`, `teleport-bar`, and `ready-check`.

## Namespace

- `Key.PartyUI`

## Files

| File | Role |
|------|------|
| `party-ui.lua` | Panel shell, tabs, resize, refresh cooldown |
| `completions-pane.lua` | Completions tab pane, scroll region, teleport bar layering on `Key.PartyUI` |

## Depends on (TOC order)

- `ui/ui.lua`, `keystones/keystones.lua`, `teleport-bar/`, `party-complete/party-complete.lua`, `ready-check/ready-check-ui.lua`
- `completions-pane.lua` loads immediately after `party-ui.lua`

## Public API

- **Panel:** `TogglePanel()`, `EnsureFrame()`, `IsShown()`, `Refresh()`, `RefreshReadyOnly()`
- **Tabs:** `SetActiveTab(tabId)`, `IsReadyTabActive()`
- **Layout:** `GetContentWidth()`, `CollectMembers()` (delegates to `Key.Party`)
- **Completions pane:** `EnsureCompletionsPane(frame)`, `RefreshCompletionsPane(contentWidth, members)`, `GetMemberBlockHeight(memberCount, contentWidth)`

## Triggers

**Dispatches:** `UI_PANEL_OPEN`, `UI_REFRESH_CLICK`, `UI_RESIZE`, `REFRESH_UI` (tab switch)

Refresh policy for inbound triggers lives in `ui-refresh.lua`.

## Output / Actions

- **Party panel** — `/keyf` window with title bar, close, and resize handle
- **Tab switching** — M+ Completions vs Ready Check; resizes to active tab content
- **Refresh button** — cooldown-gated manual sync (`R` / push bests + ready)
- **Layout pass** — computes frame size from teleport bar, bests viewport, or ready table height

## Logging

- **Code:** `PUI` (reserved — shell does not write log events today)
