# Release workflow — Key on CurseForge

This document describes how **Key** is published from `kf1232/mythic-keys` to CurseForge.

Read this before cutting a release. GitHub Release zips are **not** what CurseForge uses.

---

## How CurseForge gets the addon

The repo has a GitHub webhook pointing at CurseForge **Automatic Packaging**:

```
https://www.curseforge.com/api/projects/1571010/package?token={API_TOKEN}
```

When GitHub sends a **push** or **release** event, CurseForge:

1. Checks out the repository (at the tagged commit when a tag is pushed)
2. Reads `.pkgmeta` and the release TOC (`Key.toc`)
3. Builds a zip with folder `Key/` and uploads it to project **1571010**

CurseForge does **not** download assets attached to GitHub Releases. Manually building `Key-{version}.zip` and uploading it to GitHub only helps users who install from GitHub directly.

Official reference: [CurseForge Automatic Packaging](https://support.curseforge.com/en/support/solutions/articles/9000197281-automatic-packaging)

---

## Repo layout for releases

| File | Purpose |
|------|---------|
| `Key.toc` | **CurseForge release manifest.** Title `Key`, install path `Interface\AddOns\Key\`. Bump `## Version:` here each release. |
| `.pkgmeta` | Tells CurseForge to package as folder `Key` and exclude dev TOCs. |
| `mythic-keys-beta.toc` | Local dev copy (this folder). Not packaged. |
| `mythic-keys.toc` | Stable dev reference; keep file list in sync with `Key.toc`. Not packaged. |

### `.pkgmeta` (do not remove)

```yaml
package-as: Key
enable-nolib-creation: no
ignore:
  - mythic-keys.toc
  - mythic-keys-beta.toc
  - .gitignore
```

### `Key.toc` requirements

- `## Title: Key` — must match CurseForge project name and install folder
- `## Interface: 120100, 120007` — list all supported interface versions (12.1 + 12.0.7)
- `## IconTexture: Interface\AddOns\Key\media\icon` — path uses `Key`, not `mythic-keys`
- `## X-Curse-Project-ID: 1571010`
- File list must match every Lua file shipped in the release (same as `mythic-keys.toc`)

When adding or moving Lua files, update **both** `Key.toc` and `mythic-keys.toc`.

---

## Release type from git tags

CurseForge sets alpha / beta / release from the **tag name**:

| Tag pattern | CurseForge release type |
|-------------|-------------------------|
| contains `alpha` | Alpha |
| contains `beta` | Beta |
| anything else (e.g. `v2026.0811.3`) | **Release** |

Use tags like `v2026.MMDD.N` without `alpha` or `beta` for normal releases.

---

## Step-by-step release

### 1. Prepare on `main`

1. Merge all changes for the release into `main`.
2. Bump `## Version:` in **`Key.toc`** (and `mythic-keys.toc` for consistency).
3. Confirm `## Interface:` is still correct for the current WoW patch.
4. Confirm `Key.toc` file list includes any new or moved modules.

### 2. Commit and push

```powershell
git checkout main
git pull origin main
git add Key.toc mythic-keys.toc   # plus any other release-related changes
git commit -m "Key 2026.MMDD.N"
git push origin main
```

### 3. Tag and push the tag

The tag triggers CurseForge packaging. Tag message is optional but helpful.

```powershell
git tag -a v2026.MMDD.N -m "Key 2026.MMDD.N"
git push origin v2026.MMDD.N
```

Example that worked: `v2026.0811.3` on commit with `Key.toc` + `.pkgmeta`.

### 4. Verify CurseForge (required)

1. Open [CurseForge Author Portal](https://authors.curseforge.com) → project **Key** (ID **1571010**) → **Files**.
2. Look for the new version within a few minutes.
3. Status may be **Under Review** until moderators approve.
4. Check email for rejection or changes-required notices.

### 5. Verify GitHub webhook (optional)

Repo → **Settings** → **Webhooks** → CurseForge hook → **Recent Deliveries**:

- **200** = payload received (does not guarantee the file was approved)
- Push events fire for `main` and for tag pushes

### 6. GitHub Release (optional)

GitHub Releases are **optional**. They do not drive CurseForge.

If you want a GitHub download mirror:

```powershell
gh release create v2026.MMDD.N --title "Key 2026.MMDD.N" --notes-file notes.md
```

Do not rely on attaching a hand-built zip as the primary release path for CurseForge.

---

## Version numbering

Project convention: **`YYYY.MMDD.N`**

| Part | Meaning |
|------|---------|
| `YYYY.MMDD` | Date of release |
| `N` | Same-day increment (1, 2, 3…) |

Tag: `v` + version → `v2026.0811.3`  
In-game / CurseForge display: `2026.0811.3` (no `v` in `Key.toc`)

---

## End-user install path

CurseForge and the packaged zip install to:

```
World of Warcraft\_retail_\Interface\AddOns\Key\
```

Local development uses folder `mythic-keys-beta` and `mythic-keys-beta.toc`.

---

## Troubleshooting

### Webhook 200 but no file on CurseForge

Common causes:

1. **Missing `Key.toc` or `.pkgmeta`** — CurseForge had nothing valid to package (this broke releases before 2026.0811.3).
2. **Wrong TOC name** — folder must be `Key` with `Key.toc`; `mythic-keys.toc` alone is not used for CF packaging.
3. **Tag not pushed** — only pushing `main` may package an untagged commit as **alpha** depending on project settings.
4. **File under moderation** — check Author Portal → Files for **Under Review** or **Rejected**.
5. **Unsupported game version** — if `## Interface:` is ahead of CurseForge’s game-version list, upload may fail silently; try adding the previous patch (e.g. `120007`) alongside the new one.

### Manual upload fallback

If auto-packaging fails:

1. Download or build a zip: top-level folder `Key/`, containing `Key.toc` and all listed files.
2. Author Portal → Files → **Add File**.
3. Upload `.zip` only, set **Release**, select supported WoW versions, add changelog.

### What not to do

- Do not assume GitHub Release assets update CurseForge.
- Do not rename the CurseForge install folder away from `Key` without updating `.pkgmeta`, `Key.toc`, and the CF project.
- Do not edit only `mythic-keys.toc` and forget `Key.toc` before tagging.

---

## Quick checklist

```
[ ] Version bumped in Key.toc (and mythic-keys.toc)
[ ] Key.toc file list matches shipped code
[ ] ## Interface includes current + previous patch if needed
[ ] Changes committed and pushed to main
[ ] Annotated tag v{version} created and pushed
[ ] CurseForge Files tab shows new version (or Under Review)
[ ] In-game smoke test from CurseForge download when approved
```

---

## Links

- Repo: https://github.com/kf1232/mythic-keys
- CurseForge project: https://www.curseforge.com/wow/addons/key (ID **1571010**)
- CF automatic packaging: https://support.curseforge.com/en/support/solutions/articles/9000197281-automatic-packaging
- CF manual file upload: https://support.curseforge.com/en/support/solutions/articles/9000197241-creating-and-submitting-a-project
- CF upload API: https://support.curseforge.com/en/support/solutions/articles/9000197321-curseforge-upload-api
