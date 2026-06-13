# api-access

## Summary

Isolated reads from Blizzard APIs used across Key. Keeps spell, aura, durability, weapon-enchant, and minimap geometry access in one place so UI modules get consistent values without duplicating API quirks (including secret-value restrictions on retail).

## Output / Actions

- **Spell icons and names** — usable spell artwork and display names for consumable rows, tooltips, and logs
- **Unit aura scans** — merged buff/debuff lists per unit, including readable fields when the raw API hides values
- **Party buff labels** — comma-separated names of raid-relevant buffs the player cast on a party member
- **Gear repair percent** — single 0–100% durability figure for the Ready tab repair column
- **Weapon oil/enchant state** — whether a temporary weapon enchant is active and which enchant applies
- **Minimap orbit positions** — screen offsets that keep a button on the minimap edge for round, square, and shaped minimap skins

## Logging

- **Code:** `APIS` (reserved — this folder does not write log events today)
