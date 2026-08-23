# Phase 0 — Repo Bootstrap & Upstream Vendoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the empty `agentarchy` git repo into a scaffolded project with a reproducible, testable way to vendor the desktop-agnostic parts of upstream Omarchy (quattro) under the `oal-*` naming, plus the hygiene gates a public repo needs.

**Architecture:** A bash toolchain under `bin/oal-dev-*` fetches the pinned upstream tarball, copies only the paths listed in `upstream/VENDOR-MANIFEST`, renames files/contents via `upstream/RENAME-MAP.sed`, applies `upstream/patches/*.patch`, and writes the result into the repo. CI re-runs the same sync in check mode so any drift between repo and (pin + patches) fails the build. Everything is plain bash + coreutils + rsync + jq, tested with bats against a tiny fixture upstream tree.

**Tech Stack:** bash ≥5, rsync, GNU sed, `file`, jq, curl, tar, bats-core, shellcheck, gitleaks, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-22-agentarchy-design.md` (sections: Repo layout, Upstream relationship, Phase 0).

## Global Constraints

- Project name **Agentarchy**; package/install root `agentarchy` (`/usr/share/agentarchy`); everything terminal-facing is `oal`: commands `oal-*`, env `OAL_*`, `~/.config/oal`, `~/.local/state/oal`, `~/.local/share/oal`.
- Upstream pin: `basecamp/omarchy` commit `2c247e390e357ae0fee3f8565b0c816adb705e6a` (branch quattro). Never vendor `shell/`, `config/hypr/`, `default/hypr/`, `default/uwsm/`, `default/wayland-sessions/`, `default/xdg-terminal-exec/`, `default/fonts/`, `docs/`, `manual/`, `plans/`, `test/`, `migrations/`, `icon.*`, `logo.*`.
- The string `omarchy` (any case) may appear only under `upstream/`, in `NOTICE`, in `docs/`, and in `tasks/`. CI enforces this.
- Licence: MIT. `NOTICE` must list every file under `themes/*/backgrounds/`.
- No secrets, IPs, hostnames, or personal identifiers in tracked files (gitleaks gate).
- All shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, pass `shellcheck -S warning`.
- Commit messages: conventional (`feat:`, `chore:`, `test:`, `ci:`, `docs:`), no AI co-author trailers.
- Working directory for every task: `<repo>`.

---

### Task 1: Repo scaffolding (licence, notice, readme, conventions)

**Files:**
- Create: `LICENSE`, `NOTICE`, `README.md`, `.editorconfig`, `.gitignore`, `CLAUDE.md`, `AGENTS.md`, `version`, `tasks/todo.md`, `tasks/lessons.md`
- Already present: `docs/superpowers/specs/2026-08-22-agentarchy-design.md`, `docs/superpowers/plans/2026-08-22-phase-0-bootstrap.md`

**Interfaces:**
- Produces: `version` file read by later `oal-version` (content `0.0.1-dev`); `tasks/todo.md` phase checklist that every later phase updates.

- [ ] **Step 1: Write LICENSE (MIT) and NOTICE**

`LICENSE`:
```
MIT License

Copyright (c) 2026 Adam (RFingAdam)

Portions of this software are derived from Omarchy, Copyright (c) David Heinemeier Hansson,
licensed under the MIT License (see NOTICE).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`NOTICE`:
```
Agentarchy — NOTICE

Agentarchy is derived from Omarchy (https://github.com/basecamp/omarchy),
Copyright (c) David Heinemeier Hansson, MIT License. Agentarchy is an
independent project and is not affiliated with or endorsed by Basecamp,
37signals, or the Omarchy project. "Omarchy" and the Omarchy logo are
not used by Agentarchy.

Upstream pin: see upstream/PIN. Vendored paths: see upstream/VENDOR-MANIFEST.
Local modifications to vendored files: see upstream/patches/.

## Theme palettes
Palette names (Catppuccin, Nord, Gruvbox, Tokyo Night, Rosé Pine, Kanagawa,
Everforest, Flexoki, ...) are used with attribution to their respective
authors; the palettes are MIT-licensed by their upstream projects.

## Wallpapers (themes/*/backgrounds)
Every file below must carry a source and licence before v0.1.0.
Status UNAUDITED means the file is vendored from upstream and its provenance
has not yet been verified. (Generated by bin/oal-dev-notice-check --update.)

<!-- BEGIN BACKGROUNDS -->
<!-- END BACKGROUNDS -->
```

- [ ] **Step 2: Write README.md**

```markdown
# Agentarchy

**Omarchy's taste. Your mouse. Your agents.**

Agentarchy is an Arch Linux distribution derived from [Omarchy](https://omarchy.org): the same
palette-driven themes, system menu, update/migration tooling and offline ISO — on a **KDE Plasma 6**
desktop you can drive with a mouse (Ubuntu-style or Mint-style layout, your pick), with a
**Claude Code / agentic engineering runtime** ready at first login.

> Status: pre-alpha. Nothing here is installable yet. Follow `tasks/todo.md` for progress.

## Why the commands are called `oal-*`

Opinions are like… — everyone's got one. Omarchy is proudly opinionated; so are we, just
differently. Every Agentarchy command starts with `oal-` (`oal-theme-set`, `oal-menu`,
`oal-update`). Config lives in `~/.config/oal`, state in `~/.local/state/oal`.

## Relationship to Omarchy

Agentarchy vendors the desktop-agnostic parts of Omarchy (quattro branch, pinned in
`upstream/PIN`) and replaces the Hyprland/Quickshell shell with KDE Plasma. It is an
independent project, not affiliated with or endorsed by Basecamp or DHH. See `NOTICE`.

## Layout

| Path | What |
|---|---|
| `bin/` | `oal-*` commands (vendored + native) |
| `install/` | system/user install steps run by `oal-apply-system` / `oal-provision-user` |
| `default/`, `config/` | system-wide and per-user defaults |
| `themes/` | colour themes (`colors.toml` + assets) |
| `upstream/` | upstream pin, vendor manifest, rename map, patches |
| `test/` | bats unit tests and the VM golden path |
| `docs/superpowers/` | design spec and per-phase implementation plans |

## Developing

```
bin/oal-dev-check          # shellcheck + bats + hygiene gates (what CI runs)
bin/oal-dev-sync-upstream  # re-vendor from upstream/PIN, show diff
```

## Licence

MIT. Derived work attribution in `NOTICE`.
```

- [ ] **Step 3: Write .editorconfig, .gitignore, version**

`.editorconfig`:
```
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

`.gitignore`:
```
# build / sync scratch
.sync/
release/
*.pkg.tar.zst
*.iso

# local state
.env
.env.*
*.age
!docs/examples/**/*.age.example
.claude/settings.local.json

# editors
.idea/
.vscode/
*.swp
```

`version`:
```
0.0.1-dev
```

- [ ] **Step 4: Write CLAUDE.md and AGENTS.md**

`CLAUDE.md`:
```markdown
# Agentarchy — instructions for Claude Code

Read first: `docs/superpowers/specs/2026-08-22-agentarchy-design.md` (approved design) and `tasks/todo.md`.

## Naming (non-negotiable)
- Project/package/install root: `agentarchy`, `/usr/share/agentarchy`.
- Everything a user types or sees in a terminal: `oal` — commands `oal-*`, env `OAL_*`,
  `~/.config/oal`, `~/.local/state/oal`, `~/.local/share/oal`.
- The word `omarchy` may only appear under `upstream/`, `docs/`, `tasks/`, and `NOTICE`.

## Vendored code
- Files listed in `upstream/VENDOR-MANIFEST` are owned by `bin/oal-dev-sync-upstream`.
  Never hand-edit them; put changes in `upstream/patches/` via `bin/oal-dev-upstream-patch`.
- Never vendor `shell/`, `config/hypr`, `default/hypr`, `default/uwsm`, branding assets.

## Workflow
- Plan mode for anything non-trivial; keep `tasks/todo.md` current; record corrections in `tasks/lessons.md`.
- Before claiming done: `bin/oal-dev-check` must pass; paste its output in the PR.
- Owner-actions (things only Adam can do) go under the "Owner-actions" heading in `tasks/todo.md`.
- Shell: `#!/usr/bin/env bash`, `set -euo pipefail`, shellcheck clean. Tests: bats under `test/unit`.
- Commits: conventional prefixes, no AI co-author trailers.
```

`AGENTS.md`:
```markdown
# AGENTS.md

Same rules as CLAUDE.md (read it). Summary for non-Claude agents:
- `oal-*` / `OAL_*` naming; `omarchy` only under upstream/, docs/, tasks/, NOTICE.
- Vendored files are regenerated by `bin/oal-dev-sync-upstream`; changes go in `upstream/patches/`.
- `bin/oal-dev-check` must pass before a PR.
```

- [ ] **Step 5: Write tasks/todo.md and tasks/lessons.md**

`tasks/todo.md`:
```markdown
# Agentarchy — todo

Design spec: docs/superpowers/specs/2026-08-22-agentarchy-design.md

## Phases
- [ ] Phase 0 — Bootstrap (plan: docs/superpowers/plans/2026-08-22-phase-0-bootstrap.md)
  - [ ] Task 1 scaffolding
  - [ ] Task 2 upstream fetch
  - [ ] Task 3 vendor manifest + rename map + sync
  - [ ] Task 4 patch workflow
  - [ ] Task 5 first real vendoring run
  - [ ] Task 6 hygiene gates + oal-dev-check
  - [ ] Task 7 GitHub Actions CI
- [ ] Phase 1 — Package + bootstrap + VM golden path
- [ ] Phase 2 — Theme engine, all 22 themes (+ wallpaper licence audit)
- [ ] Phase 3 — Layouts, shortcut parity, OAL Menu
- [ ] Phase 4 — System tooling port
- [ ] Phase 5 — Agent layer + overlay contract
- [ ] Phase 6 — ISO
- [ ] Phase 7 — Plugins, cliamp, Quickshell-compat spike, Hyprland add-on
- [ ] Phase 8 — Public release hygiene, v0.1.0

## Owner-actions (only Adam can do these)
- [ ] Create GitHub repos `RFingAdam/agentarchy` and `RFingAdam/agentarchy-iso` and decide visibility
      (private until v0.1.0 is the safe default). Blocked on you: repo ownership/visibility is your call.
- [ ] Reopen the Claude Code session in `~/projects/github/agentarchy` and `rmdir ~/projects/github/opinions-are-like`.
      Blocked on you: the running session's cwd cannot move itself.
- [ ] Create the private overlay repo (e.g. `RFingAdam/oal-overlay`, private) once Phase 5 publishes `docs/overlay.md`.
      Blocked on you: it will hold your secrets and homelab config.
- [ ] Decide ISO artifact hosting (GitHub Releases vs homelab) and whether to run a self-hosted Actions runner on Proxmox
      (Phase 6). Blocked on you: infrastructure and cost decision.
- [ ] Eyeball the two layouts from the Phase 3 VM screenshots and say which tweaks you want. Blocked on you: taste.
- [ ] Confirm the tagline "Omarchy's taste. Your mouse. Your agents." and whether a text logo is fine for v0.1.

## Review log
(appended at the end of each phase)
```

`tasks/lessons.md`:
```markdown
# Lessons

Format: `## YYYY-MM-DD — <short title>` then **Mistake**, **Why**, **Rule**.

## 2026-08-22 — Name the project seriously, keep jokes in the CLI
**Mistake:** proposed the joke ("Opinions Are Like") as the repo/project name.
**Why:** a public repo needs a name that stands alone; humour belongs in command prefixes/taglines.
**Rule:** propose serious names (check GitHub collisions), keep the joke in `oal-*`.
```

- [ ] **Step 6: Verify and commit**

Run: `cd <repo> && ls -la && grep -ril omarchy --exclude-dir=.git --exclude-dir=docs --exclude-dir=tasks --exclude=NOTICE . ; echo "exit=$?"`
Expected: files listed; grep finds only `README.md` and `CLAUDE.md`/`AGENTS.md` — those are allowed prose mentions in this task; they will be covered by the branding gate's allowlist in Task 6 (README and CLAUDE.md/AGENTS.md are added to the allowlist there because they explain the relationship).

```bash
git add -A
git commit -m "chore: scaffold Agentarchy repo (licence, notice, readme, conventions, design spec)"
```

---

### Task 2: `oal-dev-upstream-fetch` — pinned upstream tarball fetch with cache

**Files:**
- Create: `upstream/PIN`, `bin/oal-dev-upstream-fetch`, `bin/oal-dev-lib.sh`
- Test: `test/unit/upstream-fetch.bats`, `test/fixtures/upstream-mini/` (tiny fake upstream tree used by all Phase 0 tests)

**Interfaces:**
- Produces: `oal-dev-upstream-fetch [--print]` → prints the absolute path of an extracted upstream tree for the sha in `upstream/PIN`. Cache dir `${OAL_DEV_CACHE:-$HOME/.cache/agentarchy}/upstream/<sha>/`. Env override `OAL_UPSTREAM_TARBALL=<file>` uses a local tarball instead of the network (tests use it). `bin/oal-dev-lib.sh` exports `oal_dev_root()` (repo root), `oal_dev_die()`, `oal_dev_log()`.

- [ ] **Step 1: Write the fixture upstream tree and tarball builder**

Create these files (content shown) under `test/fixtures/upstream-mini/`:

`bin/omarchy-theme-set`:
```bash
#!/bin/bash
# Omarchy theme setter
THEME_DIR="$HOME/.config/omarchy/themes/$1"
STATE="$HOME/.local/state/omarchy/current"
echo "applying $1 from $OMARCHY_PATH/themes/$1 -> $STATE"
omarchy-restart-terminal
```
`bin/omarchy-hyprland-focus`:
```bash
#!/bin/bash
hyprctl dispatch focuswindow "$1"
```
`bin/omarchy-system-reboot`:
```bash
#!/bin/bash
omarchy-shell notify "Rebooting"
systemctl reboot
```
`install/config/all.sh`:
```bash
run_logged "$OMARCHY_INSTALL/config/theme-system.sh"
```
`install/omarchy-base.packages`:
```
hyprland
quickshell
sddm
ghostty
omarchy-nvim
```
`default/omarchy/omarchy-menu.jsonc`:
```
{ "system": [ { "label": "Lock", "action": "omarchy-system-lock" } ] }
```
`default/themed/ghostty.conf.tpl`:
```
background = {{background}}
```
`default/themed/shell.toml.tpl`:
```
[shell]
accent = "{{accent}}"
```
`config/hypr/hyprland.lua`:
```
-- hyprland config
```
`themes/tokyo-night/colors.toml`:
```
mode = "dark"
accent = "#7aa2f7"
```
`themes/tokyo-night/shell.lock.toml`:
```
text = "#c0caf5"
```
`themes/tokyo-night/backgrounds/1-quattro.webp` — create with `printf 'RIFF\0\0\0\0WEBPVP8 ' > file` (binary-ish content; the sed step must skip it).
`shell/shell.qml`:
```
import Quickshell
```
`LICENSE`:
```
MIT License (fixture)
```

Builder script `test/fixtures/build-upstream-mini-tarball.sh`:
```bash
#!/usr/bin/env bash
# Packs test/fixtures/upstream-mini into a GitHub-style tarball (top dir "basecamp-omarchy-<sha>") at $1.
set -euo pipefail
out="$1"; sha="${2:-2c247e390e357ae0fee3f8565b0c816adb705e6a}"
src="$(cd "$(dirname "$0")/upstream-mini" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/basecamp-omarchy-${sha:0:7}"
cp -a "$src"/. "$tmp/basecamp-omarchy-${sha:0:7}/"
tar -C "$tmp" -czf "$out" "basecamp-omarchy-${sha:0:7}"
```
`chmod +x` it and the fixture `bin/*`.

- [ ] **Step 2: Write the failing test**

`test/unit/upstream-fetch.bats`:
```bash
#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache"
  export OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
  "$REPO/test/fixtures/build-upstream-mini-tarball.sh" "$OAL_UPSTREAM_TARBALL"
  PATH="$REPO/bin:$PATH"
}

@test "fetch extracts the pinned tarball into the cache and prints the tree path" {
  run oal-dev-upstream-fetch --print
  [ "$status" -eq 0 ]
  [ -f "$output/bin/omarchy-theme-set" ]
  [[ "$output" == "$OAL_DEV_CACHE/upstream/2c247e390e357ae0fee3f8565b0c816adb705e6a" ]]
}

@test "second fetch is a cache hit and does not re-extract" {
  oal-dev-upstream-fetch --print >/dev/null
  touch "$OAL_DEV_CACHE/upstream/2c247e390e357ae0fee3f8565b0c816adb705e6a/MARKER"
  run oal-dev-upstream-fetch --print
  [ "$status" -eq 0 ]
  [ -f "$output/MARKER" ]
}

@test "fails clearly when PIN is missing" {
  run env OAL_PIN_FILE="$BATS_TEST_TMPDIR/nope" oal-dev-upstream-fetch --print
  [ "$status" -ne 0 ]
  [[ "$output" == *"upstream/PIN"* ]]
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd <repo> && bats test/unit/upstream-fetch.bats`
Expected: 3 failures, "oal-dev-upstream-fetch: command not found".

- [ ] **Step 4: Write upstream/PIN, bin/oal-dev-lib.sh and bin/oal-dev-upstream-fetch**

`upstream/PIN`:
```
2c247e390e357ae0fee3f8565b0c816adb705e6a
```

`bin/oal-dev-lib.sh`:
```bash
#!/usr/bin/env bash
# Shared helpers for bin/oal-dev-* scripts. Source, do not execute.

oal_dev_root() {
  # Repo root = directory containing upstream/PIN, walking up from this file.
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/upstream/PIN" ]] && { echo "$d"; return 0; }
    d="$(dirname "$d")"
  done
  echo "oal-dev: cannot locate repo root (no upstream/PIN above ${BASH_SOURCE[0]})" >&2
  return 1
}

oal_dev_log() { echo "oal-dev: $*" >&2; }
oal_dev_die() { echo "oal-dev: error: $*" >&2; exit 1; }
```

`bin/oal-dev-upstream-fetch`:
```bash
#!/usr/bin/env bash
# oal:summary=Fetch the pinned upstream source tree into the local cache
# Usage: oal-dev-upstream-fetch [--print]
#   --print   print the extracted tree path (default behaviour; flag kept for readability)
# Env: OAL_DEV_CACHE (default ~/.cache/agentarchy), OAL_UPSTREAM_TARBALL (use a local tarball, no network),
#      OAL_PIN_FILE (default <repo>/upstream/PIN), OAL_UPSTREAM_REPO (default basecamp/omarchy)
set -euo pipefail
# shellcheck source=bin/oal-dev-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/oal-dev-lib.sh"

root="$(oal_dev_root)" || exit 1
pin_file="${OAL_PIN_FILE:-$root/upstream/PIN}"
[[ -f "$pin_file" ]] || oal_dev_die "missing upstream/PIN ($pin_file)"
sha="$(tr -d '[:space:]' < "$pin_file")"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || oal_dev_die "upstream/PIN must be a 40-char commit sha, got '$sha'"

cache="${OAL_DEV_CACHE:-$HOME/.cache/agentarchy}/upstream"
dest="$cache/$sha"
if [[ -d "$dest" && -n "$(ls -A "$dest")" ]]; then
  echo "$dest"; exit 0
fi

mkdir -p "$cache"
tmp="$(mktemp -d "$cache/.extract.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

tarball="${OAL_UPSTREAM_TARBALL:-}"
if [[ -z "$tarball" ]]; then
  repo="${OAL_UPSTREAM_REPO:-basecamp/omarchy}"
  tarball="$tmp/src.tar.gz"
  oal_dev_log "downloading https://github.com/$repo/archive/$sha.tar.gz"
  curl -fsSL --retry 3 -o "$tarball" "https://github.com/$repo/archive/$sha.tar.gz"
fi

tar -xzf "$tarball" -C "$tmp"
# GitHub tarballs contain exactly one top-level directory.
top="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d ! -name 'src*' | head -n1)"
[[ -n "$top" ]] || oal_dev_die "tarball has no top-level directory"
mv "$top" "$dest"
echo "$dest"
```
`chmod +x bin/oal-dev-upstream-fetch`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats test/unit/upstream-fetch.bats && shellcheck -S warning bin/oal-dev-*`
Expected: `3 tests, 0 failures`; shellcheck silent.

- [ ] **Step 6: Commit**

```bash
git add upstream/PIN bin/oal-dev-lib.sh bin/oal-dev-upstream-fetch test/
git commit -m "feat(dev): pinned upstream fetch with cache and fixture upstream tree"
```

---

### Task 3: Vendor manifest, rename map and `oal-dev-sync-upstream`

**Files:**
- Create: `upstream/VENDOR-MANIFEST`, `upstream/RENAME-MAP.sed`, `upstream/EXCLUDE-BIN.regex`, `bin/oal-dev-sync-upstream`
- Test: `test/unit/sync-upstream.bats`

**Interfaces:**
- Consumes: `oal-dev-upstream-fetch --print` (Task 2), `oal_dev_root`.
- Produces: `oal-dev-sync-upstream [--check|--apply] [--stage DIR]`.
  - `--apply` (default): rebuild the vendored tree in `.sync/stage/`, apply patches (Task 4 adds this; until then the step is a no-op when `upstream/patches/` is empty), then rsync the vendored top-level paths into the repo (`--delete` only inside vendored paths), and write `upstream/EXCLUDED-BIN.txt` + `upstream/NEEDS-PORT.txt`.
  - `--check`: same build into stage, then `diff -r` stage vs repo for vendored paths; exit 1 on any difference (used by CI vendor-drift).
  - Manifest format: one entry per line; `include <glob>` or `exclude <glob>` (globs relative to upstream root, evaluated with `find -path`; later lines win). Comments `#`.
  - Vendored top-level paths (the set rsync owns): `bin/`, `install/`, `default/`, `config/`, `themes/`, `applications/`, `agents/`. Files in those dirs that are **not** produced by the sync are preserved only if listed in `upstream/LOCAL-KEEP` (one glob per line) — Phase 1+ native files live there; the default `LOCAL-KEEP` contains `bin/oal-dev-*`, `bin/oal-dev-lib.sh`.

- [ ] **Step 1: Write the manifest, rename map and bin exclusion regex**

`upstream/VENDOR-MANIFEST`:
```
# Paths (globs relative to upstream root) vendored by bin/oal-dev-sync-upstream.
# Later lines win. Everything not included is ignored.

include bin/omarchy-*
include install/**
include default/**
include config/**
include themes/**
include applications/**
include agents/**

# --- never vendor: compositor/shell-bound, docs, branding, tests, upstream migrations
exclude shell/**
exclude config/hypr/**
exclude config/hyprland-preview-share-picker/**
exclude config/omarchy/shell.json
exclude default/hypr/**
exclude default/uwsm/**
exclude default/wayland-sessions/**
exclude default/xdg-terminal-exec/**
exclude default/libalpm/hooks/*hyprland*
exclude default/fonts/**
exclude default/voxtype/**
exclude default/themed/hyprland.lua.tpl
exclude default/themed/hyprland-preview-share-picker.css.tpl
exclude default/themed/shell.toml.tpl
exclude themes/*/shell.lock.toml
exclude default/sddm/**/*.png
```

`upstream/RENAME-MAP.sed` (applied to text files only; order matters):
```sed
# paths
s#/usr/share/omarchy#/usr/share/agentarchy#g
s#\.config/omarchy#.config/oal#g
s#\.local/state/omarchy#.local/state/oal#g
s#\.local/share/omarchy#.local/share/oal#g
s#\.cache/omarchy#.cache/oal#g
s#/etc/omarchy#/etc/oal#g
# env vars and commands
s#OMARCHY_#OAL_#g
s#omarchy-#oal-#g
# bare command / package / namespace word
s#\bomarchy\b#oal#g
# prose
s#Omarchy#Agentarchy#g
s#OMARCHY#AGENTARCHY#g
```

`upstream/EXCLUDE-BIN.regex` (ERE; a `bin/` script whose content matches is not vendored):
```
hyprctl|[Hh]yprland|hypridle|hyprlock|hyprsunset|hyprpicker|uwsm|quickshell|(^|[^a-z])qs( |$)|omarchy-shell-config|omarchy-plugin-|omarchy-launch-
```
and `upstream/NEEDS-PORT.regex` (vendored, but flagged for Phase 4 work):
```
omarchy-shell|grim|slurp|wtype|gsettings|nautilus|walker|swayosd
```

`upstream/LOCAL-KEEP`:
```
bin/oal-dev-*
bin/oal-dev-lib.sh
```

- [ ] **Step 2: Write the failing tests**

`test/unit/sync-upstream.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # Work on a throwaway copy of the repo so --apply cannot touch the real tree.
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cp -a "$SRC/bin" "$SRC/upstream" "$SRC/test" "$REPO/"
  export OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache"
  export OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
  "$REPO/test/fixtures/build-upstream-mini-tarball.sh" "$OAL_UPSTREAM_TARBALL"
  PATH="$REPO/bin:$PATH"
  cd "$REPO"
}

@test "apply vendors agnostic files with renamed names and contents" {
  run oal-dev-sync-upstream --apply
  [ "$status" -eq 0 ]
  [ -f bin/oal-theme-set ]
  run cat bin/oal-theme-set
  [[ "$output" == *'$HOME/.config/oal/themes/$1'* ]]
  [[ "$output" == *'$HOME/.local/state/oal/current'* ]]
  [[ "$output" == *'$OAL_PATH/themes/$1'* ]]
  [[ "$output" == *'oal-restart-terminal'* ]]
  [[ "$output" == *'# Agentarchy theme setter'* ]]
  [[ "$output" != *omarchy* ]]
}

@test "apply excludes compositor-bound bin scripts and records them" {
  oal-dev-sync-upstream --apply
  [ ! -e bin/oal-hyprland-focus ]
  grep -q '^bin/omarchy-hyprland-focus' upstream/EXCLUDED-BIN.txt
}

@test "apply keeps soft-dependent scripts but lists them in NEEDS-PORT" {
  oal-dev-sync-upstream --apply
  [ -f bin/oal-system-reboot ]
  grep -q '^bin/oal-system-reboot' upstream/NEEDS-PORT.txt
}

@test "apply honours path excludes and renames directories" {
  oal-dev-sync-upstream --apply
  [ ! -e config/hypr ]
  [ ! -e themes/tokyo-night/shell.lock.toml ]
  [ ! -e default/themed/shell.toml.tpl ]
  [ -f default/themed/ghostty.conf.tpl ]
  [ -f default/oal/oal-menu.jsonc ]
  [ ! -e default/omarchy ]
  [ -f install/oal-base.packages ]
  run cat install/config/all.sh
  [[ "$output" == *'$OAL_INSTALL/config/theme-system.sh'* ]]
}

@test "binary assets are copied byte-for-byte (sed skipped)" {
  oal-dev-sync-upstream --apply
  cmp themes/tokyo-night/backgrounds/1-quattro.webp \
      "$OAL_DEV_CACHE/upstream/2c247e390e357ae0fee3f8565b0c816adb705e6a/themes/tokyo-night/backgrounds/1-quattro.webp"
}

@test "check passes right after apply and fails after a hand edit" {
  oal-dev-sync-upstream --apply
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
  echo "# hand edit" >> bin/oal-theme-set
  run oal-dev-sync-upstream --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/oal-theme-set"* ]]
}

@test "LOCAL-KEEP files survive apply" {
  echo 'echo native' > bin/oal-dev-native-thing; chmod +x bin/oal-dev-native-thing
  oal-dev-sync-upstream --apply
  [ -f bin/oal-dev-native-thing ]
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bats test/unit/sync-upstream.bats`
Expected: all 7 fail with "oal-dev-sync-upstream: command not found".

- [ ] **Step 4: Write bin/oal-dev-sync-upstream**

```bash
#!/usr/bin/env bash
# oal:summary=Re-vendor upstream (pinned in upstream/PIN) under the oal-* naming
# Usage: oal-dev-sync-upstream [--apply|--check] [--stage DIR]
#   --apply  (default) rebuild stage and write vendored paths into the repo
#   --check  rebuild stage and diff against the repo; exit 1 on drift (CI gate)
set -euo pipefail
# shellcheck source=bin/oal-dev-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/oal-dev-lib.sh"

mode=apply; stage=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) mode=apply ;;
    --check) mode=check ;;
    --stage) stage="$2"; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) oal_dev_die "unknown argument: $1" ;;
  esac
  shift
done

root="$(oal_dev_root)" || exit 1
cd "$root"
src="$(oal-dev-upstream-fetch --print)"
manifest="upstream/VENDOR-MANIFEST"
rename="upstream/RENAME-MAP.sed"
exclude_re="$(cat upstream/EXCLUDE-BIN.regex)"
needsport_re="$(cat upstream/NEEDS-PORT.regex)"
vendored_tops=(bin install default config themes applications agents)

stage="${stage:-$root/.sync/stage}"
rm -rf "$stage"; mkdir -p "$stage"

# ---- 1. select files per manifest (later lines win) -------------------------------------------
# Build the candidate list once, then walk the manifest in order keeping a verdict per file.
mapfile -t all_files < <(cd "$src" && find . -type f | sed 's#^\./##' | sort)
declare -A verdict
glob_to_re() {  # manifest glob -> ERE anchored on whole path; ** matches across /, * within a segment
  local g="$1"
  g="${g//./\\.}"
  g="${g//\*\*/__DS__}"
  g="${g//\*/[^/]*}"
  g="${g//__DS__/.*}"
  echo "^${g}$"
}
while read -r kind glob; do
  [[ -z "$kind" || "$kind" == \#* ]] && continue
  re="$(glob_to_re "$glob")"
  for f in "${all_files[@]}"; do
    [[ "$f" =~ $re ]] && verdict["$f"]="$kind"
  done
done < "$manifest"

# ---- 2. copy, rename paths, rewrite text, classify bin/ ---------------------------------------
: > "$stage/.excluded-bin"; : > "$stage/.needs-port"
rename_path() {  # omarchy-* -> oal-*, directory/file named omarchy -> oal
  local p="$1"
  p="${p//omarchy-/oal-}"
  p="$(echo "$p" | sed -E 's#(^|/)omarchy(/|$)#\1oal\2#g')"
  echo "$p"
}
for f in "${all_files[@]}"; do
  [[ "${verdict[$f]:-}" == include ]] || continue
  if [[ "$f" == bin/* ]] && grep -Eq "$exclude_re" "$src/$f"; then
    echo "$f" >> "$stage/.excluded-bin"; continue
  fi
  dst="$stage/$(rename_path "$f")"
  mkdir -p "$(dirname "$dst")"
  if file -b --mime "$src/$f" | grep -q 'charset=binary'; then
    cp -p "$src/$f" "$dst"
  else
    sed -E -f "$rename" "$src/$f" > "$dst"
    chmod --reference="$src/$f" "$dst"
    if grep -Eq "$needsport_re" "$src/$f"; then
      echo "$(rename_path "$f")" >> "$stage/.needs-port"
    fi
  fi
done

# ---- 3. local patches (upstream/patches/*.patch, applied in name order) -----------------------
if compgen -G "upstream/patches/*.patch" >/dev/null; then
  for p in upstream/patches/*.patch; do
    oal_dev_log "applying $p"
    patch -p1 -d "$stage" --no-backup-if-mismatch -s < "$p" || oal_dev_die "patch failed: $p"
  done
fi

# ---- 4. reports ------------------------------------------------------------------------------
sort -u "$stage/.excluded-bin" > "$stage/EXCLUDED-BIN.txt"
sort -u "$stage/.needs-port"   > "$stage/NEEDS-PORT.txt"
rm -f "$stage/.excluded-bin" "$stage/.needs-port"

# ---- 5. apply or check ------------------------------------------------------------------------
keep_args=()
while read -r g; do
  [[ -z "$g" || "$g" == \#* ]] && continue
  keep_args+=(--exclude "$g")
done < upstream/LOCAL-KEEP

drift=0
for top in "${vendored_tops[@]}"; do
  [[ -d "$stage/$top" ]] || continue
  if [[ "$mode" == apply ]]; then
    rsync -a --delete "${keep_args[@]}" "$stage/$top/" "$root/$top/"
  else
    if ! diff -rq "${keep_args[@]/--exclude/--exclude=}" "$stage/$top" "$root/$top" >"$stage/.diff.$top" 2>&1; then
      drift=1; cat "$stage/.diff.$top"
    fi
  fi
done
if [[ "$mode" == apply ]]; then
  cp "$stage/EXCLUDED-BIN.txt" upstream/EXCLUDED-BIN.txt
  cp "$stage/NEEDS-PORT.txt"   upstream/NEEDS-PORT.txt
  oal_dev_log "vendored $(find "$stage" -type f ! -name '*.txt' | wc -l) files; excluded $(wc -l < upstream/EXCLUDED-BIN.txt) bin scripts; $(wc -l < upstream/NEEDS-PORT.txt) need porting"
else
  for r in EXCLUDED-BIN.txt NEEDS-PORT.txt; do
    cmp -s "$stage/$r" "upstream/$r" || { drift=1; echo "upstream/$r differs from regenerated report"; }
  done
  [[ $drift -eq 0 ]] && oal_dev_log "no vendor drift" || oal_dev_die "vendor drift detected (run oal-dev-sync-upstream --apply, or capture your change as a patch with oal-dev-upstream-patch)"
fi
```
`chmod +x bin/oal-dev-sync-upstream`.

Note on `--exclude` handling in the check branch: `diff -r` takes `--exclude=PATTERN` (basename patterns). Because LOCAL-KEEP globs are `bin/oal-dev-*` style, convert them with `basename` when building the diff args: replace the line `diff -rq "${keep_args[@]/--exclude/--exclude=}"` with:
```bash
    diff_ex=(); for g in "${keep_args[@]}"; do [[ "$g" == --exclude ]] && continue; diff_ex+=("--exclude=$(basename "$g")"); done
    if ! diff -rq "${diff_ex[@]}" "$stage/$top" "$root/$top" >"$stage/.diff.$top" 2>&1; then
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats test/unit/sync-upstream.bats && shellcheck -S warning bin/oal-dev-sync-upstream`
Expected: `7 tests, 0 failures`. If `binary assets` test fails because `file` reports `charset=us-ascii` for the fake webp, make the fixture genuinely binary: `printf 'RIFF\x00\x00\x00\x00WEBPVP8 \x00\xff\xfe' > themes/tokyo-night/backgrounds/1-quattro.webp`.

- [ ] **Step 6: Commit**

```bash
git add upstream/ bin/oal-dev-sync-upstream test/unit/sync-upstream.bats test/fixtures
git commit -m "feat(dev): vendor manifest, rename map and oal-dev-sync-upstream with drift check"
```

---

### Task 4: Patch workflow — `oal-dev-upstream-patch`

**Files:**
- Create: `bin/oal-dev-upstream-patch`, `upstream/patches/README.md`
- Test: `test/unit/upstream-patch.bats`

**Interfaces:**
- Consumes: `oal-dev-sync-upstream --stage DIR --check` (builds a pristine stage without applying to repo).
- Produces: `oal-dev-upstream-patch <name> <vendored-file>...` → writes `upstream/patches/NNNN-<name>.patch` (next free 4-digit number) containing `diff -u` of pristine-renamed stage vs the current repo file(s), then verifies `oal-dev-sync-upstream --check` passes.

- [ ] **Step 1: Write the failing test**

`test/unit/upstream-patch.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REPO="$BATS_TEST_TMPDIR/repo"; mkdir -p "$REPO"
  cp -a "$SRC/bin" "$SRC/upstream" "$SRC/test" "$REPO/"
  export OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache"
  export OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
  "$REPO/test/fixtures/build-upstream-mini-tarball.sh" "$OAL_UPSTREAM_TARBALL"
  PATH="$REPO/bin:$PATH"
  cd "$REPO"
  oal-dev-sync-upstream --apply
}

@test "a hand edit captured as a patch makes --check pass and survives re-apply" {
  sed -i 's/^hyprland$/# removed: hyprland/' install/oal-base.packages
  run oal-dev-upstream-patch drop-hyprland install/oal-base.packages
  [ "$status" -eq 0 ]
  [ -f upstream/patches/0001-drop-hyprland.patch ]
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
  oal-dev-sync-upstream --apply
  grep -q '^# removed: hyprland' install/oal-base.packages
}

@test "second patch gets the next number" {
  echo '# note' >> config/README.md 2>/dev/null || echo '# note' > install/README.md
  oal-dev-upstream-patch one install/README.md || true
  sed -i 's/^quickshell$/# removed: quickshell/' install/oal-base.packages
  run oal-dev-upstream-patch two install/oal-base.packages
  [ "$status" -eq 0 ]
  ls upstream/patches/ | grep -q '^0002-two.patch$'
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats test/unit/upstream-patch.bats`
Expected: 2 failures, command not found.

- [ ] **Step 3: Write bin/oal-dev-upstream-patch and the README**

```bash
#!/usr/bin/env bash
# oal:summary=Capture local edits to vendored files as a numbered patch under upstream/patches
# Usage: oal-dev-upstream-patch <name> <vendored-file>...
set -euo pipefail
# shellcheck source=bin/oal-dev-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/oal-dev-lib.sh"

[[ $# -ge 2 ]] || { sed -n '2,3p' "$0"; exit 2; }
name="$1"; shift
[[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || oal_dev_die "name must be kebab-case"
root="$(oal_dev_root)" || exit 1
cd "$root"
mkdir -p upstream/patches

# Pristine stage = upstream renamed + existing patches, without touching the repo.
stage="$root/.sync/pristine"
oal-dev-sync-upstream --check --stage "$stage" >/dev/null 2>&1 || true   # drift expected; we only need the stage

n="$(find upstream/patches -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.patch' | wc -l)"
num="$(printf '%04d' $((n + 1)))"
out="upstream/patches/$num-$name.patch"

: > "$out"
for f in "$@"; do
  [[ -f "$f" ]] || oal_dev_die "not a file: $f"
  [[ -f "$stage/$f" ]] || oal_dev_die "$f is not a vendored file (missing from pristine stage)"
  # diff exits 1 when files differ; that is the expected case.
  diff -u --label "a/$f" --label "b/$f" "$stage/$f" "$f" >> "$out" || true
done
[[ -s "$out" ]] || { rm -f "$out"; oal_dev_die "no differences found for: $*"; }

oal_dev_log "wrote $out"
oal-dev-sync-upstream --check
```
`chmod +x bin/oal-dev-upstream-patch`.

`upstream/patches/README.md`:
```markdown
# upstream/patches

Numbered `NNNN-<name>.patch` files applied (in order, `patch -p1`) on top of the renamed upstream tree by
`bin/oal-dev-sync-upstream`. Never hand-edit vendored files without capturing the change here:

    # edit the vendored file, then
    bin/oal-dev-upstream-patch <kebab-name> <file>...

CI runs `oal-dev-sync-upstream --check`; uncaptured edits fail the build. When bumping `upstream/PIN`, re-run
`--apply`; a patch that no longer applies must be regenerated (delete it, re-do the edit, re-capture).
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats test/unit/upstream-patch.bats && shellcheck -S warning bin/oal-dev-upstream-patch`
Expected: `2 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/oal-dev-upstream-patch upstream/patches/README.md test/unit/upstream-patch.bats
git commit -m "feat(dev): capture edits to vendored files as numbered patches"
```

---

### Task 5: First real vendoring run

**Files:**
- Create/modify: `bin/oal-*` (vendored), `install/`, `default/`, `config/`, `themes/`, `applications/`, `agents/`, `upstream/EXCLUDED-BIN.txt`, `upstream/NEEDS-PORT.txt`
- Possibly: `upstream/EXCLUDE-BIN.regex`, `upstream/VENDOR-MANIFEST` (tuning after reviewing the reports)

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces: the vendored tree every later phase builds on; `upstream/EXCLUDED-BIN.txt` (≈100–110 lines expected) and `upstream/NEEDS-PORT.txt`.

- [ ] **Step 1: Run the real sync (network)**

Run: `unset OAL_UPSTREAM_TARBALL; bin/oal-dev-sync-upstream --apply 2>&1 | tail -5`
Expected: log line like `vendored N files; excluded ~105 bin scripts; ~40 need porting`. Download is ~60 MB (themes/backgrounds).

- [ ] **Step 2: Review the reports against the design spec**

Run: `wc -l upstream/EXCLUDED-BIN.txt upstream/NEEDS-PORT.txt; grep -c . upstream/EXCLUDED-BIN.txt; ls bin | wc -l; du -sh themes`
Then spot-check:
- `grep -E 'omarchy-(update|migrate|snapshot|pkg-|install-|hw-|theme-)' upstream/EXCLUDED-BIN.txt` — expected: only `omarchy-hw-touchpad`, `omarchy-hw-touchscreen`, `omarchy-install-preinstalls`, `omarchy-install-service-sunshine`, `omarchy-update-restart`, `omarchy-update-status` and theme scripts that drive the shell. If `omarchy-theme-set` itself is excluded (it calls `omarchy-shell` AND may mention `hyprctl` via `omarchy-restart-hyprctl`), that is wrong for our purposes: add a line `omarchy-theme-set` to a new allowlist file `upstream/FORCE-INCLUDE-BIN` and make the sync honour it (a script listed there is vendored even if it matches the exclude regex, and is added to NEEDS-PORT). Implement by changing the exclusion test in `oal-dev-sync-upstream` to:
  ```bash
  if [[ "$f" == bin/* ]] && ! grep -qx "$(basename "$f")" upstream/FORCE-INCLUDE-BIN 2>/dev/null && grep -Eq "$exclude_re" "$src/$f"; then
  ```
  and add a bats case in `test/unit/sync-upstream.bats`:
  ```bash
  @test "FORCE-INCLUDE-BIN overrides the exclusion regex" {
    echo omarchy-hyprland-focus > upstream/FORCE-INCLUDE-BIN
    oal-dev-sync-upstream --apply
    [ -f bin/oal-hyprland-focus ]
    grep -q '^bin/oal-hyprland-focus' upstream/NEEDS-PORT.txt
  }
  ```
  Expected initial `FORCE-INCLUDE-BIN` content: `omarchy-theme-set`, `omarchy-theme-set-templates`, `omarchy-theme-next`, `omarchy-theme-menu`, `omarchy-theme-install`, `omarchy-theme-remove`, `omarchy-restart-terminal`, `omarchy-menu` (data-format reference; will be rewritten in Phase 3), `omarchy-system-lock`, `omarchy-system-logout`, `omarchy-system-reboot`, `omarchy-system-shutdown`.
- `grep -il 'hypr\|quickshell' install/ -r` — expected: only the `.packages` files (fixed in Phase 1) and maybe `install/config/enable-services.sh`. Anything else → add to NEEDS-PORT by extending `upstream/NEEDS-PORT.regex` with `hypr` for non-bin paths (bin already excludes).
- `git status --short | grep -v '^??' ` should be empty (sync must only add files on a first run).

- [ ] **Step 3: Run the full unit suite and the check mode**

Run: `bats test/unit && bin/oal-dev-sync-upstream --check`
Expected: all green; `no vendor drift`.

- [ ] **Step 4: Commit the vendored tree**

```bash
git add -A
git commit -m "feat: vendor desktop-agnostic Omarchy tree at upstream/PIN under oal-* naming"
```
(Single large commit is intended; later phases change vendored files only via patches.)

---

### Task 6: Hygiene gates and `oal-dev-check`

**Files:**
- Create: `bin/oal-dev-check`, `bin/oal-dev-notice-check`, `bin/oal-dev-branding-check`, `.gitleaks.toml`
- Modify: `NOTICE` (populated BACKGROUNDS block)
- Test: `test/unit/hygiene.bats`

**Interfaces:**
- Produces: `oal-dev-check` (exit 0 = all gates pass; prints one line per gate), `oal-dev-notice-check [--update] [--strict]`, `oal-dev-branding-check`.
- Branding allowlist (paths where `omarchy` may appear): `upstream/`, `docs/`, `tasks/`, `NOTICE`, `README.md`, `CLAUDE.md`, `AGENTS.md`, `test/fixtures/`, `test/unit/`, `.github/`.

- [ ] **Step 1: Write the failing tests**

`test/unit/hygiene.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REPO="$BATS_TEST_TMPDIR/repo"; mkdir -p "$REPO"
  cp -a "$SRC/bin" "$SRC/upstream" "$SRC/NOTICE" "$REPO/"
  mkdir -p "$REPO/themes/t1/backgrounds" "$REPO/docs"
  printf 'x' > "$REPO/themes/t1/backgrounds/1-a.webp"
  printf 'y' > "$REPO/themes/t1/backgrounds/2-b.jpg"
  PATH="$REPO/bin:$PATH"
  cd "$REPO"; git init -q
}

@test "notice-check --update lists every background as UNAUDITED and then passes" {
  run oal-dev-notice-check
  [ "$status" -eq 1 ]
  oal-dev-notice-check --update
  grep -q 'themes/t1/backgrounds/1-a.webp | UNAUDITED' NOTICE
  grep -q 'themes/t1/backgrounds/2-b.jpg | UNAUDITED' NOTICE
  run oal-dev-notice-check
  [ "$status" -eq 0 ]
}

@test "notice-check --strict fails while any file is UNAUDITED" {
  oal-dev-notice-check --update
  run oal-dev-notice-check --strict
  [ "$status" -eq 1 ]
  sed -i 's#themes/t1/backgrounds/1-a.webp | UNAUDITED#themes/t1/backgrounds/1-a.webp | CC0 | https://example.org/a#' NOTICE
  sed -i 's#themes/t1/backgrounds/2-b.jpg | UNAUDITED#themes/t1/backgrounds/2-b.jpg | CC0 | https://example.org/b#' NOTICE
  run oal-dev-notice-check --strict
  [ "$status" -eq 0 ]
}

@test "branding-check fails on omarchy outside the allowlist and passes inside it" {
  mkdir -p bin config
  echo 'echo omarchy' > bin/oal-bad
  run oal-dev-branding-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/oal-bad"* ]]
  rm bin/oal-bad
  echo 'omarchy is upstream' > docs/compat.md
  run oal-dev-branding-check
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats test/unit/hygiene.bats`
Expected: 3 failures, command not found.

- [ ] **Step 3: Write the three scripts and .gitleaks.toml**

`bin/oal-dev-notice-check`:
```bash
#!/usr/bin/env bash
# oal:summary=Ensure every themes/*/backgrounds file is listed in NOTICE (with --strict: audited)
# Usage: oal-dev-notice-check [--update] [--strict]
set -euo pipefail
# shellcheck source=bin/oal-dev-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/oal-dev-lib.sh"
update=0; strict=0
for a in "$@"; do case "$a" in --update) update=1 ;; --strict) strict=1 ;; *) oal_dev_die "unknown arg $a" ;; esac; done
root="$(oal_dev_root)" || exit 1; cd "$root"

mapfile -t files < <(find themes -type f -path '*/backgrounds/*' 2>/dev/null | sort)
begin='<!-- BEGIN BACKGROUNDS -->'; end='<!-- END BACKGROUNDS -->'
grep -q "$begin" NOTICE && grep -q "$end" NOTICE || oal_dev_die "NOTICE lacks the BACKGROUNDS markers"

if [[ $update -eq 1 ]]; then
  # Preserve existing audited lines; add UNAUDITED lines for new files; drop lines for removed files.
  declare -A existing
  while IFS= read -r line; do
    [[ "$line" == themes/* ]] || continue
    existing["${line%% |*}"]="$line"
  done < <(sed -n "/$begin/,/$end/p" NOTICE)
  {
    sed "/$begin/q" NOTICE
    for f in "${files[@]}"; do echo "${existing[$f]:-$f | UNAUDITED}"; done
    sed -n "/$end/,\$p" NOTICE
  } > NOTICE.new && mv NOTICE.new NOTICE
fi

rc=0
for f in "${files[@]}"; do
  line="$(grep -F "$f |" NOTICE || true)"
  if [[ -z "$line" ]]; then echo "NOTICE missing: $f"; rc=1
  elif [[ $strict -eq 1 && "$line" == *"| UNAUDITED"* ]]; then echo "UNAUDITED: $f"; rc=1; fi
done
[[ $rc -eq 0 ]] && oal_dev_log "notice ok (${#files[@]} backgrounds)"
exit $rc
```

`bin/oal-dev-branding-check`:
```bash
#!/usr/bin/env bash
# oal:summary=Fail if the word omarchy appears outside the documented allowlist
set -euo pipefail
# shellcheck source=bin/oal-dev-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/oal-dev-lib.sh"
root="$(oal_dev_root)" || exit 1; cd "$root"
allow=(upstream docs tasks NOTICE README.md CLAUDE.md AGENTS.md test/fixtures test/unit .github .sync)
args=(); for a in "${allow[@]}"; do args+=(--exclude-dir="$a" --exclude="$a"); done
if hits="$(grep -rIil --exclude-dir=.git "${args[@]}" 'omarchy' . 2>/dev/null)"; then
  echo "branding: 'omarchy' found outside allowlist:"; echo "$hits"; exit 1
fi
oal_dev_log "branding ok"
```

`bin/oal-dev-check`:
```bash
#!/usr/bin/env bash
# oal:summary=Run every local quality gate (what CI runs)
set -euo pipefail
# shellcheck source=bin/oal-dev-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/oal-dev-lib.sh"
root="$(oal_dev_root)" || exit 1; cd "$root"
fail=0
gate() { local name="$1"; shift; if "$@"; then echo "PASS $name"; else echo "FAIL $name"; fail=1; fi; }

gate shellcheck   bash -c 'find bin install -type f -exec grep -lE "^#!.*(ba)?sh" {} + | xargs -r shellcheck -S warning -x'
gate bats         bats test/unit
gate branding     bin/oal-dev-branding-check
gate notice       bin/oal-dev-notice-check
gate gitleaks     gitleaks detect --no-banner --redact --source . -c .gitleaks.toml
gate vendor-drift bin/oal-dev-sync-upstream --check
exit $fail
```

`.gitleaks.toml`:
```toml
[extend]
useDefault = true

[allowlist]
description = "Agentarchy allowlist"
paths = [
  '''test/fixtures/.*''',
  '''themes/.*/backgrounds/.*''',
]
```

`chmod +x bin/oal-dev-check bin/oal-dev-notice-check bin/oal-dev-branding-check`.

- [ ] **Step 4: Run tests, populate NOTICE, run the full gate**

Run:
```
bats test/unit/hygiene.bats
bin/oal-dev-notice-check --update && grep -c UNAUDITED NOTICE
bin/oal-dev-check
```
Expected: `3 tests, 0 failures`; UNAUDITED count equals the number of background files (≈100); `oal-dev-check` prints six `PASS` lines. Likely first-run failures and their fixes:
- `shellcheck` warnings in vendored scripts → do **not** edit them; add `-e SC2154,SC1091` to the shellcheck gate only if the warnings are the vendored `run_logged`/sourced-file kind. Anything else is a real finding: capture the fix as a patch (`oal-dev-upstream-patch shellcheck-<script> bin/<script>`).
- `gitleaks` hits in vendored files (e.g. example tokens in chromium policies) → add the specific path to `.gitleaks.toml` allowlist with a comment, never a blanket rule.
- `branding` hits in vendored text (e.g. URLs `omarchy.org`, `learn.omacom.io`) → these are allowed to stay only inside `docs/`; for vendored files add a sed line to `RENAME-MAP.sed` mapping the URL to `https://github.com/RFingAdam/agentarchy` and re-run `--apply`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "ci: local quality gates (shellcheck, bats, branding, notice, gitleaks, vendor drift)"
```

---

### Task 7: GitHub Actions CI

**Files:**
- Create: `.github/workflows/check.yml`, `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`

**Interfaces:**
- Consumes: `bin/oal-dev-check` (Task 6); network access to GitHub for `oal-dev-upstream-fetch`.

- [ ] **Step 1: Write the workflow**

`.github/workflows/check.yml`:
```yaml
name: check
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read
jobs:
  check:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Install tools
        run: |
          sudo apt-get update -q
          sudo apt-get install -y -q shellcheck bats rsync file jq
          curl -fsSL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz \
            | sudo tar -xz -C /usr/local/bin gitleaks
      - name: Cache upstream tarball
        uses: actions/cache@v4
        with:
          path: ~/.cache/agentarchy/upstream
          key: upstream-${{ hashFiles('upstream/PIN') }}
      - name: Run gates
        run: bin/oal-dev-check
      - name: Full-history secret scan
        run: gitleaks detect --no-banner --redact --source . -c .gitleaks.toml --log-opts="--all"
```

`.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: monthly
```

`.github/PULL_REQUEST_TEMPLATE.md`:
```markdown
## What

## Why

## Verification
Paste the output of `bin/oal-dev-check` and, for phases ≥1, the VM golden-path result.

## Checklist
- [ ] vendored files changed only via `upstream/patches/`
- [ ] `tasks/todo.md` updated
- [ ] no `omarchy` outside the allowlist, no secrets, NOTICE updated for new assets
```

- [ ] **Step 2: Validate YAML locally and commit**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/check.yml')); print('yaml ok')"` (install `python3-yaml` if missing) and `bin/oal-dev-check`.
Expected: `yaml ok`; six PASS lines.

```bash
git add .github
git commit -m "ci: GitHub Actions running oal-dev-check and a full-history secret scan"
```

- [ ] **Step 3: Close out Phase 0 in tasks/todo.md**

Tick Phase 0 tasks 1–7 in `tasks/todo.md`, append under "Review log":
```
### Phase 0 — <date>
- vendored: <N> files, excluded <M> bin scripts, <K> need porting (upstream/NEEDS-PORT.txt)
- gates: oal-dev-check PASS x6 (paste)
- open: owner-actions above (GitHub repos not created yet; CI runs once pushed)
```
Commit: `git commit -am "docs: close Phase 0 in tasks/todo.md"`.

---

## Self-review (done while writing)

- Spec coverage: Phase 0 items in the spec — repo creation ✔ (Task 1), LICENSE/NOTICE/README/CLAUDE.md/AGENTS.md/
  tasks/.editorconfig/.gitignore ✔ (Task 1), design spec copied ✔ (pre-existing), PIN/VENDOR-MANIFEST/RENAME-MAP/
  sync script ✔ (Tasks 2–3), patch series ✔ (Task 4), first vendoring ✔ (Task 5), CI gates shellcheck/bats/
  gitleaks/vendor-drift/branding-grep/notice-check ✔ (Tasks 6–7).
- Placeholders: none; every script and test is given in full.
- Name consistency: `oal-dev-upstream-fetch --print`, `oal-dev-sync-upstream --apply|--check [--stage]`,
  `oal-dev-upstream-patch <name> <file>...`, `oal-dev-notice-check [--update] [--strict]`,
  `oal-dev-branding-check`, `oal-dev-check`, `oal_dev_root/log/die` used consistently across tasks.
