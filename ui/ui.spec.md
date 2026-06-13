# ui

## Summary

Shared frame, theme, and widget helpers used across Key panels. Provides consistent backdrops, fonts, tab buttons, title bars, and scroll regions so party UI, debug console, and teleport slots share the same look.

## Namespace

- `Key.UI`

## Files

| File | Role |
|------|------|
| `ui.lua` | Theme tokens, frame factories, tab/close/refresh button helpers |

## Depends on (TOC order)

- `Log.lua` (loads before this file in TOC)

## Public API

- **Theme:** `LAYOUT`, `FONTS`, `BACKDROPS`, `THEME`, `GetTheme()`, `GetTabStyle(active)`
- **Style:** `ApplyTabButtonStyle()`, `ApplyReadyToggleStyle()`, `ApplyFrameStyle()`, `ApplyFontStringStyle()`
- **Widgets:** `CreateFrame()`, `CreateButton()`, `CreateScrollFrame()`, `CreateFontString()`, `CreateTabButton()`, `CreateCloseButton()`, `CreateRefreshButton()`

## Triggers

None.

## Output / Actions

- **Window chrome** — themed frames with title bar, close button, and resize-friendly padding
- **Tab buttons** — styled tab controls for the party panel (M+ Completions / Ready Check)
- **Theme tokens** — slot colors, text colors, and backdrop presets for child modules

## Logging

- **Code:** `UI` (reserved — shared helpers do not write log events today)
