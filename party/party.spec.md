# party

## Summary

Group roster and sender identity helpers: enumerate party/raid units, resolve addon-message senders to live units, and normalize ambiguous player names. Shared by the cache layer, UI layout, sync, and integrations — not keystone-specific.

## Namespace

- `Key.Party`

## Files

| File | Role |
|------|------|
| `party.lua` | Roster enumeration, sender normalization, name lookup keys, unit resolution |

## Depends on (TOC order)

- `cache/cache.lua` (for `Key.Cache:IsAccessible` only — party does not call into keystones)

## Public API

- **Sender:** `NormalizeSender(sender)`
- **Lookup:** `BuildLookupKeys(name)`
- **Roster:** `CollectMembers()`, `GetPartyUnits()`
- **Resolution:** `FindPartyUnitForSender(sender)`

## Triggers

None — passive helpers consumed by other modules.

## Output / Actions

- **Member roster** — ordered `{ unit, name, classFilename }` list for table layout (Completions, Ready)
- **Unit list** — `player` + `partyN` / `raidN` tokens for iteration
- **Sender → unit** — maps addon-message sender strings to a live group unit for GUID indexing in `Key.Cache`

## Logging

- **Code:** `CORE` (reserved — party does not write log events today)

---

## Why migrate from `Key.Keystones` (actionable)

Today five roster/identity helpers live on `Key.Keystones` while `cache.lua` delegates to them at runtime. That works but misplaces ownership and inverts load order. Each task below states the problem with the current design and the concrete fix.

| # | Problem (current design) | Action |
|---|--------------------------|--------|
| 1 | **Inverted dependency.** `cache.lua` loads before `keystones.lua` yet calls `Key.Keystones:BuildLookupKeys` / `FindPartyUnitForSender` for every store write and GUID rebind. The data layer reaches up into a domain module. | Add `party/party.lua` after cache in TOC; repoint `Cache:BuildLookupKeys` and `Cache:FindPartyUnitForSender` to `Key.Party`. |
| 2 | **Misplaced ownership.** Roster enumeration and sender disambiguation are group concerns, not keystone concerns. They are consumed by party-ui, party-sync, integrations, and ready-check stores — not only keystones. | Move `NormalizeSender`, `BuildLookupKeys`, `CollectMembers`, `GetPartyUnits`, `FindPartyUnitForSender` into `Key.Party`. |
| 3 | **Naming drift.** Callers already use `Key.PartyUI`, `Key.PartySync`, `Key.PartyComplete` for group features. Roster helpers on `Key.Keystones` hide the shared surface and suggest keystone-only scope. | Expose roster/identity on `Key.Party`; update consumers to call it directly. |
| 4 | **Keystones scope creep.** `Key.Keystones` should own key data, payloads, and cache accessors — not live unit iteration and `Ambiguate` alias sets. | Remove the five helpers from `keystones.lua`; keep internal call sites on `Key.Party`. |
| 5 | **Future stores blocked.** Ready-check (and any new cache store) needs sender→unit resolution without importing keystone logic. | Party module depends only on `Key.Cache:IsAccessible`; no keystones import. |

## Migration (completed)

1. Added `party/party.lua` after `cache/cache.lua` in `keys.toc` and `mythic-keys.toc`.
2. Moved from `keystones/keystones.lua` into `party/party.lua`: `NormalizeSender`, `BuildLookupKeys`, `CollectMembers`, `GetPartyUnits`, `FindPartyUnitForSender`. Party uses `Key.Cache:IsAccessible` directly.
3. Repointed `cache/cache.lua` — `BuildLookupKeys` and `FindPartyUnitForSender` delegate to `Key.Party`.
4. Updated consumers: `party-ui`, `party-sync`, `integrations/lib-openraid.lua`, `integrations/external-keystones.lua`, and internal `keystones` call sites.
5. **Optional compat shim** (skipped): thin `Keystones:*` wrappers if external callers remain.
6. Updated specs and README project layout.

## Target TOC slice

```
Log.lua
cache/cache.lua
party/party.lua          ← loads here
...
keystones/keystones.lua
```

## Verification

- Grouped in party and raid: `Key.Party:CollectMembers()` returns expected roster.
- Addon message from a group member resolves via `Key.Cache:Write` / `ReadBySender` (keystone, best, ready stores).
- `/keyf dump` shows party caches keyed correctly after sync.
- Leave group: session wipe still works (no change to cache lifecycle).
