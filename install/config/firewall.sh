# Allow nothing in, everything out.
#
# ufw only writes rule files here; ufw.service applies them at boot, which is where they were
# always going to take effect (installs are followed by a reboot). But once UFW is marked enabled,
# the ufw command also tries to load the rules into the running kernel -- and that fails outright
# in the window this script runs in on an existing system: oal-bootstrap.sh has just run
# `pacman -Syu`, so if that upgraded the kernel, the running kernel's modules are already gone from
# /usr/lib/modules and nf_tables cannot load. The rules are still written correctly and are correct
# after the reboot, so that specific case is a warning, not a failed install. Anything else is a
# real error and still fails.
running_kernel_modules_present() { [[ -d "/usr/lib/modules/$(uname -r)" ]]; }

ufw_rule() {
  if ufw "$@"; then
    return 0
  fi
  if running_kernel_modules_present; then
    echo "ufw $*: failed" >&2
    return 1
  fi
  echo "warning: 'ufw $*' could not reach the running kernel's netfilter tables." >&2
  echo "         The kernel was upgraded and its modules are no longer on disk; the rule is" >&2
  echo "         written to /etc/ufw and takes effect after the reboot." >&2
  return 0
}

ufw_rule default deny incoming
ufw_rule default allow outgoing

# No LocalSend rule. These two ports were opened on every install for an application that is in
# none of the package lists, which made "allow nothing in" mean "allow nothing in except two ports
# for something you do not have". Whoever installs LocalSend can open them.

# Allow Docker containers to use DNS on host.
ufw_rule allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
ufw_rule allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'allow-docker-dns'

# Do not lock the machine out of its own SSH. Denying everything inbound is the right default for
# a desktop, and Agentarchy does not enable sshd -- but if this particular system has deliberately
# enabled it (a VM, a server, or someone bootstrapping a remote box over SSH right now), then
# closing 22 cuts the only way back in, and they find out after the reboot. Open it only when sshd
# is actually enabled, so the desktop default stays closed.
if systemctl is-enabled sshd.service >/dev/null 2>&1; then
  echo "sshd is enabled here; allowing 22/tcp so this install cannot lock you out"
  ufw_rule allow 22/tcp
fi

# Turn on Docker protections. ufw-docker refuses to install its after.rules
# block unless UFW is already active, but during ISO finalization the target
# chroot shares the live installer's kernel firewall. Keep the live firewall
# untouched: for this config-file-only install action, satisfy ufw-docker's
# status preflight without activating UFW.
install_ufw_docker_rules() {
  local shim_dir status ufw_docker_bin

  ufw_docker_bin=$(command -v ufw-docker)
  shim_dir=$(mktemp -d)
  cat >"$shim_dir/ufw" <<'EOF'
#!/bin/bash
if [[ ${1:-} == "status" ]]; then
  echo "Status: active"
  exit 0
fi

exec /usr/bin/ufw "$@"
EOF

  # The packaged ufw-docker pins PATH internally, so run a temporary copy whose
  # PATH can see the status shim above.
  sed "0,/^PATH=/s#^PATH=.*#PATH=\"$shim_dir:/bin:/usr/bin:/sbin:/usr/sbin:/snap/bin/\"#" \
    "$ufw_docker_bin" >"$shim_dir/ufw-docker"
  chmod 755 "$shim_dir/ufw" "$shim_dir/ufw-docker"

  if "$shim_dir/ufw-docker" install; then
    status=0
  else
    status=$?
  fi

  rm -rf "$shim_dir"
  return "$status"
}

# ufw-docker is AUR-only, and Agentarchy's default install never touches the AUR (it is listed in
# install/agentarchy-aur.packages for people who opt in). Without it there is no shim to install,
# and that is not a failure -- docker's iptables rules simply stay unmanaged by ufw.
if command -v ufw-docker >/dev/null; then
  install_ufw_docker_rules
else
  echo "skipping ufw-docker rules: ufw-docker is not installed (AUR-only, see install/agentarchy-aur.packages)"
fi

# Installs are followed by reboot, so configure UFW to start on the installed
# system instead of mutating the live install session's firewall.
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
systemctl enable ufw
