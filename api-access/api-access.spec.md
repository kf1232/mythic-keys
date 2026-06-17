# api-access

## Summary

Single gateway for all Blizzard API reads and writes used by Key. Every module outside this folder must call `Key.Api.*` helpers — never `C_*`, `Unit*`, `Get*`, `IsInGroup`, `C_Timer`, or `Ambiguate` directly. All helpers route through `Key.Api.Middleware` for secret-value guards and scan short-circuit.

## Namespace

- `Key.Api.Middleware` — `middleware.lua` (see `middleware.spec.md`)
- `Key.Api.Unit` / `Key.Api.Group` — `unit.lua`
- `Key.Api.Zone` — `zone.lua`
- `Key.Api.Strings` — `strings.lua`
- `Key.Api.ChallengeMode` — `challenge-mode.lua`
- `Key.Api.MythicPlus` — `mythic-plus.lua`
- `Key.Api.Container` — `container.lua`
- `Key.Api.Chat` — `chat.lua`
- `Key.Api.Timer` — `timer.lua`
- `Key.Api.Spell` — `c-spell.lua`
- `Key.Api.UnitAuras` — `c-unit-auras.lua`
- `Key.Api.WeaponEnchant` — `get-weapon-enchant-info.lua`
- `Key.Api.InventoryDurability` — `get-inventory-item-durability.lua`
- `Key.Api.Minimap` — `minimap.lua`

## Files

| File | Role |
|------|------|
| `middleware.lua` | Secret gatekeeper: `Guard`, `Call`, `PCall`, `AsNumber` |
| `middleware.spec.md` | Data access instructions and limitations |
| `unit.lua` | Unit identity, class, role, leader; group roster (`Group`) |
| `zone.lua` | Zone text |
| `strings.lua` | `Ambiguate` |
| `challenge-mode.lua` | Dungeon map UI info, keystone item parsing |
| `mythic-plus.lua` | Owned keystone, season bests, map info request |
| `container.lua` | Bag scans, keystone item detection |
| `chat.lua` | Addon message prefix registration and send |
| `timer.lua` | `GetTime`, `After`, `NewTicker`, `NewTimer` |
| `c-spell.lua` | Spell info, icons, spellbook, cooldowns |
| `c-unit-auras.lua` | Aura scans (short-circuit on secret) |
| `get-weapon-enchant-info.lua` | Temporary weapon enchant state |
| `get-inventory-item-durability.lua` | Gear repair percent |
| `minimap.lua` | Minimap shape, edge positioning, cursor angle |

## Depends on (TOC order)

- `Log.lua` (must load first)
- Full `api-access/` block loads before `cache/`, `party/`, and all feature modules

## Public API convention

Every method takes a leading **`isSecret`** boolean (`true` = abort immediately; pass `false` when unknown). Middleware also checks live `issecretvalue` on inputs and outputs.

- **Middleware:** `IsSecret`, `IsAccessible`, `CheckSecret`, `Guard`, `Call`, `PCall`, `AsNumber`
- **Unit:** `Exists`, `IsUnit`, `IsPlayer`, `GetGUID`, `GetName`, `GetFullName`, `GetUnitName`, `GetClass`, `GetClassFilename`, `IsGroupLeader`, `GetGroupRole`
- **Group:** `IsInGroup`, `IsInRaid`, `GetNumMembers`, `GetNumSubgroupMembers`, `GetChannel`
- **Zone:** `GetZoneText`
- **Strings:** `Ambiguate`
- **ChallengeMode:** `GetMapUIInfo`, `GetMapName`, `GetMapTexture`, `GetKeystoneLevelAndMapID`
- **MythicPlus:** `RequestMapInfo`, `GetOwnedKeystoneLevel`, `GetOwnedKeystoneChallengeMapID`, `GetOwnedKeystoneMapID`, `GetSeasonBestForMap`
- **Container:** `GetContainerNumSlots`, `GetContainerItemInfo`, `IsItemKeystone`, `FindKeystoneInBags`
- **Chat:** `RegisterAddonMessagePrefix`, `SendAddonMessage`
- **Timer:** `GetTime`, `After`, `NewTicker`, `NewTimer`
- **Spell:** `GetSpellInfo`, `GetIcon`, `GetSpellName`, `ResolveIcon`, `IsSpellInSpellBook`, `IsSpellKnown`, `GetSpellCooldown`
- **Auras:** `Scan`, `Collect`, `GetSelfSourcedBuffNames` — scans exit on first secret aura field
- **Durability:** `GetSlotDurability`, `GetRepairPercent`
- **Weapon enchant:** `GetInfo`
- **Minimap:** `GetShape`, `GetOffsetForAngle`, `GetAngleFromCursor`

## Triggers

None.

## Output / Actions

All Blizzard data consumed by keystones, party sync, ready check, teleports, buffs/debuffs, cache, and UI flows through these helpers.

## Logging

- **Code:** `APIS` (reserved — this folder does not write log events today)
