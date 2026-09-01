---
name: oal
description: >
  REQUIRED for end-user customization of this machine's desktop or system config.
  Use when editing KDE Plasma settings, keyboard shortcuts, panels, themes, terminal
  config, or anything under ~/.config/oal/. Triggers: Plasma, KDE, KWin, panel, dock,
  taskbar, widget, applet, keybinding, shortcut, monitor, display, theme, wallpaper,
  colour scheme, lock screen, login screen, terminal config, notifications, agent
  posture, MCP servers, and user-facing oal-* commands. Excludes Agentarchy source
  development through `oal dev link` workflows.
---

# Agentarchy Skill

Manage [Agentarchy](https://github.com/RFingAdam/agentarchy) systems: an Arch Linux
distribution running **KDE Plasma 6 on Wayland**.

This skill is for end-user customization on installed systems. It is not for
contributing to Agentarchy source code.

> **This document was rewritten for KDE.** Agentarchy is derived from an upstream Hyprland
> distribution, and this skill used to describe that desktop: `~/.config/hypr/`,
> `hyprctl reload`, a Quickshell bar, and `~/.config/oal/extensions/oal-menu.jsonc` as the
> live menu. **None of those exist here.** Hyprland, Quickshell, uwsm, waybar and walker
> were all excluded from vendoring. If you find yourself about to edit a file under
> `~/.config/hypr/` or run `hyprctl`, stop: you are working from the wrong document.

## When This Skill MUST Be Used

- Keyboard shortcuts, panels, docks, widgets, window behaviour
- Themes, wallpapers, colour schemes, the lock screen, the login screen
- Terminal configuration, the shell prompt
- Monitors and display configuration
- The agent layer: posture, MCP servers, the brain backend, health
- Anything under `~/.config/oal/`, `~/.local/state/oal/`, or any `oal-*` command

## Critical safety rules

1. **Never hand-edit rendered files.** Everything under
   `~/.local/state/oal/current/theme/` is generated from a palette on every theme change
   and your edit will be gone at the next `oal-theme-set`. Change the palette or the
   template instead (see Themes below).
2. **Never hand-edit `kglobalshortcutsrc` values casually.** The format is
   `shortcut,default,description`, **comma separated**. Write tabs or omit fields and
   kglobalaccel cannot parse the line, silently blanks it on the next start, and
   `kwriteconfig6` still reports success. This cost this project a shortcut that had
   never once worked. Always read the value back *after* kglobalaccel has seen it, and
   treat an **empty** value as failure, not just an absent key.
3. **Prefer `kwriteconfig6` to editing `*rc` files by hand.** Plasma caches config and
   several components rewrite these files; a hand edit made while a session is running is
   often overwritten.
4. **Back up before changing, and say what you changed.**
5. **Do not `sudo` your way past a problem.** See Privilege below.

## Privilege, and what the guard will refuse

Tool calls on this machine pass through a policy guard before they run
(`oal-guard`, rules in `/usr/share/agentarchy/default/guard/rules`). It is not advisory.

- `sudo`, package installs and removals, forced pushes, hard resets and writes under
  `/etc` are **confirm** tier: they need a token the human mints with `oal-guard-confirm`
  at their own terminal. **You cannot mint one.** Ask the user to run it and paste it.
- Changing the agent posture (`oal-agent-profile trusted`), minting a token, and writing
  to the guard's own state are **blocked outright**. Do not try; ask the user.
- Reading `.env` files, private keys, `~/.aws/credentials`, `~/.netrc` and similar is
  blocked whatever command does the reading.

Check the current posture with `oal-agent-profile` (no argument reads it, and is allowed).

## Command discovery

```bash
oal commands              # every documented command and its summary
oal commands --all        # including hidden ones
oal <group>               # the commands inside a group
oal <group> <name> --help # help for one command, without running it
oal commands --json       # machine-readable: binary, route, summary, args, aliases
```

Commands live in `/usr/share/agentarchy/bin` and are symlinked onto `PATH`. Reading one
is often faster than guessing: they are short shell scripts with a comment block on top.

## System architecture

| Layer | What it is | Where its config lives |
|---|---|---|
| Compositor / WM | **KWin** (Wayland) | `~/.config/kwinrc`, System Settings |
| Shell / panels | **plasmashell** | `~/.config/plasma-org.kde.plasma.desktop-appletsrc` |
| Display manager | **SDDM** (autologin) | `/etc/sddm.conf.d/`, theme `oal` |
| Launcher / menu | **`oal-menu`**, a kdialog picker | the tree is in `bin/oal-menu` itself |
| Shortcuts | **kglobalaccel** | `~/.config/kglobalshortcutsrc` |
| Theme engine | `oal-theme-*` | `themes/<name>/colors.toml`, templates in `default/themed/` |
| Agent panel widget | `org.agentarchy.agent` | `/usr/share/plasma/plasmoids/` |
| Notifications | plasmashell, via `notify-send` | `oal-notification-send` |

`default/oal/oal-menu.jsonc` still exists in the tree. **Nothing reads it.** It is the
inherited Quickshell menu definition. Editing it has no effect; edit `bin/oal-menu`.

## Themes

```bash
oal-theme-list                 # what is installed
oal-theme-current              # what is active
oal-theme-set tokyo-night      # apply one, everywhere
```

One `colors.toml` per theme drives every templated config: Plasma's colour scheme, Konsole,
the SDDM greeter, the lock screen, the icon colour, the shell prompt, the terminals and the
editors. To change how a theme looks, edit `themes/<name>/colors.toml` and re-run
`oal-theme-set`. To change what a config does with a palette, edit the matching
`default/themed/<thing>.tpl` and re-run it.

`oal-theme-render <template> --file <colors.toml>` prints one rendered template without
applying anything, which is the fast way to check a template change.

Some of a theme applies live and some needs a new session; `oal-theme-set-kde` says which
on screen. The login screen is deliberately separate: `oal-refresh-sddm <theme>`, and it
needs root.

## Layouts and shortcuts

```bash
oal-layout-set              # report the current layout
oal-layout-set ubuntu       # thin top panel plus a floating dock
oal-layout-set mint         # one taskbar along the bottom
```

Both are Plasma layout scripts (`default/layouts/*.js`) applied over D-Bus. They clear
existing panels first, so re-applying is safe and does not stack duplicates. A layout
apply also rewrites the two global shortcuts (`Meta+Space` for the menu, `Meta+A` to ask).

## Configuration locations

| What | Where |
|---|---|
| Agentarchy user config | `~/.config/oal/` |
| Agentarchy state (generated) | `~/.local/state/oal/` |
| Shipped defaults | `/usr/share/agentarchy/config/`, seeded via `/etc/skel` |
| Terminal | Ghostty (`~/.config/ghostty/`) and Konsole are what ship |
| Plasma | `~/.config/*rc`, via `kwriteconfig6` |

`~/.config/` also contains config trees for alacritty, foot, kitty, imv and others that are
seeded from `/etc/skel` but whose applications are **not installed**. Editing them does
nothing until the application is there.

## Safe customization pattern

```bash
# 1. Read what is there now
kreadconfig6 --file kwinrc --group Desktops --key Number

# 2. Change it
kwriteconfig6 --file kwinrc --group Desktops --key Number 4

# 3. Read it back, and check the value rather than the exit code
kreadconfig6 --file kwinrc --group Desktops --key Number

# 4. Apply, where the component needs telling
qdbus6 org.kde.KWin /KWin reconfigure
```

For a shortcut, step 3 matters most: read it back after kglobalaccel has had a chance to
process it and check the value is not empty.

## Reset to defaults -- ALWAYS CONFIRM WITH THE USER FIRST

```bash
oal-refresh-config <path-relative-to-~/.config>   # one file, backed up first
oal-reinstall-configs                             # all of them (destructive)
oal-layout-set ubuntu                             # just the panels
```

## Troubleshooting

```bash
oal-doctor                 # 13 checks, human readable
oal-doctor --json          # the same, machine readable; exit code is the worst severity
journalctl --user -b -p warning
systemctl --user --failed
```

`oal-doctor` is the right first move for "something is wrong" and is cheap. If it reports a
finding, `oal-agent-diagnose <id>` hands that one finding to the configured agent.

## The agent layer

```bash
oal-agent-profile                 # read the posture
oal-mcp-list / oal-mcp-status     # MCP servers in the catalog, and which are registered
oal-brain-backend                 # which backend answers questions
oal-brain-status                  # and whether it is reachable
oal-ask "why is the disk full"    # ask the machine, answer arrives as a notification
oal-watch --once                  # health check now
```

MCP server *registration* currently automates one runtime's CLI. `oal-mcp-serve` is the
other direction: it exposes this machine to any MCP client, read-only apart from `os_do`,
which routes through the guard.

## Out of scope for this skill

- Editing Agentarchy's own source (that is `oal dev link` and the repository's CLAUDE.md)
- Anything Hyprland, Quickshell, uwsm, waybar or walker: not installed, not shipped
- Package management beyond `oal-pkg-*`; this is Arch, `pacman` is right there

## Example requests this skill covers

- "Make Meta+Return open a terminal"
- "Switch to the gruvbox theme"
- "Put the panel at the bottom"
- "Why is my login screen a different colour to my desktop"
- "Add a second virtual desktop"
- "What is my agent allowed to do right now"
