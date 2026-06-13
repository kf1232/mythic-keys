# integrations

## Summary

Optional bridges to other addons’ keystone libraries. When DBM-Core or Details is loaded, party keystone updates from LibKeystone and LibOpenRaid are folded into Key’s cache so the Completions tab stays populated even before Key-to-Key sync arrives.

## Output / Actions

- **LibKeystone (DBM)** — party keystones learned from DBM’s party channel updates appear on dungeon icons and in the group cache
- **LibOpenRaid (Details)** — keystone level and map from Details/OpenRaid callbacks appear for roster members
- **Unified party display** — external keystones use the same tokens, tooltips, and deduped log lines as native Key sync (no duplicate spam)
- **On-demand requests** — party keystone data is requested from external providers when the group forms or a manual refresh runs

## Logging

- **Code:** `EXTK` (reserved; keystone updates currently log via `SYNC/LogKeystone`)
- **Write API:** `KeyLog:WriteEvent(KeyLog.FEATURE.INTEGRATIONS, status, payload, { source = "FunctionName" })`
- **Example line:** `[12:34:56] SYNC/LogKeystone (info) PlayerName: +15 Algeth'ar Academy`
