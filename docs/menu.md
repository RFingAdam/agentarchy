# The menu, and the 21 commands that had no shell

## What was wrong

`bin/oal-menu` was nine lines of argument shuffling around one call:

```bash
exec oal-shell shell toggle oal.menu "$(menu_payload "$route")"
```

`oal-shell` is upstream's Quickshell IPC. It was excluded from vendoring in Phase 0 as
compositor-bound, and the `oal.menu` plugin it talks to lives in a `shell/` tree that was never
vendored either. **21 vendored commands reference `oal-shell`**, and every one of them exited 127:
present on `PATH`, listed in `--help`, doing nothing.

So the menu was not unwired. There was nothing on this tree to wire up.

## The backend

**kdialog, a native Qt dialog.** It is not the prettiest option and it was not the first one.

fuzzel was, and on paper it is the better pick: a Wayland-native launcher of about 200 KB, themed
from the current palette, keyboard-excellent. It shipped, and then clicking an entry turned out not
to select it -- reported twice from a real mouse, on a desktop whose owner uses one. fuzzel's own
changelog says left click selects and launches, so this is not a documented limitation; whatever the
cause, the result was four menu entries that did nothing when clicked.

A picker that is beautiful and inert loses to a plain one that works. kdialog is KDE's own, so it is
themed by the colour scheme, and a list in a Qt dialog responds to a mouse without anyone having to
wonder. It also answers with the tag rather than the label, so the chosen value is matched back by
index with no string round-trip at all.

`OAL_MENU_BACKEND=fuzzel` restores the old picker for anyone who lives on the keyboard.

### What fuzzel was chosen for originally

**fuzzel, in dmenu mode.** A Wayland-native picker of about 200 KB, themed from the current palette
by `default/themed/fuzzel.ini.tpl` like every other surface.

It was chosen because `oal-menu-select` already had a contract other commands depend on (options
in as `glyph⇥label⇥subtext`, the label back out, stdin accepted), and that contract is a picker's.
fuzzel implements it directly, so the rewrite is a backend swap rather than a change other callers
have to notice.

What was rejected, and why:

- **KRunner.** Native, installed, already has a shortcut and an index. But its model is a search box
  and the `oal-*` tree is a tree, and it cannot be used as a blocking picker that returns a value to
  a shell script, which is exactly what `oal-menu-select` is.
- **rofi / wofi.** rofi is X11-first and the Wayland fork is a fork; wofi is thinly maintained.
  Neither buys anything over fuzzel here.
- **A QML surface of our own.** Would match the desktop perfectly and theme natively. It is also the
  most code and the most to maintain, for a picker, and that trade only makes sense once there is
  something a picker cannot express.

## The triage

Every command that referenced `oal-shell`, and what happened to it.

### Reimplemented (7): the menu family

| Command | |
|---|---|
| `oal-menu` | Rewritten as a tree over `oal-menu-select`. Native, not vendored. |
| `oal-menu-select` | Rewritten on fuzzel. Contract unchanged. Native, not vendored. |
| `oal-menu-emoji`, `oal-menu-clipboard`, `oal-menu-images`, `oal-menu-timezone`, `oal-menu-input` | Still vendored and still call `oal-shell` directly rather than going through `oal-menu-select`. They work the moment each is pointed at the picker, which is a mechanical change per command and is left until one of them is wanted. |

### Needs a different subsystem, not a picker (6)

`oal-notification-dismiss`, `oal-notification-wait`, `oal-notification-weather`, `oal-osd`,
`oal-toggle-notification-silencing`, `oal-reminder`.

These are notifications and on-screen display, not menus. Plasma has both, through
`org.freedesktop.Notifications` and its own OSD, and `oal-notification-send` already works. Porting
them means routing to KDE's notification service, a separate piece of work with its own decisions
about persistence and Do Not Disturb, and no dependency on the menu.

### Answered by Plasma directly (2)

`oal-apply-lock`, `oal-system-lock`. The session lock is `loginctl lock-session` and the greeter is
already ours. The menu's **System → lock** entry does this today; the two vendored commands are
redundant rather than broken and are candidates to drop at the next vendoring review.

### Still open (6)

`oal-shell-config`, `oal-update-status`, `oal-theme-bg-set`, `oal-theme-set`,
`oal-chromium-ytdlp-host`, `oal-audio-source-switch`.

`oal-theme-set`'s use is already documented in `docs/theme-hooks.md` as inert: the calls fail fast
and the wallpaper is applied by `oal-theme-set-kde` instead. The rest are individually small and none
is on a path anything currently takes.

## What the menu contains

Only entries that run a command which exists on this tree. That is enforced by
`test/unit/menu.bats`, which pulls the commands out of the source rather than from a list someone has
to remember to update, because an entry that silently does nothing is worse than an absent one, and
an entire menu of exactly that is what this replaced.

```
Theme    every installed theme, applied with oal-theme-set
Layout   ubuntu / mint, applied with oal-layout-set
Agent    posture (oal-agent-profile), registered MCP servers (oal-mcp-status)
System   lock, log out, restart, shut down
```

Reachable from `Meta+Space` and from the dock.
