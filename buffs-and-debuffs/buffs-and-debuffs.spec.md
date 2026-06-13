# buffs-and-debuffs

## Summary

Tracks current-season consumables and party buffs for the Ready tab. Maintains Midnight flask, phial, oil, and food definitions; scans auras and enchants on each member; and pushes the player’s own readiness to the group when consumables change.

## Namespace

- `Key.AurasData` — static season consumable definitions (`bd-midnight-data.lua`)
- `Key.Auras` — consumable detection and status (`bd.lua`)
- `Key.BDUpdates` — event polling and ready payload sync (`bd-updates.lua`)
- `Key.AurasLog` — dev logging helper (`bd-logging.lua`, dev TOC only)

## Files

| File | Role |
|------|------|
| `bd-midnight-data.lua` | Season 1 flask/phial/oil/food spell and item IDs |
| `bd.lua` | Aura scan orchestration, `GetConsumableStatus(unit)` |
| `bd-updates.lua` | Registers WoW events, polls changes, triggers ready sync |
| `bd-logging.lua` | Verbose consumable/aura diagnostics (dev only) |

## Depends on (TOC order)

- `api-access/`, `ready-check/ready-check.lua`, `party-sync/party-sync.lua`, `party-ui/party-ui.lua`

## Public API

- **Data:** `Key.AurasData.midnight` — season tables loaded into `Key.Auras`
- **Status:** `GetConsumableStatus(unit)`, `GetConsumableConfig(kind)`, `GetQualityTierMeta(tier)`, `IsKnownConsumableSpell(spellId)`
- **Updates:** `UpdatePolling()`, `RegisterAuraChannels(reason)`, `SyncPlayerReadyPayload(reason)`

## Triggers

**Dispatches:** `REFRESH_UI` (when consumables change and Ready tab is relevant)

## Output / Actions

- **Food status** — icon in Ready tab showing well-fed, hearty food, eating in progress, or missing; tooltip names the active food
- **Flask / phial status** — icon with quality tier border; low remaining time highlighted; tooltip names the buff
- **Weapon oil status** — icon with quality tier when a tracked oil enchant is active; empty when none
- **Party buff list** — text column of buff names the player applied to each member (or “—” when none)
- **Ready payload sync** — repair, food, flask, oil, and ready flag broadcast to other Key users in the group
- **Live refresh** — consumable columns update while the party panel is open and the Ready tab is active

## Logging

- **Code:** `B&DB`
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.BUFFS_DEBUFFS, status, payload, { source = "FunctionName" })`
- **Module helpers:** `bd-logging.lua` (`Write`, `LogUpdate`, …) and `bd-updates.lua` (`Trace` forwards the calling function name)
- **Example line:** `[12:34:56] B&DB/SafeRegisterEvent (debug) UNIT_AURA registration failed`
