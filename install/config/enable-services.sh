# Enable services only. Installs are followed by reboot, so don't start/reload
# daemons mid-install. UFW and hardware-gated services stay in their own scripts.
#
# Which units exist is decided by install/agentarchy-*.packages, and that set is Agentarchy's to
# change -- so enabling a unit whose package we do not install must skip, not abort the whole
# system setup. The check reads the filesystem rather than asking systemd, because this also runs
# in the ISO's target chroot where there is no systemd to ask.
enable_unit() {
  local unit="$1"
  if [[ -f /usr/lib/systemd/system/$unit || -f /etc/systemd/system/$unit ]]; then
    systemctl enable "$unit"
  else
    echo "skipping $unit: not installed"
  fi
}

enable_unit cups.service
enable_unit cups-browsed.service
enable_unit avahi-daemon.service
enable_unit linux-modules-cleanup.service
enable_unit docker.socket
enable_unit systemd-resolved.service
enable_unit NetworkManager.service
# Don't let network-online.target (pulled in by cups-browsed) hold up
# graphical.target waiting for DHCP/Wi-Fi association. Nothing in the session
# needs to block on the network. Mirrors the systemd-networkd-wait-online mask
# in install/hardware/network.sh.
systemctl mask NetworkManager-wait-online.service
enable_unit power-profiles-daemon.service
enable_unit sddm.service
# Kill one runaway app scope instead of letting reclaim thrashing take the
# whole session down. [Install] pulls in systemd-oomd.socket via Also=, which
# is what the user manager reports app.slice candidacy over.
enable_unit systemd-oomd.service
