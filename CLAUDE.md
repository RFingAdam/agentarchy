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
