# keystones

## Summary

Keystone and season-best data layer: reads the player’s key, manages party caches via `Key.Cache`, resolves dungeon names, builds roster lists, and encodes addon-message payloads for sync.

## Namespace

- `Key.Keystones`

## Files

| File | Role |
|------|------|
| `keystones.lua` | Player/party key reads, cache accessors, sync payloads, roster helpers |

## Depends on (TOC order)

- `cache/cache.lua`, `ui/ui.lua` (indirect, for teleports season pool)

## Public API

- **Stores:** `GetKeystoneStore()`, `GetSeasonBestStore()`
- **Player:** `GetOwnKeystone()`, `GetOwnBestForMap(challengeModeID)`
- **Party:** `SetPartyKey(sender, level, mapID)`, `SetPartyBest(sender, bests)`, `GetMemberKey(unit)`, `GetMemberBestForMap(unit, mapID)`, `GetPartyKeyTokensByMap()`
- **Roster:** `CollectMembers()`, `GetPartyUnits()`, `FindPartyUnitForSender(sender)`, `BuildLookupKeys(name)`
- **Sync payloads:** `BuildBestPayload()`, `BuildEmptyBestPayload()`, `ParseBestPayload(message)`
- **Session:** `RestoreSessionCacheIfNeeded()`, `ClearPartyCache()`, `RebindPartyCache()`
- **Display:** `FormatKey(key)`, `GetClassColor(classFilename)`

## Triggers

**Registers:** `PLAYER_ENTERING_WORLD` — restore session caches when grouped

## Output / Actions

- **Player keystone** — current key level and map for the logged-in character
- **Party key cache** — keystones per member for UI tokens and tooltips
- **Season bests cache** — per-member best level per dungeon in the season pool
- **Member roster** — ordered party/raid member list for table layout
- **Sync payloads** — encoded `K:` and `M:` message bodies for `party-sync`

## Logging

- **Code:** `KEYS` (reserved; keystone lines use `SYNC/LogKeystone` today)
- **Example line:** `[12:34:56] SYNC/LogKeystone (info) PlayerName: +15 Algeth'ar Academy`
