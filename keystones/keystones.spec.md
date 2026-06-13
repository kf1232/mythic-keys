# keystones

## Summary

Keystone and season-best data layer: reads the player’s key, caches party member keys and bests (session + primary), resolves dungeon names, and builds addon-message payloads for sync.

## Output / Actions

- **Player keystone** — current key level and map for the logged-in character
- **Party key cache** — keystones per member, keyed by name/GUID for UI tokens and tooltips
- **Season bests cache** — per-member best level (and overtime flag) per dungeon
- **Member roster** — ordered party/raid member list for table layout
- **Sync payloads** — encoded `K:` and `M:` message bodies for `party-sync`

## Logging

- **Code:** `KEYS` (reserved; keystone lines use `SYNC/LogKeystone` today)
- **Example line:** `[12:34:56] SYNC/LogKeystone (info) PlayerName: +15 Algeth'ar Academy`
