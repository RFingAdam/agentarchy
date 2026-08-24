#!/usr/bin/env bash
# Turn a vanilla Arch box into Agentarchy.
#
#   from a checkout:  ./oal-bootstrap.sh
#   from anywhere:    curl -fsSL https://raw.githubusercontent.com/RFingAdam/agentarchy/main/oal-bootstrap.sh | bash
#
# Run it as your normal user, not root: makepkg refuses to run as root, and the user steps have to
# land in your home directory. Everything that needs root goes through sudo, so the user needs to
# be a sudoer.
#
# Every step is idempotent -- a second run on the same machine reinstalls the same package set and
# exits, it does not fail.
#
# Environment:
#   OAL_REF=main            branch/tag to clone when piped from curl
#   OAL_CHECKOUT=<dir>      where to clone (default ~/.local/share/oal/checkout)
#   OAL_SKIP_DESKTOP=1      build and install the package, then stop before touching the system
#   OAL_SKIP_MISE=1         skip the mise tool installs (defaulted on, see below)
set -euo pipefail

readonly REPO_URL="https://github.com/RFingAdam/agentarchy"

log() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

if (( EUID == 0 )); then
  die "run this as your normal user, not root -- makepkg refuses to build as root and the user setup needs your home directory"
fi
command -v sudo >/dev/null || die "sudo is required and was not found"

# Where is the tree? If this script is a real file next to a PKGBUILD we are in a checkout and use
# it as-is. If it arrived on stdin from curl there is nothing around it, so clone.
resolve_checkout() {
  local self="${BASH_SOURCE[0]:-}" dir
  if [[ -n $self && -f $self ]]; then
    dir="$(cd -- "$(dirname -- "$self")" && pwd)"
    if [[ -f $dir/PKGBUILD ]]; then
      printf '%s' "$dir"
      return 0
    fi
  fi

  # Only the clone path needs git up front. A checkout already on disk does not: the Arch cloud
  # image ships without git, and pacman installs it a few steps below.
  command -v git >/dev/null || die "git is needed to clone the repository; install it with 'sudo pacman -S git' or run this from a checkout"

  local ref="${OAL_REF:-main}" co="${OAL_CHECKOUT:-$HOME/.local/share/oal/checkout}"
  if [[ -d $co/.git ]]; then
    log "Updating the existing checkout at $co" >&2
    git -C "$co" fetch --depth 1 origin "$ref" >&2
    git -C "$co" checkout -q --detach FETCH_HEAD >&2
  else
    log "Cloning $REPO_URL ($ref) into $co" >&2
    mkdir -p -- "$(dirname -- "$co")"
    git clone --depth 1 --branch "$ref" "$REPO_URL" "$co" >&2
  fi
  printf '%s' "$co"
}

checkout="$(resolve_checkout)"
[[ -f $checkout/PKGBUILD ]] || die "no PKGBUILD in $checkout -- that does not look like an Agentarchy checkout"
user="$(id -un)"

log "Bootstrapping Agentarchy from $checkout as $user"

# The cloud image and any older install ship a keyring too old to verify current packages, and a
# signature failure here looks like a corrupt mirror. Refresh it before anything else.
log "Refreshing the Arch keyring"
# --disable-download-timeout on every pacman call here: pacman aborts a transaction when a mirror
# drops under 1 byte/sec for ten seconds, and a mirror that stalls mid-sync takes the whole install
# down with it ("Operation too slow", nothing installed). That is a reasonable default for someone
# watching a terminal and a bad one for an unattended installer -- two golden-path runs died on it
# in a row, at different points in the package set, on a mirror that was otherwise reachable.
sudo pacman -Sy --noconfirm --disable-download-timeout archlinux-keyring

log "Updating the system and installing build tools"
sudo pacman -Syu --needed --noconfirm --disable-download-timeout base-devel git

log "Building and installing the agentarchy package"
(
  cd "$checkout"
  # --force so a rebuild over an existing artefact is not an error on a second run.
  AGENTARCHY_SRC="$checkout" makepkg --syncdeps --install --force --noconfirm
)

log "Installing the Agentarchy base package set"
sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$checkout/install/agentarchy-base.packages" |
  sudo pacman -S --needed --noconfirm --disable-download-timeout -

if [[ ${OAL_SKIP_DESKTOP:-0} == 1 ]]; then
  log "OAL_SKIP_DESKTOP=1 -- package installed, stopping before the system and user steps"
  exit 0
fi

# install/user/mise.sh network-installs fourteen CLI tools and adds minutes to every run. Until the
# agent layer lands in its own phase and that step becomes a deliberate choice, default it off.
export OAL_SKIP_MISE="${OAL_SKIP_MISE:-1}"

log "Applying system configuration (needs root)"
sudo oal-apply-system --install-user "$user" --first-install

log "Provisioning the user environment"
oal-provision-user --first-install

# Land on a themed desktop instead of stock Breeze. No Plasma session exists during a bootstrap, so
# this writes the colour scheme and points kdeglobals at it; the first login reads that. The
# wallpaper needs a live session and is applied the first time the theme is set inside one.
log "Applying the default theme"
oal-theme-set-kde "${OAL_DEFAULT_THEME:-agentarchy}"

# The greeter is the one surface that needs root, and an install is the last moment we have it
# without asking. After this, retinting the login screen is a deliberate `oal-refresh-sddm <theme>`.
oal-refresh-sddm "${OAL_DEFAULT_THEME:-agentarchy}"

log "Done"
cat <<'NEXT'

Agentarchy is installed. Reboot to land in the Plasma session:

    sudo systemctl reboot

NEXT
