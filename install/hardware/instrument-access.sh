# Let an agent reach a bench instrument without sudo.
#
# The whole reason this distribution is worth running for hardware work. An MCP server that opens
# /dev/ttyUSB0 is correct code and fails on a stock Arch install, because nothing grants the device
# and every setup guide written on Debian says to join "dialout" -- a group Arch does not have. It
# uses "uucp". Following those instructions here silently does nothing at all, which is the worst
# way for it to fail.
#
# Same shape as input-group.sh: record the group for the deferred-provisioning path, which creates
# the user at first boot, and grant it directly when the user already exists.

if [[ -f "$OAL_PATH/default/udev/oal-instruments.rules" ]]; then
  mkdir -p /etc/udev/rules.d
  install -m644 "$OAL_PATH/default/udev/oal-instruments.rules" \
    /etc/udev/rules.d/70-oal-instruments.rules
  # 70- so it lands after systemd's own uaccess rules (71-seat.rules reads the tag we set).
  udevadm control --reload >/dev/null 2>&1 || true
  udevadm trigger --subsystem-match=tty --subsystem-match=usb >/dev/null 2>&1 || true
fi

provisioning_dir="${OAL_PROVISIONING_DIR:-/var/lib/oal/provisioning}"
mkdir -p "$provisioning_dir"
grep -qxF uucp "$provisioning_dir/groups" 2>/dev/null || echo uucp >>"$provisioning_dir/groups"

if [[ -n ${OAL_INSTALL_USER:-} ]] && getent passwd "$OAL_INSTALL_USER" >/dev/null; then
  usermod -aG uucp "$OAL_INSTALL_USER"
fi
