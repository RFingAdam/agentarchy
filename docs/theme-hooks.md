# What runs when a theme changes, and why

`bin/oal-theme-set` is vendored. It was written for a Hyprland desktop with a Quickshell bar, and it
is the entry point for every theme change on a desktop that has neither. This is the port-or-drop
ruling for each thing it invokes -- the same exercise Phase 1 did for the package channel cluster,
and the reason a theme change on Agentarchy now reaches KDE at all.

Date: 2026-08-23, Phase 2 Task 4. Upstream at `upstream/PIN`.

## The finding that prompted it

`oal-theme-set` never called `oal-theme-set-kde`. Only `oal-bootstrap.sh` did. A fresh install
therefore came up themed, and the first time anyone switched themes the terminals, editors and
browser followed while the desktop, the icons and the lock screen stayed on the install-time theme.
Nothing failed; the desktop just quietly stopped agreeing with itself.

`upstream/patches/0012-theme-set-kde-hook.patch` adds the call and drops the one entry that names a
command this tree does not have. `test/unit/theme-surface.bats` pins both, and pins the stronger
rule underneath them: **every command named in `post_theme_commands` must exist in `bin/`.** That
test is what stops the list drifting back out of step on a PIN bump.

## `post_theme_commands`

| Command | Ruling | Why |
|---|---|---|
| `oal-restart-terminal` | keep | Touches alacritty's config and signals kitty/ghostty. Ghostty ships in the desktop list. |
| `oal-restart-btop` | keep | btop reads `btop.theme`, which four themes carry. |
| `oal-restart-opencode` | keep | Editor config, compositor-independent. |
| `oal-restart-helix` | keep | As above; `helix.toml.tpl` is a vendored template we render. |
| `oal-theme-set-foot` | keep | foot is a Wayland terminal and works under KWin. Not installed by default; a no-op when absent. |
| `oal-theme-set-tmux` | keep | Terminal multiplexer, no desktop dependency. |
| `oal-theme-set-gnome` | keep | **Does real work here.** It reads the same `mode` and sets the GTK colour scheme over gsettings, which is how GTK applications follow a KDE theme; `kde-gtk-config` ships in the desktop list. Guards on `DBUS_SESSION_BUS_ADDRESS`, so it is inert during a chroot install. |
| `oal-theme-set-pi` | keep | Config file only. |
| `oal-theme-set-claude` | keep | Config file only. |
| `oal-theme-set-browser` | keep | Writes a Chromium/Brave policy file. Chromium is not in the default list; the command checks for the policy directory first. |
| `oal-theme-set-vscode` | keep | Config file only; 16 themes carry `vscode.json`. |
| `oal-theme-set-obsidian` | keep | Config file only. |
| `oal-theme-set-keyboard` | keep, inert | Dispatches to ASUS ROG and Framework 16 LED helpers. Neither does anything on other hardware, and one theme in 22 even ships a `keyboard.rgb`. Cheaper to leave than to special-case. |
| `oal-restart-hyprctl` | **drop** | Reloads Hyprland. Excluded from vendoring in Phase 0, so it does not exist on this tree: every theme change was running a command that could only fail. |
| `oal-theme-set-kde` | **add** | The desktop. Colour scheme, Konsole scheme, icon set, wallpaper, lock screen wallpaper. |

## The shell machinery around the list

Left exactly as vendored, deliberately, and recorded here so the next reader does not have to work
it out from the source:

- **`shell_ipc` / `oal-shell`** -- `oal-theme-set` drives a cross-fade between the old and new
  wallpapers by handing base64 payloads to `oal-shell`, upstream's Quickshell bar. That command is
  not vendored, so each call is a `timeout 2 oal-shell …` that exits 127 immediately: no hang, no
  effect. The wallpaper itself is applied by `oal-theme-set-kde` through
  `plasma-apply-wallpaperimage`, so nothing is lost but the animation.
- **`oal-theme-switcher --preload`, `oal-theme-bg-cache`** -- warm the Quickshell selector's caches.
  Harmless, useless, and cheap to leave in place until there is a decision about the selector.
- **`snapshot_background_path` and the `background` symlink** -- still correct. The symlink is what
  `oal-theme-bg-*` reads, and it is maintained whether or not a shell is listening.

Phase 7's Quickshell-compatibility spike owns whether any of this becomes real. Until then the
ruling is *record, do not touch*: these are inert, not broken, and rewriting a vendored file to
delete dead calls buys a patch to maintain and nothing else.

## Two things the themes carry that we do not honour

- **`themes/*/icons.theme`** -- all 22 name a `Yaru-*` variant. Yaru is Ubuntu's icon theme; on Arch
  it is AUR-only, and `install/agentarchy-aur.packages` is opt-in by rule, so a default install
  would fall back and look wrong. Icons follow `mode` instead: `breeze` or `breeze-dark`, both
  already installed with the desktop. The files stay in the tree as upstream data. Honouring them
  needs a coloured icon set in core or extra, which is a packaging decision, not a theming one.
- **`themes/*/keyboard.rgb`** -- one theme ships it; see `oal-theme-set-keyboard` above.

## The greeter, which is not in this list at all

SDDM's theme lives in `/usr/share/sddm/themes/oal`, writable only by root, and a theme change runs
as you. Nothing in `post_theme_commands` can retint it, and adding a `sudoers.d` rule to let one
would be a privilege-escalation surface bought for a colour. So:

- `install/desktop/plasma.sh` points SDDM at the theme (`/etc/sddm.conf.d/10-theme.conf`).
- `oal-bootstrap.sh` calls `oal-refresh-sddm <theme>` while it still has root, which copies the
  theme and renders `default/themed/sddm.theme.conf.tpl` into it.
- `oal-theme-set-kde` says out loud that the login screen is unchanged and names the command that
  would change it. A greeter silently left on the old palette is something you discover at the next
  reboot.

### Installs that never run the bootstrap

The bootstrap is one install path. A deferred-provisioning install -- the ISO -- is another, and it
never runs `oal-bootstrap.sh`, so nothing renders the palette and the login screen comes up on the
`[General]`-and-nothing-else `theme.conf` the theme directory ships. `Main.qml` falls back to
literal colours for every value it reads, so it renders; it just renders in a palette nobody chose,
on the first screen anyone sees.

`oal-greeter-sync.service` closes that: a root oneshot ordered before the display manager, enabled
by `install/desktop/plasma.sh`, which renders the palette if nothing else has.

**"If nothing else has" is read off the file itself.** A rendered palette carries keys and the
shipped one does not, so there is no marker file to keep in step, and a deliberate
`oal-refresh-sddm <theme>` is never undone at the next boot. That second property is the one worth
protecting: a unit that re-asserted the default every boot would silently revert every retint, and
you would blame the theme.

It gives up rather than fails -- missing theme, unreadable palette, failed render, all exit 0. The
unit is ordered ahead of the display manager, and a login screen in fallback colours beats a login
screen that did not start. The render is written aside and renamed, because half a palette parses.

The ISO's chroot finalisation therefore needs to do nothing for the default theme. If it installs
with some other theme, it calls `oal-refresh-sddm <theme>` once and this leaves that alone.

### Which theme is the default

`default/THEME`, one slug, read by `oal-theme-default`. `oal-bootstrap.sh` exports it as
`OAL_DEFAULT_THEME`; `oal-greeter-sync` reads it directly, having no environment to inherit it from.
One file, because a login screen one theme behind the desktop is exactly what a second copy of that
name produces.
