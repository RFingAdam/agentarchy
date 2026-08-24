# Agentarchy

**Omarchy's tooling. A mouse-first desktop. Agents, eventually.**

Agentarchy is an Arch Linux distribution derived from [Omarchy](https://omarchy.org), on **KDE
Plasma 6** instead of Hyprland.

![Agentarchy on its default theme](docs/screenshots/desktop-agentarchy.webp)

> **Status: pre-alpha, and the third clause of that tagline is a plan, not a feature.** There is no
> agent layer yet. If you are looking for a reason to install this today over Omarchy or stock Arch,
> there isn't one. What exists is below, stated plainly, because a README that describes the roadmap
> in the present tense is how projects waste people's evenings.

## What actually works today

- A vanilla Arch cloud image becomes an installed, themed Plasma 6 Wayland session in about
  **six minutes**, unattended and reproducibly -- `test/vm/golden-path` proves it on every change,
  with assertions and screenshots.
- **The theme engine.** One `colors.toml` per theme drives 17 application templates: switching a
  theme retints Plasma, Konsole, the SDDM greeter, the lock screen, the icon set, VS Code, helix,
  btop, tmux, foot and the rest, in one command. 20 themes ship; the default is ours.
- Wallpapers derived from public-domain photography and recoloured per palette, with every file
  accounted for in `NOTICE`.

## What it looks like

One `colors.toml` per theme drives the whole surface, so switching a theme moves the desktop, the
panel, the icon set, the lock screen and the login screen together. Left to right: the default theme,
gruvbox, the lock screen, and the greeter.

| | |
|---|---|
| ![gruvbox](docs/screenshots/desktop-gruvbox.webp) | ![lock screen](docs/screenshots/lock-screen.webp) |

![the login screen](docs/screenshots/greeter.webp)

Wallpapers are public-domain NASA photography recoloured to each palette, so a theme change moves the
background too rather than leaving one picture under twenty colour schemes. `NOTICE` credits every
source.

## What came from Omarchy, and why you cannot see it

668 files and 302 `oal-*` commands: the theme engine (33), application installers (25), hardware
helpers (24), update and removal tooling (40), the system menu (10), plus audio, Plymouth,
notification and package wrappers.

None of it is visible on the desktop yet, and that is worth explaining rather than glossing.
Everything **visible** in Omarchy is Hyprland and Quickshell -- the bar, the launcher, the window
management, the on-screen menus. All of it was deliberately left behind (121 excluded scripts,
`shell/**`, `config/hypr/**`), because none of it applies to Plasma. What was kept is the layer
underneath the shell, and most of it has no route to the screen until the menu and layout land.
83 commands still need porting; `upstream/NEEDS-PORT.txt` lists them.

So: the theme engine is real and working. The rest is inherited machinery waiting for a front end.

## What is supposed to make it worth using

Three things together, of which two exist:

1. **Omarchy's opinionated tooling** -- done, if not yet surfaced.
2. **A desktop you drive with a mouse** -- done. Plasma 6, Ubuntu-style or Mint-style layout.
3. **An agentic engineering runtime at first login** -- *not built.* This is the only part no other
   distribution offers, and it is the reason the project exists. Until it lands, Agentarchy is a
   KDE respin of somebody else's tooling and should be described that way.

## Why the commands are called `oal-*`

Opinions are like... -- everyone's got one. Omarchy is proudly opinionated; so are we, just
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
| `upstream/` | upstream pin, vendor manifest, rename rules, patches, reports -- see `upstream/README.md` |
| `test/` | bats unit tests and the VM golden path |

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
