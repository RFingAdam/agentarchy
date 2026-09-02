#!/usr/bin/env bats
#
# install/agent-layer.sh -- the agent layer on any systemd Linux, without the desktop.
#
# The measurement that justified it: 32 of 344 commands touch pacman and 5 touch KDE. The layer was
# already portable and nothing shipped it that way, so the only route to trying the idea was
# reinstalling your operating system.
#
# The property that has to hold is closure. A named set that quietly calls something outside itself
# installs a command that cannot run, which is this repository's oldest defect wearing a new hat.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  INSTALLER="$SRC/install/agent-layer.sh"
}

layer()    { sed -n '/^LAYER_BIN=(/,/^)/p' "$INSTALLER" | grep -oE '\boal-[a-z0-9-]+\b'; }
optional() { grep '^LAYER_OPTIONAL=' "$INSTALLER" | grep -oE '\boal-[a-z0-9-]+\b'; }

@test "every command the layer names exists in this tree" {
  local c missing=""
  while read -r c; do [ -f "$SRC/bin/$c" ] || missing+="$c "; done < <(layer)
  [ -z "$missing" ] || { echo "named but absent: $missing"; false; }
}

@test "the layer is closed: nothing in it calls out except the documented three" {
  # Anything else is a command that installs and then fails at its first call, on somebody else's
  # machine, where none of our tests run.
  local ok="$BATS_TEST_TMPDIR/ok" c r out=""
  { layer; optional; } | sort >"$ok"
  while read -r c; do
    while read -r r; do
      [ -n "$r" ] || continue
      grep -qx "$r" "$ok" && continue
      [ -f "$SRC/bin/$r" ] && out+="$c -> $r"$'\n'
    done < <(grep -v '^[[:space:]]*#' "$SRC/bin/$c" | grep -oE '\boal-[a-z0-9-]+\*?' | grep -v '\*$' | sort -u)
  done < <(layer)
  [ -z "$out" ] || { echo "calls outside the layer:"; echo "$out"; false; }
}

@test "the documented exceptions stay exactly three, and each is genuinely optional" {
  # If this list grows, someone has excused a real dependency instead of including it.
  [ "$(optional | grep -c .)" -eq 3 ]
  local c
  while read -r c; do
    # Each caller must tolerate the absence. Three spellings count, and all three appear in this
    # tree: `|| true`, a `timeout` wrapper, or a command substitution with stderr discarded, which
    # yields the empty string when the command is not there. oal-brain-state uses the third and
    # reports `theme: unknown`, which is exactly right on a machine with no Agentarchy theme.
    grep -rqE "$c[^|]*\\|\\| *true|timeout [0-9]+ $c|command -v $c|[$]\\($c[^)]*2>/dev/null" "$SRC"/bin/ ||
      { echo "$c is called without tolerating its absence"; false; }
  done < <(optional)
}

@test "it installs none of the desktop" {
  # The point of the layer is that it is not a distribution. If themes or Plasma appear here, the
  # thing being installed is Agentarchy again and the portability claim is gone.
  # Code, not prose: the header contrasts this with oal-bootstrap.sh, which does install all of it.
  ! grep -v '^[[:space:]]*#' "$INSTALLER" | grep -qE 'themes/|plasma|kwriteconfig|greeter|sddm'
}

@test "it names a package manager for every distro it claims to support" {
  local m
  for m in apt-get dnf pacman zypper; do
    grep -q "$m" "$INSTALLER" || { echo "$m is not handled"; false; }
  done
}

@test "removing it is not a one-way door" {
  grep -q -- '--uninstall' "$INSTALLER"
  # And it must remove exactly what it created, by the same list.
  grep -q 'for c in "${LAYER_BIN\[@\]}"' "$INSTALLER"
  # State survives: an audit log is a record, and uninstalling software is not a reason to destroy
  # the evidence of what it decided.
  grep -q 'audit log' "$INSTALLER"
}

@test "it refuses to run as root, like the bootstrap does" {
  grep -q 'EUID != 0' "$INSTALLER"
}

@test "oal-doctor no longer goes blind without pacman" {
  # Three of thirteen checks used to report unknown on anything but Arch, which is a poor advert for
  # a layer whose whole claim is that it runs anywhere.
  grep -q 'pkg_manager()' "$SRC/bin/oal-doctor"
  local m
  for m in apt-get dnf zypper pacman; do
    grep -q "$m" "$SRC/bin/oal-doctor" || { echo "oal-doctor does not know $m"; false; }
  done
}

@test "the package checks read local lists and never the network" {
  # The rule that survives the port: a health report that reaches for a mirror hangs on a train.
  grep -q 'apt list --upgradable' "$SRC/bin/oal-doctor"
  grep -q -- '--cacheonly' "$SRC/bin/oal-doctor"
  grep -q -- '--no-refresh' "$SRC/bin/oal-doctor"
  ! grep -qE '\bapt-get update\b|\bpacman -Sy\b|\bdnf makecache\b' "$SRC/bin/oal-doctor"
}
