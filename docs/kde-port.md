# The KDE port: what was kept, what was ported, what was dropped

Agentarchy vendors 653 files from an upstream Hyprland distribution and runs KDE Plasma 6.
Most of what came across is desktop-agnostic and works. Some of it is compositor-bound and
cannot. This file records the decision for each piece of that second group, so nobody has to
work it out twice.

`docs/theme-hooks.md` did this for the theme hooks. This is the same exercise for everything
else, and it exists because the alternative -- leaving a command on `PATH` that can only ever
exit 127 -- is indistinguishable from a working one until somebody runs it.

## The rule

A vendored command stays only if it does something on this desktop. Otherwise:

- **Port** it, if the feature is wanted and KDE has a mechanism for it.
- **Drop** it, if it is not wanted, or if porting means guessing at somebody else's service.

"Drop" means an `exclude` line in `upstream/VENDOR-MANIFEST`, not a deleted file: every gate
here is text-based and a deletion comes back on the next `--apply`.

## Ported

| Was | Is now | Why |
|---|---|---|
| `omarchy-launch-floating-terminal-with-presentation` | `bin/oal-run-in-terminal` | The float and the presentation were compositor rules. Finding a terminal and holding the window open is the part that mattered. |
| Quickshell menu (`default/oal/oal-menu.jsonc`) | `bin/oal-menu` | A hand-written tree over `kdialog`. Every entry runs a command that exists, and `test/unit/menu.bats` enforces it. |
| `oal-system-{lock,logout,reboot,shutdown}` | `bin/oal-session-end` | They drove uwsm and a window-closing helper that was never vendored, so `oal logout` exited 0 having done nothing. Now `loginctl` and `org.kde.Shutdown`, with `systemctl` as the no-session fallback. |
| Notification click targets (the `oal-exec` hint) | `notify-send --wait --action=` | The hint was read by the compositor shell, which is not here, so every "click to diagnose" notification was a dead popup. |
| `oal-notification-wait` | freedesktop probe only | It required `oal-shell notifications ping` as well, which can never succeed, so it burned its full timeout on every call. |
| Theme hooks | `docs/theme-hooks.md` | Ported or dropped one by one; `oal-theme-set-kde` was the piece that was missing entirely. |

## Dropped, and not coming back

| What | Why |
|---|---|
| `shell/`, `config/hypr`, `default/hypr`, `default/uwsm` | The Hyprland/Quickshell desktop. Excluded at the manifest, which is the only kind of "never" a text gate can enforce. |
| `oal-hyprland-*` | Window, monitor and workspace controls for a compositor that is not here. KWin's equivalents live in System Settings and `kwriteconfig6`. |
| `default/voxtype/**` | Dictation that could not be installed, offered by a first-run card. |
| Branding assets | Upstream's marks and wallpapers. Ours are in `default/branding/` and generated. |

## Still to decide

These are known-dead and still shipped. Each needs a call, not a patch:

- **`default/oal/oal-menu.jsonc`** -- 365 lines of Quickshell menu naming about forty absent
  commands and `~/.config/hypr/*.lua`. Nothing reads it. It sits beside the live `default/oal/`
  tree and is named exactly like "the menu config", so it is a landmine for the next person
  extending the menu. Recommend: exclude it.
- **`default/nautilus-python/`** -- a file-manager extension for a file manager this
  distribution does not install. Dolphin is the one that ships. Recommend: exclude it, or port
  the transcode action to a Dolphin service menu if it is wanted.
- **The web-app launchers** (`applications/{Basecamp,Discord,Google *,WhatsApp,X,YouTube}.desktop`)
  -- nine entries calling `oal-launch-webapp`, which was excluded from vendoring. A
  `chromium --app=` wrapper is about ten lines and Chromium is now installed, so these are
  cheap to revive. The open question is whether a distribution should put nine web apps in
  somebody's launcher by default; `PKGBUILD` currently says no, and that is a taste call.
  Their icons are also in `applications/icons/` rather than an icon theme, so a revival needs
  both halves.
- **`applications/{HEY,Zoom}.desktop`** -- these claim the `mailto:`, `zoommtg:` and `zoomus:`
  URL schemes and need service-specific handlers. Porting means guessing at another company's
  URL shapes, which is how you ship something that looks right and is not. Recommend: exclude.
- **`xdg-terminal-exec`** in `applications/{Docker,Disk Usage}.desktop` and
  `bin/oal-tui-install:87` -- not in any package list. `bin/oal-run-in-terminal` already does
  this job. Recommend: swap the three call sites.
- **The channel cluster** (`oal-channel-set`, `oal-channel-current`, `oal-version-channel`,
  `oal-refresh-pacman`, and `oal-update-available`'s package-name check) -- these address a
  package named `oal` that has never existed and copy `default/pacman/*` files that vendoring
  deliberately excludes. Issue #47. Either Agentarchy gets real repositories or these five
  commands go; today they are commands on `PATH` that fail at their first filesystem
  operation.
- **`oal-system-factory-reset`** -- hard-requires `/usr/bin/oal-provision-owner`, which is
  never shipped, so it cannot succeed on any machine built from this tree.
- **`migrations/`** -- `oal-migrate` and the `oal-migrate-notify` unit are wired up and
  enabled, and the directory they read does not exist and never has. Either the feature is
  real or it is not.
- **The `etc/` tree** -- twenty of twenty-one subtrees are packaged and installed nowhere.
  Two have live consequences: `systemd-oomd.service` is enabled on every install while the
  `app.slice.d` drop-in that would make it do anything cannot ship (`PKGBUILD` globs only
  `*.service` and `*.timer` from that directory), and `vm.swappiness=150` is tuned "for zram"
  on a machine with no zram-generator. Phase 4 owns this.
