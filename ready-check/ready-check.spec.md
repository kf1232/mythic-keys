# ready-check

## Summary

Ready Check tab: per-member repair %, food/flask/oil icons, party buff list, and ready toggle. Combines live local scans with synced payloads stored in `Key.Cache.STORE.READY`.

## Namespace

- `Key.ReadyCheck` — data, payloads, member status
- `Key.ReadyCheck.UI` — table rendering and footer toggle

## Files

| File | Role |
|------|------|
| `ready-check.lua` | Payloads, player ready state, cache read/write, `GetMemberStatus()` |
| `ready-check-ui.lua` | Ready table cells, icons, layout, footer toggle button |

## Depends on (TOC order)

- `cache/cache.lua`, `buffs-and-debuffs/bd.lua`, `api-access/`, `party-sync/party-sync.lua` (protocol patterns)
- `ready-check-ui.lua` must load after `ready-check.lua`

## Public API

**Data (`Key.ReadyCheck`):**

- **Store:** `GetReadyStore()`, `GetPrimaryEntries()`
- **Payloads:** `BuildReadyPayload()`, `BuildEmptyReadyPayload()`, `BuildReadyStatePayload()`, `ParseReadyPayload(message)`, `ParseReadyStatePayload(message)`
- **Player:** `GetPlayerReady()`, `TogglePlayerReady()`, `GetPlayerSnapshot()`
- **Party:** `SetPartyReady(sender, entry)`, `SetPartyReadyState(sender, isReady)`, `LookupCachedReady(unit)`, `GetMemberStatus(unit)`, `GetMemberReadyState(unit)`
- **Session:** `RestoreSessionCacheIfNeeded()`, `ClearCache()`, `RebindCache()`

**UI (`Key.ReadyCheck.UI`):**

- `EnsureTable(parent)`, `LayoutTable(tableFrame, contentWidth, members)`, `UpdateToggleButton()`

## Triggers

**Dispatches:** `UI_READY_TOGGLE` (from player toggle)

## Output / Actions

- **Repair column** — gear durability percentage with color thresholds
- **Consumable icons** — food, flask/phial, and weapon oil with quality borders and tooltips
- **Party buffs column** — comma-separated list of player-cast raid buffs on each member
- **Ready toggle** — per-row ready/unready state synced via `Y:` and `P:` messages
- **Footer control** — player ready toggle at the bottom of the tab

## Logging

- **Code:** `RDCK` (reserved — ready tab does not write log events today; dumps appear under `DBUG/DumpToLog`)
