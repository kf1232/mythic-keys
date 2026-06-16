# api-access

## Summary

Isolated reads from Blizzard APIs used across Key. Keeps spell, aura, durability, weapon-enchant, and minimap geometry access in one place so UI modules get consistent values without duplicating API quirks (including secret-value restrictions on retail).

## Namespace

- `Key.Api.Spell` — `c-spell.lua`
- `Key.Api.UnitAuras` — `c-unit-auras.lua`
- `Key.Api.WeaponEnchant` — `get-weapon-enchant-info.lua`
- `Key.Api.InventoryDurability` — `get-inventory-item-durability.lua`
- `Key.Api.Minimap` — `minimap.lua`

## Files

| File | Role |
|------|------|
| `c-spell.lua` | Spell info and icon resolution |
| `c-unit-auras.lua` | Aura scans, readable fields, self-sourced buff names |
| `get-weapon-enchant-info.lua` | Temporary weapon enchant state |
| `get-inventory-item-durability.lua` | Average repair percent |
| `minimap.lua` | Minimap edge positioning math |

## Depends on (TOC order)

- `Log.lua`, `cache/cache.lua`

## Public API

- **Spell:** `GetSpellInfo(spellId)`, `GetIcon(spellId)`, `GetSpellName(spellId)`, `ResolveIcon(spellId)`
- **Auras:** `Scan(unit, filter, callback)`, `Collect(unit, filter)`, `GetSelfSourcedBuffNames(unit, filter)` — returns readable names of `HELPFUL|RAID` auras on `unit` whose `sourceUnit` is the same unit (self-sourced buffs on that member, not buffs the local player cast on them)
- **Durability:** `GetRepairPercent()` — player gear average 0–100%
- **Weapon enchant:** `GetInfo()` — active oil/enchant metadata
- **Minimap:** `GetOffsetForAngle(minimap, angle, radius)`, `GetAngleFromCursor(minimap)`

## Triggers

None.

## Output / Actions

- **Spell icons and names** — artwork and display names for consumable rows, tooltips, and logs
- **Unit aura scans** — merged buff/debuff lists per unit, including readable fields when the raw API hides values
- **Party buff labels (Ready tab)** — comma-separated names from `GetSelfSourcedBuffNames`: raid-category buffs on a member where `UnitIsUnit(aura.sourceUnit, unit)` (buffs that member applied to themselves). Does not list buffs the local player cast onto other party members.
- **Gear repair percent** — single 0–100% durability figure for the Ready tab repair column
- **Weapon oil/enchant state** — whether a temporary weapon enchant is active and which enchant applies
- **Minimap orbit positions** — screen offsets that keep a button on the minimap edge for round, square, and shaped minimap skins

## Logging

- **Code:** `APIS` (reserved — this folder does not write log events today)
