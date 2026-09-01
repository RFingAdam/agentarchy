# Set links for Nautilus action icons
mkdir -p /usr/share/icons/Yaru/scalable/actions
ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg \
          /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg \
          /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg
gtk-update-icon-cache /usr/share/icons/Yaru &>/dev/null || true

# Chromium's managed-policy directory, so a theme change can tint the browser chrome.
#
# NOT world-writable. `chmod a+rw` here handed every local process the ability to write enterprise
# policy that applies to every account on the machine -- forced extensions, proxy, URL blocklist,
# DevTools -- which is a great deal of authority to trade for a title-bar colour. The desktop
# package list already makes exactly this argument about oal-install-browser and then this ran on
# every install anyway.
#
# The theme writer needs to be able to write here as the logged-in user, so the directory is owned
# by a group and left group-writable, with the install user added to it. Anyone not in the group
# gets read-only, which is what the browser itself needs.
groupadd -r oal-policy 2>/dev/null || true
mkdir -p /etc/chromium/policies/managed
chgrp -R oal-policy /etc/chromium/policies 2>/dev/null || true
chmod 2775 /etc/chromium/policies/managed
if [[ -n ${OAL_INSTALL_USER:-} ]]; then
  usermod -aG oal-policy "$OAL_INSTALL_USER" 2>/dev/null || true
else
  # Deferred-provisioning installs create the user at first boot; record the grant the way
  # install/hardware/instrument-access.sh does for uucp.
  mkdir -p /var/lib/oal/provisioning
  grep -qxF oal-policy /var/lib/oal/provisioning/groups 2>/dev/null ||
    echo oal-policy >>/var/lib/oal/provisioning/groups
fi

# Default Chromium to follow system appearance ("device") instead of dark
mkdir -p /usr/lib/chromium
echo '{"browser":{"theme":{"color_scheme":0,"color_scheme2":0}}}' > \
  /usr/lib/chromium/initial_preferences
