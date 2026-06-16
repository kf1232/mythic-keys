# party-complete

## Summary

Season-bests table for the M+ Completions tab: one row per party member; columns match the eight season dungeons in the teleport bar. Pane shell (scroll, layout) lives in `party-ui/completions-pane.lua`.

## Namespace

- `Key.PartyComplete` — season dungeon pool (aliased from teleport data), bests table layout
- `Key.Teleports` — teleport bar only (`EnsureBar`, `LayoutBar`, …)

## Files

| File | Role |
|------|------|
| `party-complete.lua` | `Key.PartyComplete`: bests table metrics, cell layout, `LayoutBestTable()` |
| `party-complete-logging.lua` | Dev layout snapshots (dev TOC only) |

## Depends on (TOC order)

- `teleport-bar/teleport-bar-data.lua`, `teleport-bar/teleport-bar.lua`

## Public API

- **PartyComplete:** `EnsureBestTable(parent)`, `LayoutBestTable(table, contentWidth, members)`, `GetBestTableHeight(memberCount, contentWidth)`, `SEASON_DUNGEONS`

## Triggers

None.

## Output / Actions

- **Member rows** — class-colored player name above their bests row
- **Best level cells** — in-time `+level` per dungeon, class-colored; em dash when no in-time season best
- **Cell tooltips** — hover shows player, dungeon, and in-time best level (or “no completed run this season”)
- **Column alignment** — bests columns line up under the matching teleport-bar dungeon icons
- **Scrollable list** — vertical scroll when the group has more than six members; pane height grows with visible rows

## Logging

- **Code:** `PCMP`
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.PARTY_COMPLETE, status, payload, { source = "FunctionName" })`
- **Module helper:** `party-complete-logging.lua` (`WriteEvent`, `LogLayout`, `LogSnapshot`, …)
- **Example line:** `[12:34:56] PCMP/LogLayout (debug) layout width=848 members=5 table=120 viewport=96 teleport=108`
