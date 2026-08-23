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
