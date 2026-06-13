# teleport-bar

## Summary

The top section of the M+ Completions tab: one slot per current-season dungeon. Learned teleports are clickable; unknown teleports appear greyed out. Keystone holders are overlaid on each dungeon icon and sync with party data.

## Namespace

- `Key.Teleports` — shared with `party-complete` (season data, bar layout, bests table helpers)

## Files

| File | Role |
|------|------|
| `teleport-bar-data.lua` | `SEASON_DUNGEONS` pool (challengeModeID, spellID, shortName) |
| `teleport-bar.lua` | Secure teleport buttons, slot layout, key token overlays |
| `teleport-bar-logging.lua` | Dev snapshot/teleport logging (dev TOC only) |

## Depends on (TOC order)

- `teleport-bar-data.lua` before `teleport-bar.lua`; `keystones/keystones.lua` for key tokens

## Public API

- **Data:** `SEASON_DUNGEONS`, `GetSeasonDungeons()` (via keystones)
- **Layout:** `ComputeLayout(contentWidth)`, `LayoutBar(bar, contentWidth)`, `GetDefaultFrameWidth(padding)`, `GetMinFrameWidth(padding)`
- **Bar:** `EnsureBar(parent)`, `bar` (pre-created secure buttons on `UIParent`)
- **Tokens:** key holder dots and leader outline on each slot

## Triggers

None.

## Output / Actions

- **Dungeon icon row** — eight season dungeon icons with map art and short-name labels (labels hide when the bar is narrow)
- **Click to teleport** — learned teleports cast via secure action buttons; tooltip shows learned state or cooldown
- **Keystone tokens** — class-colored markers on a dungeon icon for each member holding that key; level shown when space allows
- **Leader key highlight** — gold outline on a dungeon slot when the party leader’s key is present
- **Learned vs unlearned** — active border and full-color icon when the teleport spell is known; desaturated when not
- **Resizable width** — slot size scales with panel width between minimum and maximum bounds

## Logging

- **Code:** `TPBR`
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.TELEPORT_BAR, status, payload, { source = "FunctionName" })`
- **Module helper:** `teleport-bar-logging.lua` (`WriteEvent`, `LogTeleport`, `LogUpdate`, …)
- **Example line:** `[12:34:56] TPBR/LogTeleport (warn) Teleport on cooldown: Skyreach (30s)`
