# Agentarchy — todo

Design spec: docs/superpowers/specs/2026-08-22-agentarchy-design.md

## Phases
- [x] Phase 0 — Bootstrap (plan: docs/superpowers/plans/2026-08-22-phase-0-bootstrap.md)
  - [x] Task 1 scaffolding
  - [x] Task 2 upstream fetch
  - [x] Task 3 vendor manifest + rename map + sync
  - [x] Task 4 patch workflow
  - [x] Task 5 first real vendoring run
  - [x] Task 6 hygiene gates + oal-dev-check
  - [x] Task 7 GitHub Actions CI
- [ ] Phase 1 — Package + bootstrap + VM golden path
  - [ ] Replace the six `default/pacman/*` files (mirrorlist-edge/rc/stable, pacman-edge/rc/stable.conf) —
        the rename map pointed every upstream repo host at `*.agentarchy.invalid`, which by design never
        resolves, so the VM golden path dies at the first `pacman -Sy` until they name a real repo (or the
        files are dropped and stock Arch mirrors are used).
  - [ ] PKGBUILD must not link `bin/oal-dev-*` or `bin/oal-dev-lib.sh` into `/usr/bin` — they are repo
        tooling (they look for `upstream/PIN` above themselves) and have no meaning on an installed system.
  - [ ] Supply the Phase 1 replacements listed in `upstream/EXCLUDED-ASSETS.md` (SDDM/Plymouth logo,
        `logo.txt`, Chromium extension icons, the Plasma greeter session in `etc/sddm.conf.d/`).
- [ ] Phase 2 — Theme engine, all 22 themes (+ wallpaper licence audit)
- [ ] Phase 3 — Layouts, shortcut parity, OAL Menu
- [ ] Phase 4 — System tooling port
- [ ] Phase 5 — Agent layer + overlay contract
- [ ] Phase 6 — ISO
- [ ] Phase 7 — Plugins, cliamp, Quickshell-compat spike, Hyprland add-on
- [ ] Phase 8 — Public release hygiene, v0.1.0

## Owner-actions (only Adam can do these)
- [~] Create GitHub repos `RFingAdam/agentarchy` and `RFingAdam/agentarchy-iso` and decide visibility
      Status 2026-08-23: `RFingAdam/agentarchy` created **private** and `main` pushed (d9c2190). Still yours: `agentarchy-iso` repo, and flipping to public only after the Phase 2 wallpaper/icon audit.
      (private until v0.1.0 is the safe default). Blocked on you: repo ownership/visibility is your call.
      **Keep it private until the Phase 2 wallpaper + application-icon audit is finished** (see NOTICE):
      git history is permanent, so an unlicensed asset pushed once is pushed forever.
- [ ] Reopen the Claude Code session in `~/projects/github/agentarchy` and `rmdir ~/projects/github/opinions-are-like`.
      Blocked on you: the running session's cwd cannot move itself.
- [ ] Create the private overlay repo (e.g. `RFingAdam/oal-overlay`, private) once Phase 5 publishes `docs/overlay.md`.
      Blocked on you: it will hold your secrets and homelab config.
- [ ] Decide ISO artifact hosting (GitHub Releases vs homelab) and whether to run a self-hosted Actions runner on Proxmox
      (Phase 6). Blocked on you: infrastructure and cost decision.
- [ ] Eyeball the two layouts from the Phase 3 VM screenshots and say which tweaks you want. Blocked on you: taste.
- [ ] Confirm the tagline "Omarchy's taste. Your mouse. Your agents." and whether a text logo is fine for v0.1.
- [ ] Confirm the git author identity you want on this public repo (commits currently use your global
      gitconfig email). Blocked on you: it is your identity.

- [ ] Fix GitHub Actions billing for this private repo: the first two `check` runs did not start ("recent account
      payments have failed or your spending limit needs to be increased" — Settings → Billing & plans). Private repos
      bill Actions minutes; making the repo public removes the charge but only after the Phase 2 asset audit.
      Blocked on you: it is your GitHub account/payment method. Until then run `bin/oal-dev-check` locally (it is
      exactly what CI runs).

## Review log
(appended at the end of each phase)

### Phase 0 — 2026-08-23
- vendored: 755 files, excluded 121 bin scripts, 92 need porting (upstream/NEEDS-PORT.txt)
- final review dropped 96 upstream-branded binary assets (wordmark wallpapers, theme previews,
  unlock/plymouth logos) and the 5 `themes/*/hyprland.lua`; see upstream/EXCLUDED-ASSETS.md
- gates: oal-dev-check PASS x7
  ```
  PASS shellcheck
  INFO shellcheck(vendored): 51 warnings in 303 vendored scripts (non-blocking)
  PASS bats
  PASS branding
  PASS notice
  PASS gitleaks
  PASS gitleaks-worktree
  PASS vendor-drift
  ```
- tests: 30 bats cases in test/unit
- open: owner-actions above (GitHub repos not created yet; CI runs once pushed)
