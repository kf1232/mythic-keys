# party-sync

## Summary

Group data sync over the `KeyF` addon message prefix. Pushes and receives keystones, season bests, ready consumables, and zone rally data when the roster changes, on login, and on manual refresh.

## Namespace

- `Key.PartySync`

## Files

| File | Role |
|------|------|
| `party-sync.lua` | Protocol, send/receive, debounced roster sync, trigger registration |

## Depends on (TOC order)

- `cache/cache.lua`, `party/party.lua`, `keystones/keystones.lua`, `ready-check/ready-check.lua`, `integrations/external-keystones.lua`

## Public API

- **Protocol:** `PREFIX` (`KeyF`), `PROTOCOL` (`K`, `M`, `P`, `Y`, `Z`, `T`, `R`)
- **Send:** `PushAll(force?)`, `PushKey(force?)`, `PushBest(force?)`, `PushReady(force?)`, `PushReadyState(force?)`, `PushZone(force?)`, `PushZoneTarget(force?)`, `SchedulePartySync()`
- **Receive:** `OnAddonMessage(prefix, message, channel, sender)`
- **Lifecycle:** `BootstrapIfGrouped()`, `OnPartyChanged()`, `OnGroupLeft()`, `InvalidatePayloadCache(scope)`

## Triggers

**Registers:**

- `ADDON_LOADED` — bootstrap sync when already grouped
- `GROUP_LEFT` — clear party caches
- `GROUP_CHANGED`, `PLAYER_ENTERING_WORLD`, `KEYSTONE_DATA_CHANGED` — schedule sync / invalidate payloads
- `CHAT_MSG_ADDON` — inbound message handling
- `PARTY_SYNC_SCHEDULE`, `PARTY_CHANGED` — debounced roster push
- `UI_PANEL_OPEN`, `UI_REFRESH_CLICK` — push on panel open / manual refresh
- `UI_ZONE_TARGET_SET`, `UI_ZONE_CHANGED` — push zone target / zone on set / player zone change

**Dispatches:** `PARTY_CHANGED`, `PARTY_SYNC_SCHEDULE`, `REFRESH_UI` (via inbound messages and schedule)

## Output / Actions

- **Auto broadcast** — shares key, bests, ready consumables, and zone rally data when joining a group or on roster change (panel closed is fine)
- **Inbound merge** — applies other Key users’ messages into `Key.Cache` via keystones and ready-check
- **Refresh request** — `R` message triggers a full re-push from peers
- **Session survival** — coordinates with `Key.Cache` session mirrors across loading screens until group leave

## Logging

- **Code:** `SYNC`
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.PARTY_SYNC, status, payload, { source = "FunctionName" })`
- **Example lines:**
  - `[12:34:56] SYNC/LogKeystone (info) PlayerName: +15 Skyreach`
  - `[12:34:56] SYNC/SendAddonMessage (warn) Party keystone share skipped (addon messages blocked).`
