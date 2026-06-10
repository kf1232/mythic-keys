# Key

A World of Warcraft **retail** addon for Mythic+ groups: see party keystones, season bests, consumable readiness, and dungeon teleports in one resizable panel.

Type `/keyf` to open the party list.

## Features

### Party list (`/keyf`)

A movable, resizable window with two tabs:

**Completions**
- **Teleport bar** — one icon per current-season dungeon. Click a learned teleport to cast it (secure action buttons, same approach as Details/DBM keystone UIs).
- **Key tokens** — small class-colored markers on each dungeon icon show who is holding a key for that dungeon (leader key gets a gold outline).
- **Season bests table** — per-player best completed key level for each dungeon in the pool, with overtime highlighting.

**Ready**
- Repair durability, food, flask, weapon oil, party buffs, and a ready toggle per member.
- Ready state syncs with other Key users in your group.

### Party sync

Anyone with Key enabled shares data automatically — **opening the panel is not required**.

On join, login, and roster changes, Key pushes:
- Current keystone (`K:level:mapID`)
- Season bests (`M:…`)
- Ready details and ready flag (`P:…`, `Y:…`)

Other Key users can request a refresh with the `R` addon message. Data is mirrored to a **session cache** so party info survives instance transitions and brief loading-screen glitches; it clears when you leave the group.

### External keystone sources (optional)

If loaded, Key also consumes party keystone data from:
- **LibKeystone** (bundled with DBM-Core)
- **LibOpenRaid** (bundled with Details)

No duplicate logging spam — updates are deduped and formatted consistently.

### Debug console (`/keyf debug`)

- Live event log (keystones, teleports, auras, clicks)
- **Clear** — wipe the log
- **Dump** — snapshot cached addon state into the log
- **Click debug** — trace which UI layers receive mouse events (safe for teleport buttons; secure action buttons are never hooked)

## Slash commands

| Command | Description |
|---------|-------------|
| `/keyf` | Toggle the party list |
| `/keyf debug` | Open the debug console |
| `/keyf clear` | Clear the debug log |
| `/keyf dump` | Dump cached addon data to the log |
| `/keyf clickdebug` | Toggle click-hit tracing (`/keyf click` also works) |

## Installation

1. Clone or copy this folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\Key
   ```
2. Enable **Key** on the character select AddOns screen.
3. `/reload` or log in.

**Optional:** Enable **DBM-Core** and/or **Details** for richer keystone data from LibKeystone and LibOpenRaid. Key works without them via its own `KeyF` addon messages.

## Current season dungeons

The teleport bar and bests table use the Midnight Season 1 M+ pool (8 dungeons). Season data lives in `Teleports.SEASON_DUNGEONS` in `Teleports.lua` — update `challengeModeID` and `spellID` when the season rotates.

## Project layout

| File | Role |
|------|------|
| `Core.lua` | Event bus, slash commands, refresh/sync triggers |
| `PartyUI.lua` | Main panel, tabs, layout |
| `Teleports.lua` | Dungeon bar, secure teleport buttons, bests table |
| `Keystones.lua` | Keystone and season-best caches |
| `PartySync.lua` | `KeyF` addon message protocol |
| `ReadyCheck.lua` | Ready tab UI and consumable/buff state |
| `ExternalKeystones.lua` | LibKeystone / LibOpenRaid integration |
| `Auras.lua` | Party buff scanning for the Ready tab |
| `Log.lua` | Central logging with deduplication |
| `DebugUI.lua` / `DebugData.lua` | Debug console and data dump |
| `ClickDebug.lua` | Optional click-hit tracing |
| `UI.lua` | Shared frame/theme helpers |

## Development notes

### Teleport buttons

Teleport slots use `InsecureActionButtonTemplate` with `type=spell` attributes. Buttons are **pre-created at addon load** on `UIParent` and reparented into the panel later — do not create or re-attribute them from insecure click handlers, and do not call `C_Spell.CastSpell` from addon code.

Decorative slot layers (`labelBar`, tokens, leader outline) disable mouse input and propagate clicks to the action button above them.

### Sync protocol prefix

Addon message prefix: `KeyF`

| Message | Meaning |
|---------|---------|
| `K:level:mapID` | Keystone |
| `M:…` | Season bests payload |
| `P:…` | Ready consumables |
| `Y:0` / `Y:1` | Not ready / ready |
| `R` | Request full party refresh |

## Author

KyleF — version 1.0.0

## License

No license file is included in this repository. Add one if you plan to distribute the addon publicly.
