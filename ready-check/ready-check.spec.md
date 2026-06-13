# ready-check

## Summary

Ready Check tab: per-member repair %, food/flask/oil icons, party buff list, and ready toggle. Combines live local scans with synced payloads from other Key users.

## Output / Actions

- **Repair column** — gear durability percentage with color thresholds
- **Consumable icons** — food, flask/phial, and weapon oil with quality borders and tooltips
- **Party buffs column** — comma-separated list of player-cast raid buffs on each member
- **Ready toggle** — per-row ready/unready state synced via `Y:` and `P:` messages
- **Footer control** — player ready toggle at the bottom of the tab

## Logging

- **Code:** `RDCK` (reserved — ready tab does not write log events today; dumps appear under `DBUG/DumpToLog`)
