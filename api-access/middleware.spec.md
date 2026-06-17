# middleware

## Summary

Gatekeeper for every Blizzard API read in `api-access`. Evaluates inputs and outputs against retail **secret-value** restrictions (`issecretvalue`) before callers consume data or continue scans.

## Namespace

- `Key.Api.Middleware` — `middleware.lua`

## Files

| File | Role |
|------|------|
| `middleware.lua` | Secret detection, guard checks, and short-circuit helpers |
| `middleware.spec.md` | Data access instructions and limitations (this file) |

## Depends on (TOC order)

- `Log.lua` (must load before `api-access` — provides `Key` namespace)

## Public API

All helpers take an optional leading `isSecret` boolean (`true` = caller already knows the context is secret and must abort). When omitted, pass `false` or `nil`.

- **`IsSecret(value)`** — returns `true` when `value` is a Blizzard secret value
- **`IsAccessible(value)`** — returns `true` when `value` is non-nil and not secret
- **`CheckSecret(...)`** — returns `true` if any argument is secret
- **`Guard(isSecret, ...)`** — returns `true` when `isSecret == true` or any argument is secret (abort signal)
- **`Call(isSecret, fn, ...)`** — runs `fn(...)` only when not secret; returns `result, isSecret`

## Data access instructions

1. **Route all Blizzard reads through middleware.** Spell, aura, durability, weapon-enchant, and minimap modules in this folder must call `Guard` or `Call` before invoking `C_*`, `Get*`, or `Unit*` APIs.
2. **Pass the secret flag.** Every guarded entry point accepts `isSecret` as its first boolean argument (`false` when unknown). Middleware merges that flag with live `issecretvalue` checks on inputs.
3. **Short-circuit on secret.** When `Guard` returns `true`, the caller must return immediately with no side effects — no partial results, no further API calls.
4. **Abort scans.** Aura `Scan`, `Collect`, and `GetSelfSourcedBuffNames` must exit their loops on the first secret value (unit token, aura field, or pre-flagged context). Do not skip and continue.
5. **Do not propagate secrets.** Never store, log, stringify, or compare secret values. Return `nil` or omit the field instead.

## Limitations

- **Retail only.** `issecretvalue` exists on current retail clients; on clients without it, middleware treats all values as accessible.
- **Input-side only.** Middleware guards arguments passed into Blizzard APIs and values read back before use. It does not unwrap or decode secret payloads.
- **No write APIs.** This layer is read-only; it does not authorize casts, item use, or secure actions.
- **Scope.** Every Blizzard API touch in Key must go through this folder. Feature modules (`keystones`, `party`, `party-sync`, `ready-check`, `teleport-bar`, `buffs-and-debuffs`, `cache`, `ui`, etc.) call `Key.Api.*` only — never `C_*`, `Unit*`, `Get*`, `IsInGroup`, `C_Timer`, or `Ambiguate` directly.

## Triggers

None.

## Output / Actions

- **Abort signal** — `Guard` / `Call` return `isSecret = true` so callers exit early
- **Safe reads** — non-secret Blizzard API results pass through to spell, aura, durability, weapon-enchant, and minimap helpers

## Logging

- **Code:** `APIS` (reserved — middleware does not write log events)
