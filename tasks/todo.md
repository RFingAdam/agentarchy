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
- [x] Phase 1 — Package + bootstrap + VM golden path (plan: docs/superpowers/plans/2026-08-23-phase-1-vm-bootable.md)
  - [x] Task 1 VM harness (`test/vm/`)
  - [x] Task 2 native package lists + Plasma desktop step
  - [x] ~~Replace the six `default/pacman/*` files~~ — resolved by **dropping** them instead: they are
        excluded from vendoring, and Agentarchy installs from stock Arch mirrors. It has no repos of its
        own, so there was nothing for a rewritten `pacman.conf` to point at.
  - [ ] The package **channel** cluster is now inert and must not be advertised until a phase gives
        Agentarchy real repositories: `bin/oal-channel-set`, `bin/oal-channel-current`,
        `bin/oal-version-channel` and `bin/oal-refresh-pacman` still implement upstream's stable/rc/edge
        switching against the `default/pacman/*` files that no longer exist, so `oal-refresh-pacman` fails
        at its first `cp`. Decide per command: port to a real Agentarchy repo, or exclude from vendoring.
        Not urgent — nothing on the golden path calls them (`oal-reinstall-pkgs` was patched off it).
  - [x] ~~PKGBUILD must not link `bin/oal-dev-*` or `bin/oal-dev-lib.sh` into `/usr/bin`~~ — done in
        Task 3 (`76730f4`): the package installs the tree to `/usr/share/agentarchy`, symlinks 300
        `oal-*` commands onto PATH and drops `oal-dev-*` entirely. Verified on the guest: absent from
        both `/usr/bin` and `/usr/share`.
  - [x] Task 3 PKGBUILD + `oal-bootstrap.sh` (vanilla Arch to installed Agentarchy in ~3 min, idempotent)
  - [x] Task 4 boot into Plasma (patches 0003-0009; reboots into a Plasma 6 Wayland session as `oal`)
  - [x] ~~Supply the Phase 1 replacements listed in `upstream/EXCLUDED-ASSETS.md`~~ — done in Task 5
        (`126765b`): placeholders in `default/branding/`, copies at the Plymouth and SDDM paths, both
        Chromium extension icons. The greeter row was answered by dropping `etc/sddm.conf.d/10-wayland.conf`
        from vendoring instead: it only pointed SDDM's Wayland greeter at a Hyprland compositor we
        never ship, and `install/desktop/plasma.sh` already chose the X11 greeter behind autologin.
  - [x] Task 5 minimal KDE theme apply (`bin/oal-theme-set-kde`) + placeholder branding
  - [x] Task 6 `test/vm/golden-path` + `test/vm/assertions.sh` (21 assertions, 261 s, artefacts)
  - [ ] Only `etc/profile.d/oal.sh` is installed to `/etc`; the other 17 subtrees under `etc/` ship to
        `/usr/share/agentarchy/etc` and are installed nowhere (units, `sudoers.d`, `sysctl.d`,
        `security/`, `tmpfiles.d`, NetworkManager, plymouth, ...). Each is a per-file decision — some
        are still Hyprland-shaped, some are in `upstream/NEEDS-PORT.txt` — so **Phase 4** (system
        tooling port) should walk the tree and decide. Nothing on the golden path needs them today.
- [ ] Phase 2 — Theme engine, all 22 themes (+ wallpaper licence audit)
- [ ] Phase 3 — Layouts, shortcut parity, OAL Menu
- [ ] Phase 4 — System tooling port
- [ ] Phase 5 — Agent layer + overlay contract
- [ ] Phase 6 — ISO
- [ ] Phase 7 — Plugins, cliamp, Quickshell-compat spike, Hyprland add-on
- [ ] Phase 8 — Public release hygiene, v0.1.0

## Owner-actions (only Adam can do these)
- [~] Create GitHub repos `RFingAdam/agentarchy` and `RFingAdam/agentarchy-iso` and decide visibility
      Status 2026-08-23: `RFingAdam/agentarchy` created and made **public** the same day (Adam's decision; wallpaper/icon provenance audit remains a Phase 2 gate before v0.1.0). Still yours: `agentarchy-iso` repo.
      (private until v0.1.0 is the safe default). Blocked on you: repo ownership/visibility is your call.
      **Keep it private until the Phase 2 wallpaper + application-icon audit is finished** (see NOTICE):
      git history is permanent, so an unlicensed asset pushed once is pushed forever.
- [ ] Reopen the Claude Code session in `~/projects/github/agentarchy` and `rmdir ~/projects/github/opinions-are-like`.
      Blocked on you: the running session's cwd cannot move itself.
- [ ] Create the private overlay repo (e.g. `RFingAdam/oal-overlay`, private) once Phase 5 publishes `docs/overlay.md`.
      Blocked on you: it will hold your secrets and homelab config.
- [ ] Decide ISO artifact hosting (GitHub Releases vs homelab) and whether to run a self-hosted Actions runner on Proxmox
      (Phase 6). Blocked on you: infrastructure and cost decision.
- [ ] Look at `.vm/artifacts/<latest>/desktop-guest.png` (the Phase 1 golden-path screenshot: Plasma 6
      Wayland, tokyo-night, bottom panel) and say whether that is the first impression you want.
      Blocked on you: taste. Re-shoot any time with `test/vm/golden-path`.
- [ ] Confirm **tokyo-night** as Agentarchy's default theme, or name another. It is what a fresh
      install lands on today (`OAL_DEFAULT_THEME` in `oal-bootstrap.sh`). Blocked on you: taste.
- [ ] Eyeball the two layouts from the Phase 3 VM screenshots and say which tweaks you want. Blocked on you: taste.
- [ ] Confirm the tagline "Omarchy's taste. Your mouse. Your agents." and whether a text logo is fine for v0.1.
- [ ] Confirm the git author identity you want on this public repo (commits currently use your global
      gitconfig email). Blocked on you: it is your identity.

- [x] ~~Fix GitHub Actions billing for the private repo~~ — resolved 2026-08-23 by making the repo public (free Actions minutes); private-repo minutes were exhausted by other work.
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

### Phase 1 — 2026-08-23
`test/vm/golden-path` is green: a pristine Arch cloud image becomes an installed Agentarchy that
reboots into a themed KDE Plasma 6 Wayland session, autologged in as the install user, in **261
seconds** (boot 53, sync 2, bootstrap 149, reboot 48, session 0, assert 1, theme 0, shots 8).
Artefacts, including both screenshots, are in `.vm/artifacts/20260823-163008/`.

All 21 assertions pass: session wayland/user/active, wayland socket, kwin_wayland, plasmashell,
`plasma-plasmashell.service`, sddm active + enabled, `graphical.target`, package installed,
`oal-version`, 300 `oal-*` commands on PATH, no `oal-dev-*` installed, `OAL_PATH` in a login shell,
the logo renders, the colour scheme is ours *and* kdeglobals carries its colours, no `.invalid` host
in pacman's config, `pacman -Syy`, and ufw still allows SSH where sshd is enabled.

Shipped: `PKGBUILD` + `oal-bootstrap.sh`, native package lists (55 base / 33 desktop / 4 AUR),
`bin/oal-theme-set-kde`, placeholder branding, `test/vm/` harness + golden path, 11 upstream patches,
62 bats tests, 7 gates. Bugs the VM found and fixed on the way: the desktop step ordering, services
we do not install, ufw against a replaced kernel, the mise steps, default-application claims for
uninstalled apps, **ufw closing SSH on the reboot**, the missing `/etc/profile.d/oal.sh`,
`oal-version` asking for the wrong package, and a colour scheme that was named but never applied.

Deferred out of Phase 1 on purpose: the package channel cluster (inert until Agentarchy has repos),
the rest of the `etc/` tree (Phase 4), the SDDM theme and greeter (Phase 3), everything about themes
beyond one colour scheme (Phase 2).
