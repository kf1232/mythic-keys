# keystones

## Summary

Keystone and season-best data layer: reads the player’s key, manages party caches via `Key.Cache`, resolves dungeon names, and encodes addon-message payloads for sync. Group roster and sender identity live in `Key.Party` (see `party/party.spec.md`).

## Namespace

- `Key.Keystones`

## Files

| File | Role |
|------|------|
| `keystones.lua` | Player/party key reads, cache accessors, sync payloads |

## Depends on (TOC order)

- `cache/cache.lua`, `party/party.lua`, `ui/ui.lua` (indirect, for teleports season pool)

## Public API

- **Stores:** `GetKeystoneStore()`, `GetSeasonBestStore()`
- **Player:** `GetOwnKeystone()`, `GetOwnBestForMap(challengeModeID)`
- **Party cache:** `SetPartyKey(sender, level, mapID)`, `SetPartyBest(sender, bests)`, `GetMemberKey(unit)`, `GetMemberBestForMap(unit, mapID)`, `GetPartyKeyTokensByMap()`
- **Sync payloads:** `BuildBestPayload()`, `BuildEmptyBestPayload()`, `ParseBestPayload(message)`
- **Session:** `RestoreSessionCacheIfNeeded()`, `ClearPartyCache()`, `RebindPartyCache()`
- **Display:** `FormatKey(key)`, `GetClassColor(classFilename)`

## Triggers

**Registers:** `PLAYER_ENTERING_WORLD` — restore session caches when grouped

## Output / Actions

- **Player keystone** — current key level and map for the logged-in character
- **Party key cache** — keystones per member for UI tokens and tooltips
- **Season bests cache** — per-member in-time best level per dungeon in the season pool
- **Sync payloads** — encoded `K:` and `M:` message bodies for `party-sync`

## Season bests (in-time only)

Only in-time completions are tracked, synced, cached, and shown. Overtime runs are excluded end-to-end:

- **`PickBestRun()`** — reads `C_MythicPlus.GetSeasonBestForMap` in-time level only; always returns `overTime = false`
- **`ParseBestPayload()`** — drops payload pairs where the OT flag is `1`; stored entries always have `overTime = false`
- **`GetMemberBestForMap()`** — returns cached entries only when `not entry.overTime` (defensive; cache never stores OT today)

The `M:` wire format still carries a second `level:otFlag` field per dungeon for protocol compatibility, but OT values are never populated or consumed.

## Logging

- **Code:** `KEYS` (reserved; keystone lines use `SYNC/LogKeystone` today)
- **Example line:** `[12:34:56] SYNC/LogKeystone (info) PlayerName: +15 Algeth'ar Academy`
