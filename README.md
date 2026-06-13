# Key

A World of Warcraft **retail** addon for Mythic+ groups: see party keystones, season bests, consumable readiness, and dungeon teleports in one resizable panel.

Type `/keyf` to open the party list, or click the minimap button.

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

The teleport bar and bests table use the Midnight Season 1 M+ pool (8 dungeons). Season data lives in `Teleports.SEASON_DUNGEONS` in `teleport-bar/teleport-bar-data.lua` — update `challengeModeID` and `spellID` when the season rotates.

## Project layout

| File | Role |
|------|------|
| `Core.lua` | Event bus, slash commands, refresh/sync triggers |
| `PartyUI.lua` | Main panel, tabs, layout |
| `teleport-bar/teleport-bar.lua` | Dungeon bar, secure teleport buttons |
| `teleport-bar/teleport-bar-logging.lua` | Teleport cast/cooldown logging and event hooks |
| `party-complete/party-complete.lua` | Season bests table |
| `party-complete/party-complete-logging.lua` | Completions pane layout logging |
| `party-complete/party-complete-pane.lua` | M+ Completions tab pane and scroll |
| `Keystones.lua` | Keystone and season-best caches |
| `PartySync.lua` | `KeyF` addon message protocol |
| `ReadyCheck.lua` | Ready tab UI and consumable/buff state |
| `ExternalKeystones.lua` | LibKeystone / LibOpenRaid integration |
| `Auras.lua` | Party buff scanning for the Ready tab |
| `Log.lua` | Central logging with deduplication |
| `DebugUI.lua` / `DebugData.lua` | Debug console and data dump |
| `ClickDebug.lua` | Optional click-hit tracing |
| `UI.lua` | Shared frame/theme helpers |
| `minimap/minimap-button.lua` | Minimap quick-access button |

## Development notes

### TOC manifests

- **`keys.toc`** — public release manifest (tracked in git). Omits debug console and `*-logging.lua` modules.
- **`mythic-keys.toc`** — local dev manifest (gitignored). Loads everything, including `DebugUI.lua`, `ClickDebug.lua`, and module logging.

For local development, copy or symlink `mythic-keys.toc` as your active TOC (WoW loads the folder name or whichever `.toc` matches the addon directory).

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

KyleF — version 2026.0613.1

## Use policy

Key is provided **free of charge** for personal use with World of Warcraft. By installing or using this addon, you agree to the following:

### Permitted use

- Install and use Key on your own Battle.net account(s).
- Share unmodified copies of this addon with others, provided you include this README and do not charge for the addon itself.
- Fork or modify the source for personal use or public distribution, provided you credit the original author and state clearly that your version is a derivative work.

### Prohibited use

- Selling Key, locking features behind payment, or bundling it as part of a paid product or service.
- Using Key in any way that violates the [World of Warcraft Terms of Use](https://www.blizzard.com/legal/wow_tou) or [Blizzard UI Add-On Development Policy](https://develop.battle.net/documentation/world-of-warcraft/ui-add-ons).
- Misrepresenting modified versions as the official Key addon or implying endorsement by the author or Blizzard Entertainment.

### Blizzard & third-party addons

Key is a **third-party fan project**. It is not affiliated with, endorsed by, or sponsored by Blizzard Entertainment. Key optionally integrates with libraries shipped by other addons (for example DBM-Core and Details); those projects retain their own licenses and policies.

### Disclaimer

Key is provided **“as is”**, without warranty of any kind, express or implied. The author is not liable for any loss of data, account action, in-game penalties, or other damages arising from use of this addon. You use Key at your own risk.

### Contributions

If you submit changes (for example via pull request), you grant permission for those changes to be included in this project under the same use policy above, unless you specify otherwise in writing.
