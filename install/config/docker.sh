# Record the docker group for provisioning first-boot user creation and factory reset,
# then grant it directly when the install user already exists (deferred-provisioning
# installs create the user at first boot instead).
provisioning_dir="${OAL_PROVISIONING_DIR:-/var/lib/oal/provisioning}"
mkdir -p "$provisioning_dir"
grep -qxF docker "$provisioning_dir/groups" 2>/dev/null || echo docker >>"$provisioning_dir/groups"

if [[ -n ${OAL_INSTALL_USER:-} ]] && getent passwd "$OAL_INSTALL_USER" >/dev/null; then
  usermod -aG docker "$OAL_INSTALL_USER"
fi
