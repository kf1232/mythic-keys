# party-complete

## Summary

The M+ Completions tab content below the teleport bar: a scrollable season-bests grid aligned to the current dungeon pool. One row per party member; columns match the eight season dungeons shown above.

## Namespace

- `Key.Teleports` — bests table layout (extended in `party-complete.lua`)
- `Key.PartyUI` — completions pane methods patched in `party-complete-pane.lua`

## Files

| File | Role |
|------|------|
| `party-complete.lua` | Bests table metrics, cell layout, `LayoutBestTable()` |
| `party-complete-pane.lua` | Completions pane, scroll region, `RefreshCompletionsPane()` on `Key.PartyUI` |
| `party-complete-logging.lua` | Dev layout snapshots (dev TOC only) |

## Depends on (TOC order)

- `teleport-bar/teleport-bar-data.lua`, `teleport-bar/teleport-bar.lua`, `party-complete.lua`
- `party-complete-pane.lua` after `party-ui/party-ui.lua` (extends `Key.PartyUI`)

## Public API

- **Teleports:** `EnsureBestTable(parent)`, `LayoutBestTable(table, contentWidth, members)`, `GetBestTableHeight(memberCount, contentWidth)`
- **PartyUI (pane):** `EnsureCompletionsPane(frame)`, `RefreshCompletionsPane(contentWidth, members)`, `GetMemberBlockHeight(memberCount, contentWidth)`

## Triggers

None.

## Output / Actions

- **Member rows** — class-colored player name above their bests row
- **Best level cells** — `+level` per dungeon, class-colored; em dash when no season best
- **Overtime runs** — completed keys over time shown with desaturated text
- **Cell tooltips** — hover shows player, dungeon, and best level (or “no completed run this season”)
- **Column alignment** — bests columns line up under the matching teleport-bar dungeon icons
- **Scrollable list** — vertical scroll when the group has more than six members; pane height grows with visible rows

## Logging

- **Code:** `PCMP`
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.PARTY_COMPLETE, status, payload, { source = "FunctionName" })`
- **Module helper:** `party-complete-logging.lua` (`WriteEvent`, `LogLayout`, `LogSnapshot`, …)
- **Example line:** `[12:34:56] PCMP/LogLayout (debug) layout width=848 members=5 table=120 viewport=96 teleport=108`
