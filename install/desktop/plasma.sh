#!/usr/bin/env bash
# Install the KDE Plasma 6 desktop and point the display manager at it.
#
# Runs as root out of oal-apply-system, possibly in a chroot with no systemd and certainly with no
# graphical session -- so this enables units and writes configuration, and starts nothing. Safe to
# re-run: pacman is --needed, systemctl enable is idempotent, and the SDDM drop-in is rewritten
# wholesale rather than appended to.
set -euo pipefail

OAL_PATH="${OAL_PATH:-/usr/share/agentarchy}"
OAL_INSTALL="${OAL_INSTALL:-$OAL_PATH/install}"
packages_file="$OAL_INSTALL/agentarchy-desktop.packages"

[[ -f $packages_file ]] || { echo "Error: missing $packages_file" >&2; exit 1; }

# One package per line, '#' comments and blank lines stripped. pacman reads the list on stdin, and
# a failure here must stop the install: a half-installed desktop is worse than a clear error.
sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$packages_file" |
  pacman -S --needed --noconfirm --disable-download-timeout -

systemctl enable sddm.service
systemctl enable NetworkManager.service

# The Arch cloud image -- and any minimal install -- boots to multi-user.target, which never pulls
# display-manager.service in. Enabling SDDM is not enough on its own; the default target has to be
# graphical or the machine comes back to a text console with a perfectly configured, unstarted DM.
systemctl set-default graphical.target

# Autologin straight into the Wayland session. The greeter itself stays on its X11 default: SDDM's
# Wayland greeter is flagged experimental upstream, and autologin skips the greeter anyway, so
# there is nothing to gain by taking that risk. Session name is the file stem of
# /usr/share/wayland-sessions/plasma.desktop.
install -d -m 0755 /etc/sddm.conf.d

# Point SDDM at Agentarchy's greeter. etc/sddm.conf.d/10-theme.conf is vendored and says exactly
# this, but nothing installs the etc/ tree yet (Phase 4 decides that per subtree), so the greeter
# theme has been named by a file no SDDM ever read. Written here because this script already owns
# the display manager's configuration.
cat > /etc/sddm.conf.d/10-theme.conf <<'CONF'
[Theme]
Current=oal
CONF
chmod 0644 /etc/sddm.conf.d/10-theme.conf

# The greeter's theme directory and its palette. oal-bootstrap.sh renders the palette during a
# scripted install, while it still has root; an install that never runs the bootstrap would reach
# the login screen with the empty theme.conf the theme directory ships. This unit renders it on the
# way up instead, which covers both paths and leaves a deliberate retint alone.
install -m 0644 "$OAL_INSTALL/desktop/oal-greeter-sync.service" \
  /etc/systemd/system/oal-greeter-sync.service
systemctl enable oal-greeter-sync.service
if [[ -n ${OAL_INSTALL_USER:-} ]]; then
  cat > /etc/sddm.conf.d/10-agentarchy.conf <<CONF
[Autologin]
User=$OAL_INSTALL_USER
Session=plasma
Relogin=false
CONF
  chmod 0644 /etc/sddm.conf.d/10-agentarchy.conf
else
  # Deferred-provisioning installs (the ISO path) have no user yet; first boot creates one and is
  # responsible for writing this drop-in. Leaving a stale autologin block naming nobody would break
  # SDDM outright, so write nothing.
  echo "oal: no install user yet, leaving SDDM autologin unconfigured"
fi
