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
| `etc/` | files installed under `/etc` (systemd, sddm, plymouth, sudoers.d, ...) |
| `agents/` | agent skills shipped with the distro |
| `applications/` | `.desktop` launchers and their icons |
| `themes/` | colour themes (`colors.toml` + assets) |
| `upstream/` | upstream pin, vendor manifest, rename rules, patches, reports — see `upstream/README.md` |
| `test/` | bats unit tests and the VM golden path |
| `docs/superpowers/` | design spec and per-phase implementation plans |

## Try it in a VM

Everything runs headless on a Linux host with KVM and QEMU; nothing touches your machine's desktop.

```
test/vm/golden-path                 # pristine Arch cloud image -> installed Agentarchy ->
                                    # reboot -> themed Plasma 6 Wayland session -> assertions
                                    # -> screenshots, in about six minutes
test/vm/golden-path --keep          # same, but leave the VM up to poke at
test/vm/vm-ssh                      # a shell in the guest
```

Evidence from each run lands in `.vm/artifacts/<timestamp>/`: `bootstrap.log`, `assertions.txt`,
`timings.txt` and two screenshots (one from QEMU's framebuffer, one from inside the session).
`test/vm/README.md` documents the harness, including how to watch the guest live over VNC.

This is deliberately not part of `bin/oal-dev-check`: CI runners have no VM, and a gate that cannot
run in CI is a gate that rots.

## Developing

```
bin/oal-dev-check                   # seven gates: shellcheck, bats, branding, notice,
                                    # gitleaks (history + worktree), vendor drift (what CI runs)
bin/oal-dev-sync-upstream --check   # verify the vendored tree matches upstream/PIN + patches (read-only)
bin/oal-dev-sync-upstream --apply   # re-vendor (writes into the tree)
```

Files listed in `upstream/VENDORED-FILES.txt` are owned by the sync and must not be hand-edited;
capture changes with `bin/oal-dev-upstream-patch`. `upstream/README.md` documents the whole
contract, including the runbook for bumping `upstream/PIN`.

## Licence

MIT. Derived work attribution in `NOTICE`.
