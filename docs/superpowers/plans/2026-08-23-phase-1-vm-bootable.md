# Phase 1 -- Bootable Agentarchy in a VM: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `test/vm/golden-path` boots a vanilla Arch VM, installs Agentarchy from this checkout, reboots, and proves a KDE Plasma 6 Wayland desktop comes up with `oal-*` commands present and one theme applied -- with screenshots pulled out for a human to look at.

**Architecture:** Agentarchy ships as an Arch package (`agentarchy` → `/usr/share/agentarchy`, `oal-*` on PATH, `oal-dev-*` excluded). `oal-bootstrap.sh` turns a vanilla Arch box into Agentarchy: refresh keyring → `pacman -Syu` → build+install the package → install the desktop package list → `oal-apply-system` (root steps) → `oal-provision-user` (user steps) → reboot into SDDM autologin. The VM harness is plain bash + qemu around the official Arch **cloud image** (cloud-init seeds an SSH user), so a full loop is minutes, not an installer script.

**Tech Stack:** bash, pacman/makepkg, qemu-system-x86_64 + OVMF + virtio-gpu, cloud-init (NoCloud), QMP over unix socket, bats, KDE Plasma 6.7 / SDDM / Wayland.

**Spec:** `docs/superpowers/specs/2026-08-22-agentarchy-design.md` (Install model, Packages, Theme engine, Phase 1).

## Global Constraints

- Naming: package/install root `agentarchy` (`/usr/share/agentarchy`); everything terminal-facing is `oal` -- commands `oal-*`, env `OAL_*` (`OAL_PATH=/usr/share/agentarchy`), `~/.config/oal`, `~/.local/state/oal`.
- **Never hand-edit a vendored file** (anything in `upstream/VENDORED-FILES.txt`). Change data files under `upstream/` + re-run `bin/oal-dev-sync-upstream --apply`, or capture the edit with `bin/oal-dev-upstream-patch`. `bin/oal-dev-check` (7 gates) must pass before every commit; `--check` must report no drift.
- The literal `omarchy` may appear only under `upstream/`, `docs/`, `tasks/`, `test/fixtures/`, `test/unit/`, `NOTICE`, `LICENSE`, `README.md`, `CLAUDE.md`, `AGENTS.md`.
- Scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, `shellcheck -S warning -x` clean (native scripts gate; vendored ones do not).
- Only official Arch repos in the default install path. AUR is opt-in and never required to reach a working desktop.
- Conventional commits, no AI co-author trailers. Do not push unless told; the repo is public at `RFingAdam/agentarchy`.
- Working directory for every task: `/home/swamp/projects/github/agentarchy`.

## Verified environment facts (do not re-derive; a spike established these)

- Host `/tmp` is a **2 GB tmpfs** -- VM disks and screendumps MUST live under `.vm/` in the repo (git-ignored), never `/tmp`. Filling tmpfs breaks the guest's I/O *and* the agent harness.
- Host already runs sshd on **2222** -- the harness must pick a free port dynamically.
- QMP unix socket paths must be **< 108 bytes** -- `.vm/qmp.sock` in the repo is fine, deep scratchpad paths are not.
- SSH to the VM needs `-o IdentitiesOnly=yes` or the host agent's keys exhaust auth attempts.
- Arch cloud image: `https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2` (+ `.SHA256`), btrfs, GRUB, cloud-init preinstalled, no default user, 2 GB virtual disk → grow the overlay to 24 G before boot; cloud-init growpart handles the rest. Already cached at `.vm-cache/`.
- Boot-to-SSH is ~50 s with `-smp 6 -m 8192`, `-device virtio-gpu-pci -display none -vga none`, OVMF `_4M` pair (per-VM copy of `OVMF_VARS_4M.fd`).
- Plasma facts: session file is `/usr/share/wayland-sessions/plasma.desktop` → SDDM `Session=plasma`; `kwriteconfig6`/`kreadconfig6` come from **kconfig**, `qdbus6` from **qt6-tools**, the `plasma-apply-*` tools from **plasma-workspace**; `ghostty` is in `extra`. SDDM's Wayland greeter is flagged experimental -- keep the greeter default (X11) and autologin straight into the Wayland session.
- `install/post-install/pacman.sh` (vendored) **overwrites `/etc/pacman.conf` and the mirrorlist with the `.invalid` stubs** -- it must be neutralised in Task 2 or every install ends with a dead pacman.
- Upstream package lists contain 22 AUR-only and ~21 nonexistent packages -- the native list in Task 2 replaces them wholesale.

---

### Task 1: VM harness

**Files:**
- Create: `test/vm/lib.sh`, `test/vm/vm-image`, `test/vm/vm-up`, `test/vm/vm-ssh`, `test/vm/vm-scp`, `test/vm/vm-shot`, `test/vm/vm-down`, `test/vm/README.md`
- Modify: `.gitignore` (already ignores `.vm/`, `.vm-cache/` -- verify)

**Interfaces:**
- Produces, for later tasks: `test/vm/lib.sh` exporting `VM_DIR=$repo/.vm`, `VM_CACHE=$repo/.vm-cache`, `vm_port` (reads `.vm/port`), `vm_ssh <cmd...>`, `vm_scp_from <remote> <local>`, `vm_scp_to <local> <remote>`, `vm_wait_ssh <timeout_s>`, `vm_qmp <json>`, `vm_running`.
- `test/vm/vm-up [--fresh]` boots and blocks until SSH answers; `--fresh` discards `.vm/disk.qcow2` first. Exit non-zero with the serial log's tail on failure.
- `test/vm/vm-shot <out.png> [--guest]` -- default QMP screendump (works even at a TTY/greeter); `--guest` runs `spectacle -b -n -f` inside the session and copies the PNG out.
- Guest user is `oal`, key at `.vm/id_vm` (generated on first `vm-up`, never committed).

- [ ] **Step 1: Write `test/vm/lib.sh` with the pitfalls encoded**

Must include: repo-root resolution, `VM_DIR`/`VM_CACHE` under the repo (assert they are NOT under `/tmp` and fail loudly if someone points them there), free-port selection (`for p in $(seq 2822 2899); do ss -ltn | grep -q ":$p " || break; done`, persisted to `.vm/port`), the SSH option array including `-o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`, and `vm_qmp` using `socat - UNIX-CONNECT:$VM_DIR/qmp.sock` with a `qmp_capabilities` handshake first.

- [ ] **Step 2: Write `test/vm/vm-image`** -- idempotent download+verify of the cloud image into `.vm-cache/` (`curl -fsSL -O` the `.qcow2` and `.SHA256`, then `sha256sum -c`; skip if already valid). Print the build date from the filename listing so a stale cache is visible.

- [ ] **Step 3: Write `test/vm/vm-up`** -- generate `.vm/id_vm` if missing; write cloud-init `user-data` (user `oal`, wheel, NOPASSWD sudo, the pubkey, `ssh_pwauth: false`, `runcmd: systemctl enable --now sshd`) and `meta-data`; `cloud-localds .vm/seed.iso`; `qemu-img create -f qcow2 -F qcow2 -b <cache image> .vm/disk.qcow2 24G`; copy `OVMF_VARS_4M.fd`; launch qemu exactly as in the verified command (q35/kvm/host cpu, `-smp 6 -m 8192`, both pflash drives, disk + seed as virtio, `-device virtio-gpu-pci -display none -vga none`, `-netdev user,hostfwd=tcp:127.0.0.1:$PORT-:22`, `-qmp unix:.vm/qmp.sock,server,nowait`, `-serial file:.vm/serial.log`), record the PID in `.vm/qemu.pid`, then `vm_wait_ssh 300`.

- [ ] **Step 4: Write `vm-ssh`, `vm-scp`, `vm-shot`, `vm-down`** -- thin wrappers over `lib.sh`. `vm-down` kills by PID file and removes the socket. `vm-shot` must convert PPM→PNG with `magick` and fail loudly if the QMP write errors (e.g. ENOSPC).

- [ ] **Step 5: Verify the harness end to end**

Run: `test/vm/vm-image && test/vm/vm-up --fresh && test/vm/vm-ssh 'uname -r; df -h / | tail -1' && test/vm/vm-shot .vm/boot.png && test/vm/vm-down`
Expected: image verified; SSH answers within ~60 s; root filesystem ~24 G; a PNG is produced; the VM stops. Paste the timings into the report.

- [ ] **Step 6: Write `test/vm/README.md`** documenting the loop, every pitfall above (tmpfs, port, socket length, IdentitiesOnly), and how to watch the VM live (`-vnc` note) -- then commit.

```bash
git add test/vm .gitignore && git commit -m "feat(test): VM harness for the Arch cloud-image golden path"
```

---

### Task 2: Distro package lists and pacman config

**Files:**
- Modify: `upstream/VENDOR-MANIFEST` (excludes), `upstream/EXCLUDED-ASSETS.md` (record), then re-run the sync
- Create: `install/agentarchy-base.packages`, `install/agentarchy-desktop.packages`, `install/agentarchy-aur.packages`, `install/desktop/all.sh`, `install/desktop/plasma.sh`
- Test: `test/unit/packages.bats`

**Interfaces:**
- Consumes: `bin/oal-dev-sync-upstream --apply`, the vendored `install/` tree.
- Produces: three flat package lists (one package per line, `#` comments allowed) consumed by `pacman -S --needed -` and later by the ISO's pacstrap; `install/desktop/all.sh` callable from `oal-apply-system` (Task 4 wires it in).

- [ ] **Step 1: Exclude the distro-defining upstream files**

Add to `upstream/VENDOR-MANIFEST` (upstream paths, under a comment explaining that package lists and pacman config are Agentarchy decisions, not upstream's):
```
exclude install/omarchy-base.packages
exclude install/omarchy-other.packages
exclude default/pacman/**
exclude install/post-install/pacman.sh
```
Then `bin/oal-dev-sync-upstream --apply`. Confirm the four paths disappear from `upstream/VENDORED-FILES.txt` and from the tree, and that `install/post-install/all.sh` -- which still calls `pacman.sh` -- is handled: it is vendored, so capture a patch removing that one `run_logged` line:
```bash
# after editing the file, capture it so a re-sync reproduces it
bin/oal-dev-upstream-patch drop-pacman-conf-overwrite install/post-install/all.sh
```
`bin/oal-dev-sync-upstream --check` must end clean.

- [ ] **Step 2: Write `install/agentarchy-base.packages`** -- the CLI/system layer that is not the desktop: base-devel git jq gum bash-completion openssh sudo, networkmanager, pipewire pipewire-pulse wireplumber, cups (+ print-manager comes with the desktop list), bluez bluez-utils, btrfs-progs, snapper, ufw, plymouth, man-db, less, wget curl, unzip, ripgrep fd bat eza fzf zoxide starship tmux lazygit lazydocker htop btop, docker docker-compose, tailscale, syncthing, age, github-cli, nodejs npm, python uv, rustup?, plus fonts (noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-jetbrains-mono-nerd ttf-ia-writer→AUR so **omit**). Only packages that exist in core/extra -- verify EVERY line with the JSON API before committing:
```bash
while read -r p; do [[ -z $p || $p == \#* ]] && continue; \
  curl -fsS "https://archlinux.org/packages/search/json/?name=$p" | jq -e '.results|length>0' >/dev/null || echo "MISSING: $p"; \
done < install/agentarchy-base.packages
```
Expected output: nothing.

- [ ] **Step 3: Write `install/agentarchy-desktop.packages`** -- the verified Plasma set: `plasma-desktop plasma-workspace kwin kscreen plasma-nm plasma-pa powerdevil bluedevil kde-gtk-config breeze-gtk xdg-desktop-portal-kde qt6-wayland xorg-xwayland sddm dolphin konsole spectacle kate ark gwenview okular plasma-systemmonitor kwallet-pam kdeplasma-addons kde-cli-tools systemsettings kconfig qt6-tools ghostty`. Run the same existence check. Add a comment block explaining what we deliberately do NOT take from `plasma-meta` (discover, plasma-welcome, plasma-vault, krdp, oxygen, …) and why.

- [ ] **Step 4: Write `install/agentarchy-aur.packages`** -- opt-in only, one per line with a trailing comment saying what it is: `yay`, `cliamp`, `ttf-ia-writer`, `ufw-docker`. Nothing installs this list in Phase 1; `oal-install-aur` (later phase) will.

- [ ] **Step 5: Write `install/desktop/plasma.sh` and `install/desktop/all.sh`**

`plasma.sh`: `pacman -S --needed --noconfirm -` fed the desktop list (strip comments/blanks with `sed`), enable `sddm.service` and `NetworkManager.service`, write `/etc/sddm.conf.d/10-agentarchy.conf` with the autologin block for `$OAL_INSTALL_USER` and `Session=plasma`, and (idempotently) create `/etc/sddm.conf.d/` first. Must be safe to re-run.
`all.sh`: `run_logged "$OAL_INSTALL/desktop/plasma.sh"` following the vendored `all.sh` convention exactly.

- [ ] **Step 6: Write `test/unit/packages.bats`** -- assert: every line in each list is either a comment/blank or matches `^[a-z0-9@._+-]+$`; no duplicates within or across base/desktop; the three known-bad classes are absent (`grep -E '^(hyprland|quickshell|uwsm|oal-nvim|omacalc|omacut|omawrite|ttfx|herdr|tensaku)$'` finds nothing); `install/desktop/all.sh` references only files that exist.

- [ ] **Step 7: Verify and commit**

Run: `bats test/unit && bin/oal-dev-check`
Expected: all green, 7 PASS.
```bash
git add -A && git commit -m "feat(install): native package lists and Plasma desktop step"
```

---

### Task 3: `agentarchy` package + `oal-bootstrap.sh`

**Files:**
- Create: `PKGBUILD`, `oal-bootstrap.sh`, `.gitignore` additions (`pkg/`, `src/`, `*.pkg.tar.zst`)
- Test: `test/unit/pkgbuild.bats`

**Interfaces:**
- Produces: a package installing the tree to `/usr/share/agentarchy` with `/usr/bin/oal-*` for every `bin/` script **except** `oal-dev-*` and `oal-dev-lib.sh`; `oal-bootstrap.sh` usable as `curl -fsSL <raw>/oal-bootstrap.sh | bash` or `./oal-bootstrap.sh` from a checkout.

- [ ] **Step 1: Write the PKGBUILD** -- `pkgname=agentarchy`, `arch=('any')`, `license=('MIT')`, thin `depends=('bash' 'git' 'jq' 'gum')`, `makedepends=('git')`, `options=('!strip')`, `pkgver()` from `git describe --long --tags || printf 'r%s.%s' <count> <sha>`, and a source that works from a local checkout -- support `AGENTARCHY_SRC` (copy the tree in `prepare()`) with `source=("agentarchy::git+file://$PWD#branch=$(git rev-parse --abbrev-ref HEAD)")` as the default, mirroring upstream's pattern. `package()` copies `bin config default themes applications agents install etc migrations upstream/VENDORED-FILES.txt version` into `/usr/share/agentarchy`, installs each non-dev `bin/*` to `/usr/bin/` and symlinks `/usr/share/agentarchy/bin/<name>` → `/usr/bin/<name>`.

- [ ] **Step 2: Write `test/unit/pkgbuild.bats`** -- parse-only checks that do not need an Arch host: `bash -n PKGBUILD`; sourcing it in a subshell with `srcdir/pkgdir` stubs and asserting `pkgname`/`arch`/`license`/`depends` values; and a guard that the exclusion list in `package()` mentions `oal-dev-`. Run them.

- [ ] **Step 3: Write `oal-bootstrap.sh`** in this order, each step idempotent and logged: refuse to run as root; `sudo pacman -Sy --noconfirm archlinux-keyring`; `sudo pacman -Syu --needed --noconfirm base-devel git`; resolve the checkout (if piped from curl, clone `https://github.com/RFingAdam/agentarchy` into `~/.local/share/oal/checkout` at `${OAL_REF:-main}`); `makepkg -si --noconfirm` (as the invoking non-root user -- document that makepkg refuses root); `sudo pacman -S --needed --noconfirm -` fed `agentarchy-base.packages`; `sudo oal-apply-system --install-user "$USER" --first-install`; `oal-provision-user --first-install`; print what to do next (reboot). Honour `OAL_SKIP_DESKTOP=1` to stop before the desktop step (useful for CI/debug).

- [ ] **Step 4: Verify in the VM (the real test)**

```bash
test/vm/vm-up --fresh
test/vm/vm-scp to . :/home/oal/agentarchy      # rsync the checkout in (exclude .git,.vm,.vm-cache)
test/vm/vm-ssh 'cd ~/agentarchy && ./oal-bootstrap.sh 2>&1 | tail -30'
test/vm/vm-ssh 'pacman -Q agentarchy; command -v oal-theme-set oal-update; ls /usr/share/agentarchy | head; ! command -v oal-dev-sync-upstream && echo "dev tools correctly absent"'
```
Expected: package installed; `oal-*` on PATH; **no** `oal-dev-*` in `/usr/bin`. Capture the full bootstrap log into the report; expect the desktop package install to dominate the runtime.

- [ ] **Step 5: Commit**

```bash
git add PKGBUILD oal-bootstrap.sh test/unit/pkgbuild.bats .gitignore
git commit -m "feat: agentarchy PKGBUILD and oal-bootstrap.sh"
```

---

### Task 4: Boot into Plasma -- wire the desktop step and fix what breaks

**Files:**
- Modify (via `bin/oal-dev-upstream-patch`, never by hand): `bin/oal-apply-system` (source `install/desktop/all.sh` after `config`), and any vendored step the VM proves broken
- Create: `upstream/patches/*.patch` as produced
- Test: extend `test/vm/golden-path` (Task 6)

**Interfaces:**
- Produces: a VM that reboots straight into a Plasma Wayland session as user `oal`, verified by the assertion list below.

- [ ] **Step 1: Patch `oal-apply-system` to run the desktop step**

Edit the vendored file so the ordered chain becomes `config → hardware → **desktop** → login → post-install`, then:
```bash
bin/oal-dev-upstream-patch add-desktop-install-step bin/oal-apply-system
bin/oal-dev-sync-upstream --check   # must be clean
```

- [ ] **Step 2: Run the bootstrap in the VM and reboot**

```bash
test/vm/vm-ssh 'sudo systemctl reboot'; sleep 25; test/vm/vm-ssh true   # wait loop
```

- [ ] **Step 3: Assert the session, with the exact commands**

```bash
test/vm/vm-ssh 'export XDG_RUNTIME_DIR=/run/user/$(id -u)
  sid=$(loginctl list-sessions --no-legend | awk "{print \$1}" | head -1)
  loginctl show-session $sid -p Type -p Class -p State
  ls $XDG_RUNTIME_DIR/wayland-*
  pgrep -a kwin_wayland; pgrep -a plasmashell
  systemctl --user is-active plasma-plasmashell.service
  systemctl is-active sddm'
```
Expected: `Type=wayland`, a `wayland-0` socket, `kwin_wayland` and `plasmashell` running, `plasma-plasmashell.service` active, `sddm` active.

- [ ] **Step 4: Fix what fails, each fix as a patch or a native file**

Known likely failures and the intended fix, in order of probability:
1. A vendored `install/config/*` step calls a script excluded in Phase 0 (`oal-apply-lock`, `oal-shell`, …) → patch that step to skip when the command is absent (`command -v X >/dev/null || return 0`).
2. `install/config/snapper.sh` on a non-btrfs-subvol layout or without `limine-snapper-sync` → patch to no-op unless the tooling exists.
3. `install/config/firewall.sh` needs `ufw-docker` (AUR) → patch to skip the docker shim when absent.
4. `install/user/mise.sh` tries to install 13 CLI tools over the network → patch to honour `OAL_SKIP_MISE=1`, and set that in the bootstrap for now.
5. KWin refuses to start without KMS → the harness already uses `virtio-gpu-pci`, which exposes DRM; if it still fails, capture `journalctl --user -u plasma-kwin_wayland` and the greeter log before changing the GPU model.
Record every patch you create, with the failure it fixes, in the report.

- [ ] **Step 5: Screenshot the desktop both ways and commit**

```bash
test/vm/vm-shot .vm/desktop-qmp.png
test/vm/vm-shot .vm/desktop-guest.png --guest
```
Both must be non-trivial images (> 50 KB, not a black frame -- check with `magick identify -format '%[mean]'`). Commit the patches and any native fixes:
```bash
git add -A && git commit -m "fix(install): make the vendored install steps work on a Plasma VM"
```

---

### Task 5: Placeholder branding assets and a minimal theme apply

**Files:**
- Create: `default/agentarchy/logo.txt` (ASCII wordmark), `default/agentarchy/logo.png` (generated, simple text-on-transparent -- `magick -background none -fill '#7aa2f7' -pointsize 96 label:agentarchy`), `bin/oal-theme-set-kde`
- Modify (patch): `bin/oal-show-logo` and the plymouth/sddm consumers listed in `upstream/EXCLUDED-ASSETS.md` to use the new paths
- Test: `test/unit/theme-kde.bats`

**Interfaces:**
- Produces: `oal-theme-set-kde <theme-name>` -- reads `themes/<name>/colors.toml`, writes `~/.local/share/color-schemes/Agentarchy-<Name>.colors`, applies it with `plasma-apply-colorscheme`, sets the wallpaper with `plasma-apply-wallpaperimage`, writes a Konsole `.colorscheme` and a Ghostty theme file. Must degrade gracefully (log and continue) when a target tool is missing, and be runnable headlessly (`--dry-run` writes files without applying).

- [ ] **Step 1: Write the colors.toml → .colors generator** with the mapping from the spec (background→Window/View BackgroundNormal + WM inactive; lighter_background→Button/Header; foreground→ForegroundNormal; accent→DecorationFocus/DecorationHover/ForegroundActive/WM activeBackground; red/green/yellow/blue→Negative/Positive/Neutral/Link; selection→Selection; muted→ForegroundInactive), emitting every section Breeze ships (`[Colors:Button|Complementary|Header|Selection|Tooltip|View|Window]`, `[General]`, `[KDE]`, `[WM]`) with `R,G,B` decimal triples.

- [ ] **Step 2: Write `test/unit/theme-kde.bats`** -- run `oal-theme-set-kde tokyo-night --dry-run --out $BATS_TEST_TMPDIR` and assert: the `.colors` file exists, has all nine sections, `[General] Name=` matches, every colour line is three integers 0-255, and the Konsole scheme has `Color0`–`Color7` plus Intense variants. Run it (RED), implement, run (GREEN).

- [ ] **Step 3: Apply it in the VM**

```bash
test/vm/vm-ssh 'export XDG_RUNTIME_DIR=/run/user/$(id -u); oal-theme-set-kde tokyo-night; \
  kreadconfig6 --file kdeglobals --group General --key ColorScheme'
test/vm/vm-shot .vm/desktop-themed.png --guest
```
Expected: the scheme name comes back, and the screenshot visibly differs from the pre-theme one (compare `magick identify -format '%[mean]'` of both).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(theme): minimal KDE colour-scheme generator and placeholder branding"
```

---

### Task 6: `golden-path` -- one command, green, with artefacts

**Files:**
- Create: `test/vm/golden-path`, `test/vm/assertions.sh`
- Modify: `bin/oal-dev-check` (add an optional, non-default `vm` gate that just reports whether a golden-path artefact exists and its age), `README.md` (Developing section), `tasks/todo.md`

**Interfaces:**
- Produces: `test/vm/golden-path [--keep]` → boots fresh, rsyncs the checkout, bootstraps, reboots, runs `assertions.sh`, writes `.vm/artifacts/<timestamp>/{desktop-qmp.png,desktop-guest.png,bootstrap.log,assertions.txt}`, prints a PASS/FAIL summary and the artefact path. `--keep` leaves the VM running for poking at.

- [ ] **Step 1: Write `test/vm/assertions.sh`** -- every check from Task 4 Step 3 plus: `oal-version` prints, `/usr/bin/oal-dev-sync-upstream` absent, `pacman -Q agentarchy` succeeds, `systemctl is-enabled sddm`, the applied colour scheme is the Agentarchy one, no `.invalid` host in `/etc/pacman.d/mirrorlist` or `/etc/pacman.conf`, `pacman -Syy` succeeds (proves the mirror config is real). Each assertion prints `PASS <name>` / `FAIL <name> <detail>`; exit non-zero if any failed; always run all of them.

- [ ] **Step 2: Write `test/vm/golden-path`** orchestrating the whole loop with timing per stage, and make failures dump the last 40 lines of `.vm/serial.log` and the guest's `journalctl -b --no-pager | tail -50`.

- [ ] **Step 3: Run it clean, twice** (second run proves idempotency of the bootstrap on an already-provisioned VM -- use `--keep` then re-run the bootstrap step by hand).

Expected: `PASS` for every assertion; total wall time recorded; artefacts written.

- [ ] **Step 4: Document and close out**

`README.md` gains a "Try it in a VM" block (`test/vm/golden-path`). `tasks/todo.md`: tick Phase 1, append a Review-log entry with the assertion output and timings, and add any new owner-actions. Commit:
```bash
git add -A && git commit -m "feat(test): golden-path VM run with assertions and artefacts"
git commit -am "docs: close Phase 1 in tasks/todo.md"
```

---

## Verification (end-to-end)

1. `bin/oal-dev-check` -- 7 gates, including the new bats files, must pass at every commit.
2. `test/vm/golden-path` -- the phase is done when it exits 0 with every assertion PASS and both screenshots show a themed Plasma desktop.
3. Human check: Adam looks at `.vm/artifacts/<latest>/desktop-guest.png` and says whether it looks right (owner-action, recorded in `tasks/todo.md`).
4. No vendored file hand-edited: `bin/oal-dev-sync-upstream --check` clean, every local change present as a numbered patch in `upstream/patches/`.

## Out of scope for Phase 1 (do not drift into these)

Both panel layouts and the layout switcher (Phase 3), the full 22-theme engine and asset audit (Phase 2), the OAL menu (Phase 3), `oal-update`/migrations end-to-end (Phase 4), the agent layer (Phase 5), the ISO (Phase 6). If the VM cannot reach a desktop without one of these, note it and stop -- do not build it here.
