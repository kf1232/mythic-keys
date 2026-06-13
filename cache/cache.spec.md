# cache

## Summary

Shared party-member data stores for synced addon state. Each store keeps a primary map (by sender), name lookup aliases, GUID indexes, and session mirrors that survive loading screens until the group is cleared.

## Namespace

- `Key.Cache` — store registry and read/write API
- `Key.Cache.STORE.KEYSTONE` — party keystones (`keystones`)
- `Key.Cache.STORE.SEASON_BEST` — season bests (`keystones`)
- `Key.Cache.STORE.READY` — ready consumable payloads (`ready-check`)

## Files

| File | Role |
|------|------|
| `cache.lua` | Store creation, read/write, session restore, GUID rebind |

## Depends on (TOC order)

- `Log.lua` (must load first — `Key` namespace and `Key.RegisterTrigger`)

## Public API

- **Stores:** `CreateStore(id)`, `GetStore(id)`, `GetPrimary(store)`
- **Write:** `Write(store, sender, entry)`, `UpdateBySender(store, sender, mutator)`, `Clear(store, sender)`
- **Read:** `ReadBySender(store, sender, includeSession?)`, `ReadByUnit(store, unit, includeSession?)`
- **Maintenance:** `RebindByGUID(store)`, `RestoreSession(store)`, `Wipe(store)`, `WipeSession(store)`

Party name/GUID resolution delegates to `Key.Keystones` at runtime (`BuildLookupKeys`, `FindPartyUnitForSender`).

## Triggers

None — passive data layer consumed by other modules.

## Output / Actions

- **Keystone store** — `{ level, mapID, dungeonName }` per party member
- **Season-best store** — `{ [challengeModeID] = { level, overTime } }` per member
- **Ready store** — `{ repair, food, flask, oil, isReady? }` per member

## Logging

- **Code:** `CORE` (reserved — cache does not write log events today)
