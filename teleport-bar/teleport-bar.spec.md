# teleport-bar

## Summary

The top section of the M+ Completions tab: one slot per current-season dungeon. Learned teleports are clickable; unknown teleports appear greyed out. Keystone holders are overlaid on each dungeon icon and sync with party data.

## Output / Actions

- **Dungeon icon row** — eight season dungeon icons with map art and short-name labels (labels hide when the bar is narrow)
- **Click to teleport** — learned teleports cast via secure action buttons; tooltip shows learned state or cooldown
- **Keystone tokens** — class-colored markers on a dungeon icon for each member holding that key; level shown when space allows
- **Leader key highlight** — gold outline on a dungeon slot when the party leader’s key is present
- **Learned vs unlearned** — active border and full-color icon when the teleport spell is known; desaturated when not
- **Resizable width** — slot size scales with panel width between minimum and maximum bounds

## Logging

- **Code:** `TPBR`
- **Write API:** `KeyLog:WriteEvent(KeyLog.FEATURE.TELEPORT_BAR, status, payload, { source = "FunctionName" })`
- **Module helper:** `teleport-bar-logging.lua` (`WriteEvent`, `LogTeleport`, `LogUpdate`, …)
- **Example line:** `[12:34:56] TPBR/LogTeleport (warn) Teleport on cooldown: Skyreach (30s)`
