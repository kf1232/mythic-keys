# party-complete

## Summary

The M+ Completions tab content below the teleport bar: a scrollable season-bests grid aligned to the current dungeon pool. One row per party member; columns match the eight season dungeons shown above.

## Output / Actions

- **Member rows** — class-colored player name above their bests row
- **Best level cells** — `+level` per dungeon, class-colored; em dash when no season best
- **Overtime runs** — completed keys over time shown with desaturated text
- **Cell tooltips** — hover shows player, dungeon, and best level (or “no completed run this season”)
- **Column alignment** — bests columns line up under the matching teleport-bar dungeon icons
- **Scrollable list** — vertical scroll when the group has more than six members; pane height grows with visible rows
