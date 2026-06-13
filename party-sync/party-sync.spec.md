# party-sync

## Summary

Group data sync over the `KeyF` addon message prefix. Pushes and receives keystones, season bests, ready consumables, and ready toggles when the roster changes, on login, and on manual refresh.

## Output / Actions

- **Auto broadcast** — shares key, bests, and ready state when joining a group or on roster change (panel closed is fine)
- **Inbound merge** — applies other Key users’ messages into `keystones` and `ready-check` caches
- **Refresh request** — `R` message triggers a full re-push from peers
- **Session survival** — coordinates with keystones session cache across loading screens until group leave

## Logging

- **Code:** `SYNC`
- **Write API:** `KeyLog:WriteEvent(KeyLog.FEATURE.PARTY_SYNC, status, payload, { source = "FunctionName" })`
- **Example lines:**
  - `[12:34:56] SYNC/LogKeystone (info) PlayerName: +15 Skyreach`
  - `[12:34:56] SYNC/SendAddonMessage (warn) Party keystone share skipped (addon messages blocked).`
