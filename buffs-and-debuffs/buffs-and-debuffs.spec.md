# buffs-and-debuffs

## Summary

Tracks current-season consumables and party buffs for the Ready tab. Maintains Midnight flask, phial, oil, and food definitions; scans auras and enchants on each member; and pushes the player’s own readiness to the group when consumables change.

## Output / Actions

- **Food status** — icon in Ready tab showing well-fed, hearty food, eating in progress, or missing; tooltip names the active food
- **Flask / phial status** — icon with quality tier border; low remaining time highlighted; tooltip names the buff
- **Weapon oil status** — icon with quality tier when a tracked oil enchant is active; empty when none
- **Party buff list** — text column of buff names the player applied to each member (or “—” when none)
- **Ready payload sync** — repair, food, flask, oil, and ready flag broadcast to other Key users in the group
- **Live refresh** — consumable columns update while the party panel is open and the Ready tab is active
