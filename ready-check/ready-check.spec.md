# ready-check

## Summary

Ready Check tab: per-member repair %, food/flask/oil icons, party buff list, and zone rally check. Combines live local scans with synced payloads stored in `Key.Cache.STORE.READY`. Per-member ready toggles and a footer ready button were removed; consumable and zone data remain the focus.

## Namespace

- `Key.ReadyCheck` — data, payloads, member status, zone tracking
- `Key.ReadyCheck.UI` — table rendering and footer controls

## Files

| File | Role |
|------|------|
| `ready-check.lua` | Payloads, cache read/write, consumable status, zone rally, `GetMemberStatus()` |
| `ready-check-ui.lua` | Ready table cells, icons, layout, footer action buttons |

## Depends on (TOC order)

- `cache/cache.lua`, `buffs-and-debuffs/bd.lua`, `api-access/`, `party-sync/party-sync.lua` (protocol patterns)
- `ready-check-ui.lua` must load after `ready-check.lua`

## Public API

**Data (`Key.ReadyCheck`):**

- **Store:** `GetReadyStore()`
- **Consumable payloads (`P:`):** `BuildReadyPayload()`, `BuildEmptyReadyPayload()`, `ParseReadyPayload(message)`, `GetPlayerSnapshot()`
- **Ready-state payload (`Y:`):** `BuildReadyStatePayload()`, `ParseReadyStatePayload(message)`, `SetPartyReadyState(sender, isReady)` — parse/cache only; no UI and local player always emits `Y:0`
- **Zone payloads (`Z:` / `T:`):** `BuildZonePayload()`, `BuildZoneTargetPayload()`, `ParseZonePayload(message)`, `ParseZoneTargetPayload(message)`, `SetPartyZone(sender, zone)`, `SetPartyTargetZone(sender, zone)`, `SetTargetZone(zone, broadcast?)`, `SetTargetZoneFromPlayer()`, `GetTargetZone()`, `GetMemberZoneText(unit)`, `GetLocalZoneStatusDisplay()`, `GetMemberZoneCheckDisplay(unit)`
- **Party cache:** `SetPartyReady(sender, entry)`, `LookupCachedReady(unit)`, `GetMemberStatus(unit)`
- **Session:** `RestoreSessionCacheIfNeeded()`, `ClearCache()`, `RebindCache()`

**UI (`Key.ReadyCheck.UI`):**

- `EnsureTable(parent)`, `LayoutTable(tableFrame, contentWidth, members)`, `UpdateZoneStatus()`
- **Columns (`UI.COLUMNS`):** repair, food, flask, oil (weapon oil), party buffs, zone

## Triggers

**Dispatches:** `UI_ZONE_TARGET_SET` (from `SetTargetZone` broadcast), `UI_ZONE_CHANGED` (from player zone change)

**Internal:** `InitZoneTracking()` registers `ZONE_CHANGED` / `ZONE_CHANGED_NEW_AREA` and a periodic ticker to push zone updates and refresh the zone column.

## Output / Actions

- **Repair column** — gear durability percentage with color thresholds
- **Consumable icons** — food, flask/phial, and weapon oil with quality borders and tooltips (hearty food, low flask time, eating state)
- **Party buffs column** — comma-separated list from `Key.Api.UnitAuras:GetSelfSourcedBuffNames(unit, "HELPFUL|RAID")`: raid buffs on each member whose `sourceUnit` is that member (self-sourced). Shows "—" when none. Not buffs the local player applied to others.
- **Zone column** — compares each member’s shared zone (`Z:`) against the group rally target (`T:`); shows “Ready” when they match
- **Footer controls** — **Ready Check** (`/readycheck`), **Countdown** (`/countdown 10`), **Set Zone** (broadcasts current zone as rally target), plus rally-zone status text on the right

## Sync protocol (via `Key.PartySync`)

| Message | Role in ready-check |
|---------|---------------------|
| `P:repair:food:flask:oil:isReady` | Consumable snapshot; `isReady` is always `0` locally and is not shown in the UI |
| `Y:0` / `Y:1` | Inbound ready flag is parsed and cached via `SetPartyReadyState`; no column or toggle exposes it |
| `Z:zoneName` | Member’s current zone, stored on the ready cache entry |
| `T:zoneName` | Group rally target; leader sets via **Set Zone** |

## Logging

- **Code:** `RDCK` (reserved — ready tab does not write log events today; dumps appear under `DBUG/DumpToLog`)
