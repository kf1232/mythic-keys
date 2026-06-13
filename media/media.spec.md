# media

## Summary

Static artwork for Key branding. Supplies the icon shown in the AddOns list and the texture referenced by the addon manifest; no runtime logic lives in this folder.

## Namespace

None — assets only. Referenced by `Key.DEFAULT_ICON` and TOC `IconTexture`.

## Files

| File | Role |
|------|------|
| `icon.png` | Packaging / README artwork |
| `icon.tga` | In-game texture path used by the TOC |

## Depends on (TOC order)

None (loaded by path reference only).

## Public API

None.

## Triggers

None.

## Output / Actions

- **AddOns list icon** — Key logo on the character-select AddOns screen (`IconTexture` in the TOC)
- **Shared icon asset** — PNG and TGA copies of the same logo for packaging and in-game texture paths

## Logging

- **Code:** `MEDI` (reserved — static assets only, no log events)
