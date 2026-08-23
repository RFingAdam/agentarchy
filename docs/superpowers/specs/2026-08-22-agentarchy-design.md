# Agentarchy — an Omarchy-derived, agent-first Arch distro for people who use a mouse

> Project name: **Agentarchy**. The joke ("opinions are like…") lives in the terminal: every command is `oal-*`.

## Context

Omarchy (basecamp/omarchy, MIT) is a beautiful, opinionated Arch setup: 22 palette-driven themes, a system menu,
~430 `omarchy-*` scripts (update/migrate/snapshot/install-*/hw-*), an offline ISO with an archinstall-based
orchestrator, Limine + btrfs + snapper, SDDM, plymouth. Its interaction model is keyboard-only Hyprland tiling —
no title bars, no taskbar, no minimize, no desktop icons. Adam likes everything *except* that, and comes from
Ubuntu/GNOME. Goal: a **public repo** (`RFingAdam/agentarchy`) that keeps Arch + Omarchy's themes, menu,
tooling and install machinery, swaps the desktop for a familiar mouse-first one (two layouts: Ubuntu-style and
Mint-style), and makes the machine an **AI-agent-first engineering OS** (Claude Code + hooks + skills + MCP runtime
ready at first boot).

Two read-only research passes (7 agents + an Opus critic) established the load-bearing facts:

- **Upstream is v4 "quattro"** (tagged 2026-08-14, default branch, head `2c247e39…`). The shell (bar/menu/OSD/
  lock/clipboard) is one Quickshell/QML app in `shell/` with a plugin system; Hyprland config is now Lua. The old
  `boot.sh`/`install.sh` curl-pipe path **no longer exists**: Omarchy ships as pacman packages (`omarchy`,
  `omarchy-settings`, `omarchy-nvim`, built by `omacom-io/omarchy-pkgs`) installed to `/usr/share/omarchy`
  (`OMARCHY_PATH`), and two scripts run the steps: `omarchy-apply-system` (root: `install/config`, hardware,
  `install/login/sddm.sh`, post-install) and `omarchy-provision-user` (user: `install/user`). The ISO
  (`omacom-io/omarchy-iso`, branch quattro) drives the `archinstall` Python library, **Limine only**, then calls
  those two scripts in a chroot. `install/` is ~100% desktop-agnostic; `config/`+`default/` are agnostic except
  `hypr/`, `uwsm/`, `wayland-sessions/omarchy.desktop`, `libalpm` hyprland-reload hooks, `xdg-terminal-exec` list.
- **Theme system**: `themes/<name>/colors.toml` is a flat schema (`mode`, `accent`, `selection`, `muted`,
  `background`/`dark_`/`darker_`/`lighter_background`, `foreground`/`dark_`/`light_`/`bright_foreground`, `red
  yellow orange green cyan blue magenta brown`, `bright_*`). `omarchy-theme-set` renders `default/themed/*.tpl`
  (18 templates; 14 agnostic — ghostty/alacritty/foot/kitty/btop/neovim/vscode/obsidian/chromium/claude/pi/helix/
  tmux…; only `hyprland.lua.tpl`, `hyprland-preview-share-picker.css.tpl`, `shell.toml.tpl` are compositor-bound),
  atomically swaps `~/.local/state/omarchy/current/theme`, then pushes colors to the shell over IPC.
- **Hyprland can't be a stacking desktop** without fighting it; a real DE is the honest answer. **KDE Plasma 6.7**
  (Arch extra; 6.8 in Oct 2026 drops X11 — design Wayland-only) gives both layouts natively via Look-and-Feel
  packages (no extensions to break), `.colors` schemes are plain INI generatable from a palette, Konsole
  colorschemes map 1:1 to 16 ANSI colors, KWin has built-in tiling + Krohnkite, Spectacle/Klipper replace
  grim/cliphist (KWin has no wlr-screencopy), KWin implements wlr-layer-shell (rofi 2.0 in Arch extra is native
  Wayland), archinstall has a Wayland-only `PlasmaProfile`.
- **Plugin compatibility** (Adam's ask): Omarchy v4 plugins are `manifest.json` + **QML entry points loaded into
  the Quickshell process** (`kinds`: bar-widget/panel/overlay/menu/service/bar). No install hooks, no packages, no
  migrations, no Hyprland bindings in the spec. The desktop-agnostic parts are: the manifest schema + `omarchy
  plugin add/update/remove/list/validate/clone` lifecycle, the **menu extension format** (`omarchy-menu.jsonc` +
  `~/.config/omarchy/extensions/omarchy-menu.jsonc`: `label/icon/action/when/checked`), and `"type":"command"` bar
  modules. The 230+ community plugins on omarchyplugins.com are QML for Quickshell → only runnable on OAL by
  hosting Quickshell under KWin (feasible via layer-shell, unverified), which is a Phase-7 spike, not a v0.1 promise.
- **Public-repo hazards**: Omarchy name/logo/ASCII/`omarchy.ttf` are Basecamp branding (MIT covers code, not
  marks; the font has no licence file); **no theme/wallpaper has any licence or attribution file** upstream;
  Adam's real agent config holds secrets, homelab topology, business identity and a very permissive permission
  posture; naive copying of `migrations/` (84 files) would collide with upstream's marker namespace.
- **This host** (Ubuntu 26.04, 16c/30 GB/248 GB free, KVM + nested virt, docker + libvirt groups) can run the
  Docker `--privileged` ISO build and the QEMU/KVM integration tests exactly as upstream does.

### Decisions made with Adam (2026-08-22)

| Decision | Choice |
|---|---|
| Base | Omarchy **quattro (v4)**, pinned commit, hard fork with scripted vendoring |
| Desktop | **KDE Plasma 6**, Wayland only |
| Layouts | Both, picked at install and switchable later: `ubuntu` (top panel + dock) and `mint` (single bottom panel) |
| Name / CLI | Project **Agentarchy** (repos `agentarchy`, `agentarchy-iso`; package `agentarchy` → `/usr/share/agentarchy`). Everything in the terminal is the joke: commands `oal-*`, env `OAL_*` (`OAL_PATH=/usr/share/agentarchy`), `~/.config/oal`, `~/.local/state/oal`. README explains "opinions are like…" once. |
| Delivery | Bootable ISO (fork of `omarchy-iso`) **and** `oal-bootstrap` (curl \| bash) over vanilla Arch |
| First target | VM on this Ubuntu box (libvirt/QEMU), then hardware |
| Agent layer | Public generic layer in this repo + **private personal overlay repo**; guarded defaults, "trusted" tier opt-in |
| Hyprland/Quickshell | Optional add-on later (`oal-install-hyprland`); Quickshell only lives there |
| Plugins | Honor the desktop-agnostic subset now; Quickshell-under-KWin compat is a Phase-7 spike |
| Extras | Ghostty default terminal; **cliamp** (AUR `cliamp`, Go, bjarneo) via `oal-install-cliamp` |
| Models | Fable planned; execution **Opus** = theme engine, installer/package, ISO orchestrator, security hook, menu; **Sonnet** = vendoring/renames, package lists, LnF layout.js, shortcuts, docs, tests |

---

## Architecture

### Repo `agentarchy` (today: the empty dir `~/projects/github/opinions-are-like` — Phase 0 creates
`~/projects/github/agentarchy` and the session moves there; the old empty dir is removed)

```
agentarchy/
├── PKGBUILD                      # builds package `agentarchy` from this tree → /usr/share/agentarchy + /usr/bin/oal-* symlinks
├── oal-bootstrap.sh              # curl|bash for vanilla Arch: deps → makepkg -si → oal-apply-system → oal-provision-user
├── version
├── bin/                          # oal-* (vendored bucket B/C/D scripts renamed + new Plasma ones; `oal` dispatcher)
├── install/                      # vendored 1:1 (helpers, config, hardware, login/sddm.sh, post-install, user,
│   │                             #   provisioning) + new install/desktop/plasma.sh, install/agent/
│   ├── oal-base.packages         # official repos only: upstream base minus hyprland/quickshell/uwsm/xdph/gtk4-layer-shell/
│   │                             #   omarchy-only tools, plus plasma set (see §Packages)
│   ├── oal-other.packages        # ISO bootstrap set (kernel, limine, snapper, zram, pipewire, btrfs-progs, dkms…) vendored
│   └── oal-agent.packages        # nodejs npm github-cli uv docker tailscale syncthing jq age ripgrep fd bat eza lazygit lazydocker tmux zsh git-delta
├── default/                      # system defaults (vendored agnostic dirs) + new:
│   ├── themed/*.tpl              # vendored 16 agnostic templates + plasma.colors.tpl, konsole.colorscheme.tpl, sddm-theme.conf.user.tpl
│   ├── oal/oal-menu.jsonc        # vendored omarchy-menu.jsonc with Hyprland actions swapped for KCMs / oal-* scripts
│   ├── plasma/lookandfeel/org.oal.ubuntu/   # metadata.json, contents/defaults, contents/layouts/org.kde.plasma.desktop-layout.js
│   ├── plasma/lookandfeel/org.oal.mint/
│   ├── plasma/shortcuts/         # *.desktop + kglobalshortcutsrc fragment (Super, Ctrl+Alt+T, PrintScreen, Super+E, Super+Alt+Space…)
│   ├── plasma/kwinrc, kdeglobals, kscreenlockerrc seeds
│   └── sddm/oal/                 # vendored Omarchy SDDM QML theme, rebranded
├── config/                       # per-user seeds (ghostty, btop, git, lazygit, obsidian, starship, tmux, oal/{extensions,hooks,shell.json→dropped})
├── themes/<name>/                # vendored: colors.toml, backgrounds/, neovim.lua, vscode.json, icons.theme, preview*.png (no shell.lock.toml)
├── applications/                 # .desktop overrides + hidden/
├── migrations/                   # empty at start; <epoch>.sh; markers in ~/.local/state/oal/migrations
├── agents/skills/                # vendored + OAL skills
├── etc/  # vendored system config (sysctl, sudoers.d, mkinitcpio, tmpfiles, profile.d)
├── agent/                        # public agent layer templates (CLAUDE.md, hooks, settings.json, security hook)
├── plugins/                      # oal-plugin-* + compat notes (Phase 7)
├── upstream/PIN  upstream/VENDOR-MANIFEST  upstream/RENAME-MAP  NOTICE
├── test/unit (bats)  test/vm (libvirt golden path)  test/fixtures (rendered themes)
├── docs/  manual/  tasks/todo.md  tasks/lessons.md  CLAUDE.md  AGENTS.md  README.md  LICENSE (MIT)
└── .github/workflows/ (shellcheck, bats, gitleaks, vendor-drift, branding-grep, notice-check)
```

Second repo `agentarchy-iso` = fork of `omacom-io/omarchy-iso@quattro` (archiso submodule kept).

### Install model (mirrors upstream v4)

- `PKGBUILD` (package `agentarchy`) installs the tree to `/usr/share/agentarchy` and links `bin/*` into `/usr/bin`. `oal-apply-system
  --install-user U --first-install` (root) runs `install/config/all.sh` → `oal-apply-hardware` → `install/desktop/
  all.sh` (new) → `install/login/all.sh` → `install/post-install/all.sh`. `oal-provision-user --first-install`
  runs `install/user/all.sh` (+ `oal-layout-set "$OAL_LAYOUT"`, `oal-theme-set tokyo-night`, agent scaffold).
- `oal-bootstrap.sh` (vanilla Arch, Limine+btrfs recommended): `pacman -S base-devel git` → clone → `makepkg -si`
  → the two commands above → reboot into SDDM/Plasma. `OAL_REF`/`OAL_REPO` honored.
- No Basecamp binary repo dependency. Official repos only in the base path; AUR (`yay`, `cliamp`) only via opt-in
  `oal-install-*`; the ISO prebuilds the few AUR items it needs (upstream pattern: `builder/build-omarchy-packages.sh`).

### Packages (`install/oal-base.packages`, diff vs upstream)

Remove: `hyprland hyprland-guiutils hyprland-preview-share-picker hyprpicker hyprsunset quickshell uwsm
xdg-desktop-portal-hyprland gtk4-layer-shell grim slurp wtype` + Omarchy-only tools (`omarchy-nvim herdr omacalc
omacut omawrite tensaku ttfx`). Add: `plasma-desktop plasma-workspace kwin kscreen plasma-nm plasma-pa bluedevil
powerdevil kde-gtk-config breeze-gtk xdg-desktop-portal-kde sddm sddm-kcm dolphin konsole spectacle ark gwenview
okular kate plasma-systemmonitor print-manager kwallet-pam kdeplasma-addons rofi` (exact set validated by
`pacman -Si` in Phase 1; start from `plasma-meta` minus bloat). Keep: ghostty, nvim (LazyVim via upstream's
`config/nvim` equivalent — upstream moved it to the `omarchy-nvim` package; OAL vendors a plain LazyVim seed),
btop, lazygit, lazydocker, docker, chromium, nautilus→**dolphin**, fonts (`ttf-jetbrains-mono-nerd-basic`,
`noto-*`, `ttf-ia-writer`, `woff2-font-awesome`), plymouth, limine, snapper, ufw, tailscale, pipewire, fcitx5.

### Theme engine (`bin/oal-theme-*`, `default/themed/`)

Vendored `oal-theme-set` + `oal-theme-set-templates` + 14 agnostic `.tpl` files keep working unchanged (paths
renamed). Replace the Quickshell IPC block with `oal-theme-set-kde`:

| Output | Mechanism |
|---|---|
| Plasma colour scheme | render `plasma.colors.tpl` → `~/.local/share/color-schemes/OAL <Name>.colors` (map: `background`→Window/View BackgroundNormal + WM inactive; `lighter_background`→Button/Header; `foreground`→ForegroundNormal; `accent`→DecorationFocus/Hover/ForegroundActive/WM activeBackground; red/green/yellow/blue→Negative/Positive/Neutral/Link; `selection`→Selection; `muted`→ForegroundInactive); `plasma-apply-colorscheme "OAL <Name>"` (KWin decorations + Breeze-GTK follow via kde-gtk-config) |
| Light/dark | `mode` from colors.toml → `kwriteconfig6 --file kdeglobals --group General --key ColorScheme`; verify `xdg-desktop-portal-kde` reports dark/light for custom scheme names (flagged uncertain) — fallback: name schemes "OAL <Name> Dark/Light" |
| Wallpaper / lock / SDDM | `plasma-apply-wallpaperimage`; `kscreenlockerrc [Greeter][Wallpaper][org.kde.image][General] Image=`; `sddm-theme.conf.user.tpl` → `/usr/share/sddm/themes/oal/theme.conf.user` via a polkit/sudoers rule created at install (upstream already runs `omarchy-refresh-sddm` as root) |
| Icons | `icons.theme` → `kwriteconfig6 --file kdeglobals --group Icons --key Theme` (Yaru variants stay — upstream already installs Yaru; fallback Papirus) |
| Ghostty / Konsole | vendored `ghostty.conf.tpl` + new `konsole.colorscheme.tpl` (Color0-7 + Intense = 16 ANSI) + `oal-restart-terminal` |
| btop, neovim, VS Code, Obsidian, Chromium policy colour, Claude, tmux, helix, keyboard RGB | vendored handlers unchanged |
| Dropped | `shell.toml.tpl`, `hyprland*.tpl`, `omarchy-theme-set-gnome` (replaced by the KDE path) |

`oal-theme-next/menu/install/remove/colors-from-alacritty` vendored → community theme repos (`omarchy-*-theme`)
install unchanged (`shell.lock.toml` ignored).

### Layouts (`default/plasma/lookandfeel/`, `bin/oal-layout-set`)

Two Look-and-Feel packages (`KPackageStructure: Plasma/LookAndFeel`, `contents/defaults` for scheme/icons/cursor/
decoration/wallpaper plugin, `contents/layouts/org.kde.plasma.desktop-layout.js`), modelled on the shipped
`org.kde.breeze` template and Garuda's Dr460nized dual-panel script (top panel + bottom dock):
- `org.oal.ubuntu`: top panel (`kickoff` with OAL icon, `panelspacer`, `digitalclock`, `systemtray`), left dock
  panel (`icontasks` launchers: ghostty, chromium, dolphin, obsidian; `showdesktop`); Meta → Kickoff, Meta+W overview.
- `org.oal.mint`: single bottom panel (`kicker` classic menu, `taskmanager` labelled, `systemtray`, `digitalclock`,
  `showdesktop`).
`oal-layout-set <ubuntu|mint>` = `kpackagetool6` install (if needed) + `plasma-apply-lookandfeel -a org.oal.<l>
--resetLayout` (flag semantics verified on the live VM in Phase 3; documented that it resets panels). Installer and
first-run prompt set `OAL_LAYOUT`. Shared shortcut parity set and KWin defaults (tiling on, overview, focus
follows click, title bars with min/max/close) in `default/plasma/`.

### OAL Menu (`bin/oal-menu`)

Upstream v4's menu is a Quickshell QML plugin fed by `omarchy-menu.jsonc` (+ user extensions). OAL keeps the **data
format verbatim** (`default/oal/oal-menu.jsonc`, `~/.config/oal/extensions/oal-menu.jsonc`) and renders it with a
bash + `jq` driver over **rofi 2.0** (native Wayland, layer-shell on KWin; fallback `--backend=kdialog`): evaluates
`when`/`checked` in one batched bash subprocess, runs `action`. Hyprland actions swapped for `kcmshell6 kcm_*`
(displays, bluetooth, audio, power, input, keyboard), `oal-*` scripts, `spectacle`. Bound to Super+Alt+Space and
exposed as a panel launcher (`.desktop` in the dock) so it is mouse-reachable. Plasmoid rewrite is a Phase-7 option.

### System tooling (vendored buckets)

- **B (≈270 agnostic scripts)**: `oal-update*`, `oal-migrate`, `oal-snapshot`, `oal-pkg-*`, `oal-install-*`/
  `oal-remove-*`, `oal-hw-*` (minus touchpad/touchscreen which call hyprctl → KCM), `oal-refresh-{applications,
  chromium,limine,pacman,plymouth,sddm,tmux}`, `oal-channel-*`, `oal-version*`, audio/battery/bluetooth/brightness/
  network/powerprofiles/hibernation/tailscale/webapp/agent/hook/font/factory-reset scripts.
- **D**: `oal-clipboard-*` (wl-clipboard, works on KWin; history = Klipper) ; `oal-capture-*` rewritten on
  `spectacle -b -r/-f/-u -o` and the portal (screenshot/region/record/QR/OCR via tesseract as upstream).
- **A (≈107 Hyprland/Quickshell-bound)**: not vendored. `oal-system-{lock,logout,reboot,shutdown}` re-implemented
  on `loginctl`/`qdbus6 org.kde.ksmserver`.
- Migrations: start empty; same runner, own marker dir; `oal-update` = snapshot → `pacman -Sy oal` (or git
  `makepkg` on the git channel) → migrate. Channels: `main`/`rc`/`dev` = git branches of this repo.

### Agent layer (`agent/`, `install/agent/`, `bin/oal-agent-*`, `bin/oal-project-init`) — public & generic

- Runtime: Claude Code (official installer, self-updating), `gh`, `uv`, nodejs/npm, docker (+group), tailscale,
  syncthing, jq (**hard dependency**), age, ripgrep/fd/bat/eza/lazygit/lazydocker/tmux/zsh/git-delta; optional
  `oal-install-{codex,ollama}`.
- Templates: `~/.claude/CLAUDE.md` (genericized: plan-mode default, `tasks/todo.md` + `tasks/lessons.md`,
  verification-before-done, owner-action capture, subagent usage), SessionStart dev-brief hook (gh-based,
  generic), Stop workflow-improvement capture hook, **PreToolUse security blocker** (HARD-BLOCK / CONFIRM /
  ALLOW-logged tiers, audit log `~/.local/state/oal/claude-audit/`, **fail-closed** if jq missing), `oal-agent-
  profile trusted|scoped|untrusted` (default `scoped`), `oal-project-init` (tasks/, CLAUDE.md stub, .gitignore
  hygiene). Upstream's `agents/skills` symlink mechanism (`omarchy-provision-user` → `~/.claude/skills`) vendored.
- Shipped `settings.json` is **guarded** (no permission-skipping, no auto mode). Model IDs never hard-coded.
- `oal-agent-setup` first-run wizard (after first login; re-runnable): `claude auth login`, `gh auth login`,
  age key generate/import, optional overlay URL → `oal-overlay-apply <git-url>`.
- **Private overlay contract** (`docs/overlay.md` + `docs/examples/overlay-example/`): repo with `apply.sh`,
  `secrets.age`, `repos.manifest` (clone list), `ssh/config`, MCP fragments, personal `settings.json`, homelab/
  hermes/openclaw bits. Adam's real overlay lives in a private repo he creates (owner-action). Enforcement:
  gitleaks (CI + pre-commit), `ip-hygiene` pre-push checklist bound to the repo, rule that nothing reads
  `~/.claude.json` into a tracked path.

### Plugins (`bin/oal-plugin-*`, Phase 7)

Honored unchanged: manifest.json schema + `oal plugin add/update/remove/list/validate/clone` lifecycle (vendored,
`omarchy.*` namespace rule kept), menu extensions JSONC, `"type":"command"` modules (rendered by a small "command
output" panel widget). Quickshell-QML kinds: validator reports "requires Quickshell shell; install the Hyprland
add-on or the Quickshell-compat spike". Spike: run `quickshell -p $OAL_PATH/shell` (upstream shell vendored
verbatim) as a layer-shell client under KWin with Plasma's panel hidden → if it works, it becomes
`oal-install-quickshell-bar` (opt-in, "Omarchy bar on Plasma"). cliamp: `oal-install-cliamp` (AUR); its Quickshell
now-playing card only lights up in the Hyprland add-on; a Plasma now-playing applet is a later nicety.

### ISO (`agentarchy-iso`)

Fork `omacom-io/omarchy-iso@quattro`. Changes: branding; `builder/build-iso.sh` + `build-omarchy-packages.sh` →
build `agentarchy` from `--local-source ../agentarchy` (no `[omarchy]` repo/GPG key; our own signing key later),
offline mirror from `oal-base/other.packages` + `builder/archinstall.packages`; orchestrator `phases_impl.py`:
package names, `oal-apply-system`/`oal-provision-user`, `configure_login` → `Session=plasma`, new **Layout**
question in the configurator (`configs/airootfs/root/configurator` — inspect its tech first; it is not a
submodule), drop `omarchy-nvim`/`mise` Node tarball unless kept. Keep Limine, snapper, hibernation, ufw, ssh/
tailscale provisioning. Tests: `test/all` (unit), `oal-iso-boot`, `test/integration` (QEMU/KVM + QMP screendump
+ tesseract OCR, 8 GB RAM, `--reuse-base`) run on this host. GitHub-hosted runners can't hold the offline mirror
→ local builds first; self-hosted runner on the homelab is an owner decision.

### Hyprland add-on (later)

`oal-install-hyprland`: installs upstream Omarchy's packages from the `[omarchy]` repo into a second SDDM session,
sharing `themes/` (re-adds `shell.lock.toml`/`shell.toml.tpl` for that session only). Explicitly out of v0.1.

---

## Phases (each = one PR; each ends with the VM golden path green; Sonnet unless noted)

### Phase 0 — Bootstrap
Create `~/projects/github/agentarchy` (remove the empty `opinions-are-like` dir); `git init`; MIT LICENSE; NOTICE
(Omarchy attribution, theme/wallpaper credits section); README ("Agentarchy — Omarchy's taste, your mouse, your
agents"; the `oal` = "opinions are like…" explanation; "not affiliated with Basecamp/Omarchy"); CLAUDE.md/AGENTS.md;
`docs/superpowers/specs/2026-08-22-agentarchy-design.md` (this plan as the design spec); `tasks/todo.md` (phase checklist + owner-actions)
+ `tasks/lessons.md`; `.editorconfig`/`.gitignore`. `upstream/PIN=2c247e39…`, `VENDOR-MANIFEST`, `RENAME-MAP`,
`bin/oal-dev-sync-upstream` (tarball fetch → copy manifest paths → sed map → diff). First vendoring run. CI:
shellcheck, bats, gitleaks, vendor-drift, branding-grep (no `omarchy` outside `upstream/`, NOTICE, docs/compat),
notice-check (every `themes/*/backgrounds/*` listed in NOTICE).

### Phase 1 — Package + bootstrap + VM golden path (Opus: PKGBUILD/apply/provision; Sonnet: VM harness, packages)
`test/vm/`: libvirt domain from the official Arch ISO with an automated `archinstall` JSON (Limine, btrfs, no LUKS,
user `oal`, sshd) → snapshot "vanilla" → `oal-bootstrap.sh` over SSH → assertions (`loginctl` wayland session,
`plasmashell` + `kwin_wayland` alive, SDDM autologin `Session=plasma`, `oal-version`, theme dir symlinked). Measured
iteration time recorded in docs. `install/desktop/plasma.sh` (packages, portals, pipewire, NM, bluetooth, CUPS,
fonts), SDDM theme rebranded, Ghostty/Dolphin/Spectacle defaults, one layout (mint = Plasma default), tokyo-night
applied through a minimal `oal-theme-set-kde`. Early spikes logged here: `plasma-apply-lookandfeel --resetLayout`
semantics, portal dark/light for custom scheme names, rofi layer-shell on KWin.

### Phase 2 — Theme engine, all 22 themes (Opus)
`plasma.colors.tpl`, `konsole.colorscheme.tpl`, SDDM/lock handling, icons mapping, light/dark, `oal-theme-*`
complete; fixture snapshot tests for every theme; VM: cycle 3 themes, assert `kdeglobals` ColorScheme + wallpaper.
**Asset audit**: table of all `themes/*/backgrounds/*` with source/licence (upstream git log/PRs; Catppuccin/Nord/
Gruvbox/Tokyo Night/Rose Pine/Kanagawa/Everforest/Flexoki are MIT palettes — names kept with attribution);
unlicensed wallpapers replaced (Unsplash/CC0) or dropped; `omarchy.ttf` excluded; NOTICE updated.

### Phase 3 — Layouts, shortcut parity, OAL Menu (Sonnet: LnF/shortcuts; Opus: menu)
Both LnF packages; `oal-layout-set`; installer/first-run prompt; `kglobalshortcutsrc` + `.desktop` shortcuts
(Super, Ctrl+Alt+T, PrintScreen, Super+E, Super+L, Meta+W, Meta+T); KWin defaults; `oal-install-krohnkite`.
`oal-menu` rofi renderer with `when`/`checked`/`action`, KCM-based Setup, panel entry. VM screenshots of both
layouts attached to the PR (Spectacle inside VM, copied out) — **Adam eyeballs the look** (owner-action).

### Phase 4 — System tooling port (Sonnet; Opus for update/snapshot)
Vendored bucket B verified script-by-script (shellcheck + smoke in VM), capture scripts on Spectacle/portal,
clipboard on Klipper, `oal-update` end-to-end against a local git remote + `pacman -U` rebuilt package, migration
runner test (marker/skip semantics), channel switching, `oal-hw-*` docs marked "inherited, untested on OAL".

### Phase 5 — Agent layer + overlay contract (Opus: security hook/wizard; Sonnet: templates/docs)
`install/agent/`, `agent/` templates, `oal-project-init`, `oal-agent-setup`, `oal-agent-profile`,
`oal-overlay-apply` + `docs/overlay.md` + redacted example overlay; bats for the PreToolUse blocker (block/confirm/
allow cases, jq-missing → fail-closed); VM: fresh login → wizard runs → `claude --version`, hooks registered.

### Phase 6 — ISO (Opus)
Fork iso repo; branding; package build from local source; manifests; orchestrator rename + `Session=plasma` +
Layout step; local Docker build on this host; `oal-iso-boot` smoke; `test/integration` full install; boot the
installed image and re-run Phase-1 assertions. Artifact hosting decision recorded (owner-action).

### Phase 7 — Plugins, cliamp, Quickshell-compat spike, Hyprland add-on (Opus spike; Sonnet CLI)
`oal-plugin-*` lifecycle + validator messaging + command-output widget; compatibility matrix in docs;
`oal-install-cliamp`; Quickshell-under-KWin spike (time-boxed, result documented either way); `oal-install-hyprland`.

### Phase 8 — Public release hygiene
`human-voice` pass; `ip-hygiene` full-history audit; supported-hardware matrix + disclaimer; issue/contribution
policy (inherit upstream's "we won't add X" stance explicitly); docs site from `manual/`; `v0.1.0` tag.

---

## Verification (end-to-end)

1. **Unit** (CI): shellcheck on `bin/` + `install/`; bats — theme renderer (fixture diff per theme), migration
   runner, security hook, rename completeness, menu JSONC evaluator.
2. **VM golden path** (`test/vm/run.sh`, libvirt/KVM here): vanilla Arch → `oal-bootstrap.sh` → SSH assertions;
   theme cycle; layout switch; `oal-update`; screenshots for review.
3. **ISO**: Docker build; `oal-iso-boot`; `test/integration`; boot installed image; Phase-1 assertions again.
4. **Hygiene gates**: gitleaks, vendor-drift, branding-grep, notice-check.
5. Per CLAUDE.md: no phase is "done" without the above output in the PR; `tasks/lessons.md` updated on every
   correction; diff behaviour vs upstream Omarchy noted where a vendored script was changed.

## Owner-actions (recorded in `tasks/todo.md` at Phase 0)

- Create GitHub repos `RFingAdam/agentarchy` and `RFingAdam/agentarchy-iso`; decide public-now vs public-at-v0.1.
- Reopen the Claude Code session in `~/projects/github/agentarchy` once Phase 0 creates it.
- Create the private overlay repo; hand over its URL after Phase 5.
- Decide ISO artifact hosting (GitHub Releases vs homelab) and whether to run a self-hosted Actions runner on Proxmox.
- Eyeball both layouts in the Phase-3 screenshots (taste call).
- Confirm the tagline/branding text and a simple logo (text logo is fine for v0.1).

## Known uncertainties (verified early, not assumed)

- `plasma-apply-lookandfeel --resetLayout` exact behaviour (Phase 1 spike on live Plasma 6.7).
- `xdg-desktop-portal-kde` dark/light reporting for custom scheme names (Phase 1 spike; naming fallback ready).
- rofi 2.0 layer-shell behaviour on KWin (anchors/keyboard grab) — fallback `kdialog`/plasmoid.
- The ISO configurator's implementation (`configs/airootfs/root/configurator`) — read before Phase 6 estimates.
- Whether `omarchy-nvim`'s LazyVim config is worth vendoring vs a plain LazyVim starter (decide in Phase 1).
