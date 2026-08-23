# Configure pacman after package installation completes. Offline target package
# installs use the live ISO's offline pacman.conf until this final restore.
cp -f "$OAL_PATH/default/pacman/pacman-${OAL_MIRROR:-stable}.conf" /etc/pacman.conf
cp -f "$OAL_PATH/default/pacman/mirrorlist-${OAL_MIRROR:-stable}" /etc/pacman.d/mirrorlist

# oal-settings skips this override until cups-browsed is actually present
# to avoid pacman creating cups-browsed.conf.pacnew during ISO package install.
if [[ -f $OAL_PATH/etc-overrides/cups-cups-browsed.conf && -d /etc/cups ]]; then
  cp -f "$OAL_PATH/etc-overrides/cups-cups-browsed.conf" /etc/cups/cups-browsed.conf
  rm -f /etc/cups/cups-browsed.conf.pacnew
fi

source "$OAL_INSTALL/hardware/pacman.sh"
