# integrations

## Summary

Optional bridges to other addons’ keystone libraries. When DBM-Core or Details is loaded, party keystone updates from LibKeystone and LibOpenRaid are folded into `Key.Cache` so the Completions tab stays populated even before Key-to-Key sync arrives.

## Namespace

- `Key.Integrations.LibKeystone` — DBM LibKeystone adapter
- `Key.Integrations.LibOpenRaid` — Details LibOpenRaid adapter
- `Key.Integrations.ExternalKeystones` — provider registry and unified import

## Files

| File | Role |
|------|------|
| `lib-keystone.lua` | LibKeystone (DBM) callback handler |
| `lib-openraid.lua` | LibOpenRaid (Details) party cache import |
| `external-keystones.lua` | Provider init, `RequestPartyKeys()`, merge into keystones cache |

## Depends on (TOC order)

- `cache/cache.lua`, `party/party.lua`, `keystones/keystones.lua`, `party-sync/party-sync.lua` (optional at runtime: DBM-Core, Details)

## Public API

- **ExternalKeystones:** `Init()`, `RequestPartyKeys()`, `GetProviderSummary()`, `providers`
- **LibKeystone:** `OnUpdate(host, keyLevel, mapID, …)`
- **LibOpenRaid:** `ImportPartyCache(host)`

## Triggers

None registered directly; `external-keystones.lua` listens for `CHALLENGE_MODE_MAPS_UPDATE` and provider callbacks.

**Dispatches:** `REFRESH_UI` when an external keystone is merged

## Output / Actions

- **LibKeystone (DBM)** — party keystones from DBM’s party channel appear on dungeon icons and in the keystone cache
- **LibOpenRaid (Details)** — keystone level and map from Details/OpenRaid callbacks appear for roster members
- **Unified party display** — external keystones use the same tokens, tooltips, and deduped log lines as native Key sync (no duplicate spam)
- **On-demand requests** — party keystone data is requested from external providers when the group forms or a manual refresh runs

## Logging

- **Code:** `EXTK` (reserved; keystone updates currently log via `SYNC/LogKeystone`)
- **Write API:** `Key.Log:WriteEvent(Key.Log.FEATURE.INTEGRATIONS, status, payload, { source = "FunctionName" })`
- **Example line:** `[12:34:56] SYNC/LogKeystone (info) PlayerName: +15 Algeth'ar Academy`
