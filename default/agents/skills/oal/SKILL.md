---
name: oal
description: >
  REQUIRED for end-user customization of Linux desktop, window manager, or system config.
  Use when editing ~/.config/hypr/, ~/.config/oal/,
  ~/.config/alacritty/, ~/.config/foot/, ~/.config/kitty/, or ~/.config/ghostty/.
  Triggers: Hyprland, window rules, animations, keybindings, monitors, gaps, borders,
  blur, opacity, oal-shell, bar, terminal config, themes, background,
  night light, idle, lock screen, screenshots, reminders, layer rules, workspace
  settings, display config, and user-facing oal commands. Excludes Agentarchy
  source development through `oal dev link` workflows.
---

# Agentarchy Skill

Manage [Agentarchy](https://github.com/RFingAdam/agentarchy) Linux systems - a beautiful, modern, opinionated Arch Linux distribution with Hyprland.

This skill is for end-user customization on installed systems.
It is not for contributing to Agentarchy source code.

## When This Skill MUST Be Used

**ALWAYS invoke this skill for end-user requests involving ANY of these:**

- Editing ANY file in `~/.config/hypr/` (window rules, animations, keybindings, monitors, etc.)
- Editing `~/.config/oal/shell.json` (status bar layout, widgets)
- Editing terminal configs (alacritty, foot, kitty, ghostty)
- Editing ANY file in `~/.config/oal/`
- Window behavior, animations, opacity, blur, gaps, borders
- Layer rules, workspace settings, display/monitor configuration
- Themes, backgrounds, fonts, appearance changes
- User-facing `oal` commands (`oal theme ...`, `oal refresh ...`, `oal restart ...`, etc.)
- Screenshots, screen recording, reminders, night light, idle behavior, lock screen

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

**Do NOT use this skill for Agentarchy development tasks** (editing the Agentarchy source tree, creating migrations, or running `oal dev ...` workflows).

## Topic Guides

Deeper instructions for common areas live next to this file. Read the
matching guide before starting:

- [`hyprland.md`](hyprland.md) - keybindings, monitors, window rules, and other Hyprland config
- [`plugins.md`](plugins.md) - the Agentarchy shell: bar layout, widgets, plugins, idle behavior
- [`theming.md`](theming.md) - themes, backgrounds, and fonts
- [`hooks.md`](hooks.md) - automation hooks that run on system events
- [`capture.md`](capture.md) - screenshots, screen recordings, OCR text capture, and file sharing
- [`contributing.md`](contributing.md) - reporting Agentarchy bugs and submitting fixes upstream

## Critical Safety Rules

For privileged commands, follow the Privilege Escalation rules below: `sudo` when a terminal is available for the password prompt, `pkexec` when it is not. Do not wrap commands that already manage privilege elevation themselves.

**For end-user customization tasks, NEVER modify anything in `/usr/share/agentarchy/`** - but READING is safe and encouraged.

This directory is owned by the oal package. Any local changes will be
overwritten on the next `oal update`.

```
/usr/share/agentarchy/     # READ-ONLY - NEVER EDIT (reading is OK)
├── bin/                    # Command source (packaged binaries are on PATH)
├── config/                 # Default config templates
├── themes/                 # Stock themes
├── default/                # System defaults
├── shell/                  # Agentarchy shell source and defaults
├── migrations/             # Update migrations
└── install/                # Installation scripts
```

**Reading `/usr/share/agentarchy/` is SAFE and useful** - do it freely to:
- Understand how oal commands work: `oal theme set --help` or `cat $(which oal-theme-set)`
- See default configs before customizing: `cat "$OAL_PATH/config/oal/shell.json"`
- Check stock theme files to copy for customization
- Reference default hyprland settings: `cat /usr/share/agentarchy/default/hypr/*`

**Always use these safe locations instead:**
- `~/.config/` - User configuration (safe to edit)
- `~/.config/oal/themes/<custom-name>/` - Custom themes
- `~/.config/oal/hooks/` - Custom automation hooks

If the request is to develop Agentarchy itself, this skill is out of scope. Follow repository development instructions instead of this skill.

## Privilege Escalation

For an interactive script or command run in a visible terminal, use `sudo` for
privileged work. Agentarchy may grant passwordless `sudo` access to particular
commands, and the terminal is the appropriate place to request a password
when one is needed.

Use `pkexec` only when the caller cannot interact with a terminal or cannot
enter a password there, such as a command launched by an agent or a graphical
background process. Do not replace `sudo` with `pkexec` merely because a
command changes system state.

## System Architecture

Agentarchy is built on:

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Arch Linux** | Base OS | `/etc/`, `~/.config/` |
| **Hyprland** | Wayland compositor/WM | `~/.config/hypr/` |
| **Agentarchy shell** | Status bar + notifications (Quickshell) | `~/.config/oal/shell.json` |
| **Launcher/menus** | Quickshell menu | `~/.config/oal/extensions/oal-menu.jsonc` |
| **Alacritty/Foot/Kitty/Ghostty** | Terminals | `~/.config/<terminal>/` |
| **Agentarchy OSD** | On-screen display | Quickshell plugin |

## Command Discovery

Agentarchy ships a single `oal` CLI that dispatches to all `oal-*` binaries via `oal <group> <action>`. Always prefer this form — it is self-documenting and stable. The underlying `oal-*` binaries still exist on `PATH` and remain safe to read for source.

```bash
# List every documented command and its summary (--all includes hidden commands)
oal commands

# Show the commands inside a group
oal theme --help
oal refresh --help
oal restart --help

# Show help for a specific command (does not execute it)
oal theme set --help

# Machine-readable listing (binary, route, summary, args, aliases)
oal commands --json

# Read a command's source to understand it
cat $(which oal-theme-set)
```

### Command Groups

Run `oal --help` for the full list. The most common groups:

| Group | Purpose | Example |
|-------|---------|---------|
| `oal refresh` | Reset config to defaults (backs up first) | `oal refresh shell` |
| `oal restart` | Restart a service/app | `oal restart shell` |
| `oal toggle` | Toggle feature on/off | `oal toggle nightlight` |
| `oal theme` | Theme management | `oal theme set <name>` |
| `oal bar` | Bar layout and widgets | `oal bar move oal.clock --section right` |
| `oal plugin` | Manage/clone shell plugins | `oal plugin clone oal.clock` |
| `oal hook` | Install automation hooks | `oal hook install theme-set <script>` |
| `oal install` | Install optional software / packages | `oal install docker dbs` |
| `oal launch` | Launch apps | `oal launch browser` |
| `oal capture` | Screenshots and recordings | `oal capture screenshot` |
| `oal reminder` | Desktop notification reminders | `oal reminder 15 "Pickup Jack"` |
| `oal pkg` | Package management | `oal pkg add <pkg>` |
| `oal setup` | Interactive setup wizards | `oal setup security fingerprint` |
| `oal update` | System updates | `oal update` |

## Configuration Locations

Hyprland config lives in `~/.config/hypr/` — see [`hyprland.md`](hyprland.md).
The Agentarchy shell (bar, notifications, plugins, idle) is configured in
`~/.config/oal/shell.json` — see [`plugins.md`](plugins.md).

### Terminals

```
~/.config/alacritty/alacritty.toml
~/.config/foot/foot.ini
~/.config/kitty/kitty.conf
~/.config/ghostty/config
```

**Command:** `oal restart terminal`

### Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fastfetch | `/etc/fastfetch/config.jsonc` default; `~/.config/fastfetch/config.jsonc` user override |
| lazygit | `~/.config/lazygit/config.yml` |
| starship | `~/.config/starship.toml` |
| git | `~/.config/git/config` |

## Safe Customization Patterns

### Edit User Config Directly

For simple changes, edit files in `~/.config/`:

```bash
# 1. Read current config
cat ~/.config/hypr/bindings.lua

# 2. Backup before changes
cp ~/.config/hypr/bindings.lua ~/.config/hypr/bindings.lua.bak.$(date +%s)

# 3. Make changes with Edit tool

# 4. Apply changes
# - Hyprland: auto-reloads on save, but MUST validate with `hyprctl reload` and `hyprctl configerrors`
# - Agentarchy shell: shell.json and user plugin code under ~/.config/oal/plugins/ hot-reload on save
# - Menus/launcher: ~/.config/oal/extensions/oal-menu.jsonc hot-reloads on save
# - Terminals: apply with `oal restart terminal` (reloads running terminals; foot picks changes up in new windows)
```

### Reset to Defaults -- ALWAYS SEEK USER CONFIRMATION BEFORE RUNNING

When customizations go wrong:

```bash
# Reset specific config (creates backup automatically)
oal refresh shell
oal refresh hyprland

# The refresh command:
# 1. Backs up current config with timestamp
# 2. Copies default from $OAL_PATH/config/
# 3. Restarts the component where the refresh needs it (e.g. `refresh shell`)
```

## System Commands

```bash
oal update                  # Full system update
oal version                 # Show Agentarchy version
oal debug --no-sudo --print # Debug info (ALWAYS use these flags)
oal system lock             # Lock screen
oal system shutdown         # Shutdown
oal system reboot           # Reboot
```

**IMPORTANT:** Always run `oal debug` with `--no-sudo --print` flags to avoid interactive sudo prompts that will hang the terminal.

## Troubleshooting

```bash
# Get debug information (ALWAYS use these flags to avoid interactive prompts)
oal debug --no-sudo --print

# Reset specific config to defaults
oal refresh <app>

# Refresh specific config file
# config-file path is relative to ~/.config/
# eg. `oal refresh config hypr/hyprland.lua` will refresh ~/.config/hypr/hyprland.lua
oal refresh config <config-file>

# Full reinstall of configs (nuclear option)
oal reinstall
```

## Decision Framework

When user requests system changes:

1. **Is it a stock oal command?** Use it directly
2. **Is it a config edit?** Edit in `~/.config/`, never `/usr/share/agentarchy/`
3. **Is it a theme customization?** Follow [`theming.md`](theming.md); create a NEW custom theme directory
4. **Is it automation?** Follow [`hooks.md`](hooks.md); use `oal hook install` and the hook `.d` directories
5. **Is it a package install?** Use `oal pkg add <pkgs...>` (or `oal pkg aur add <pkgs...>` for AUR-only packages)
6. **Is it built-in shell/plugin code?** Follow [`plugins.md`](plugins.md); clone it with `oal plugin clone`, never edit the packaged copy
7. **Unsure if command exists?** Run `oal commands` (or `oal <group> --help` for one group)

### Reminder Requests

When the user asks to set a reminder, use `oal reminder <minutes> [message]` directly. Convert natural language durations to minutes and title-case short reminder labels when appropriate.

```bash
oal reminder 15 "Pickup Jack"
oal reminder 60 "Check laundry"
oal reminder show
oal reminder clear
```

## Out of Scope

This skill intentionally does not cover Agentarchy source development. Do not use this skill for:
- Editing files in `/usr/share/agentarchy/` (`bin/`, `config/`, `default/`, `shell/`, `themes/`, `migrations/`, etc.)
- Creating or editing migrations
- Running `oal dev ...` commands

## Example Requests

- "Change my theme to catppuccin" -> `oal theme set catppuccin`
- "Add a keybinding for Super+E to open file manager" -> Check existing bindings first, call `hl.unbind` if needed, then `o.bind` in `~/.config/hypr/bindings.lua`
- "Configure my external monitor" -> Edit `~/.config/hypr/monitors.lua`
- "Make the window gaps smaller" -> Edit `~/.config/hypr/looknfeel.lua`
- "Turn on night light" -> `oal toggle nightlight` (for time-based schedules, edit `~/.config/hypr/hyprsunset.conf` profiles, then `oal restart hyprsunset`)
- "Set a reminder to pickup jack in 15 minutes" -> `oal reminder 15 "Pickup Jack"`
- "Show my reminders" -> `oal reminder show`
- "Clear all reminders" -> `oal reminder clear`
- "Customize the catppuccin theme colors" -> Overlay: put an edited `colors.toml` in `~/.config/oal/themes/catppuccin/`, then re-apply the theme (see `theming.md`)
- "Run a script every time I change themes" -> Install it with `oal hook install theme-set <script>`
- "Change how workspace labels are rendered" -> Clone `oal.workspaces`, which switches the bar to `<username>.workspaces`, then edit the clone
- "Lock after ten minutes" -> Set `idle.lock` to `600` in `~/.config/oal/shell.json`
- "Reset shell/bar to defaults" -> `oal refresh shell`
- "Record my screen" -> `oal screenrecord --fullscreen`, then `oal screenrecord --stop-recording` (see `capture.md`)
- "Report this bug to Agentarchy" -> Gather diagnostics and a capture of the problem, then file it (see `contributing.md`)
