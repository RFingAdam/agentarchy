#!/usr/bin/env bats
#
# The native package lists are what turns a vanilla Arch box into Agentarchy, so they get the same
# treatment as code. These checks are offline and structural; the "does this package exist in
# core/extra" question is answered against the archlinux.org API when a list changes (the loop is
# in the Phase 1 plan) rather than on every test run, because a unit suite must not need network.

setup() {
  # comm compares byte by byte; sort respects the locale. Without this the two disagree about order
  # under any UTF-8 locale and comm refuses the input.
  export LC_ALL=C
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  BASE="$SRC/install/agentarchy-base.packages"
  DESKTOP="$SRC/install/agentarchy-desktop.packages"
  AUR="$SRC/install/agentarchy-aur.packages"
}

# Strip '#' comments and blank lines exactly the way the install scripts do.
entries() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]//g' "$@"; }

@test "all three package lists exist and are non-empty" {
  for f in "$BASE" "$DESKTOP" "$AUR"; do
    [ -s "$f" ]
    [ "$(entries "$f" | wc -l)" -gt 0 ]
  done
}

@test "every entry is a plausible pacman package name" {
  for f in "$BASE" "$DESKTOP" "$AUR"; do
    while read -r p; do
      [[ $p =~ ^[a-z0-9@._+-]+$ ]] || { echo "bad package name in $f: '$p'"; return 1; }
    done < <(entries "$f")
  done
}

@test "no duplicates within any one list" {
  for f in "$BASE" "$DESKTOP" "$AUR"; do
    dupes="$(entries "$f" | sort | uniq -d)"
    [ -z "$dupes" ] || { echo "duplicate entries in $f: $dupes"; return 1; }
  done
}

@test "base and desktop do not overlap" {
  # The desktop list is installed on top of the base list; repeating a package across the two hides
  # which layer actually owns it.
  overlap="$(entries "$BASE" "$DESKTOP" | sort | uniq -d)"
  [ -z "$overlap" ] || { echo "package listed in both base and desktop: $overlap"; return 1; }
}

@test "the AUR list never leaks into the lists that install by default" {
  # Reaching a working desktop must never require the AUR.
  leaked="$(entries "$BASE" "$DESKTOP" | sort -u | comm -12 - <(entries "$AUR" | sort -u))"
  [ -z "$leaked" ] || { echo "AUR-only package in a default list: $leaked"; return 1; }
}

@test "upstream's compositor and AUR-only packages are gone" {
  # The classes that made upstream's lists unusable for us: the Hyprland/Quickshell desktop we
  # replaced with Plasma, and names that do not resolve in core/extra at all.
  run grep -nEx '(hyprland|hyprland-qtutils|hypridle|hyprlock|hyprsunset|hyprpicker|quickshell|uwsm|xdg-desktop-portal-hyprland|gtk4-layer-shell|walker|oal-nvim|omacalc|omacut|omawrite|ttfx|herdr|tensaku|ttf-ia-writer)' "$BASE" "$DESKTOP"
  [ "$status" -ne 0 ]
}

@test "the desktop list installs Plasma on Wayland with a display manager" {
  for p in plasma-desktop plasma-workspace kwin sddm qt6-wayland; do
    entries "$DESKTOP" | grep -qx "$p" || { echo "desktop list is missing $p"; return 1; }
  done
}

@test "the base list stays headless" {
  # Anything that only makes sense with a GUI belongs in the desktop list.
  run grep -nEx '(plasma-.*|kwin|sddm|dolphin|konsole|kate|spectacle|ghostty|breeze.*)' "$BASE"
  [ "$status" -ne 0 ]
}

@test "install/desktop/all.sh only references scripts that exist" {
  all="$SRC/install/desktop/all.sh"
  [ -f "$all" ]
  while read -r script; do
    rel="${script#\$OAL_INSTALL/}"
    [ -f "$SRC/install/$rel" ] || { echo "install/desktop/all.sh references missing $rel"; return 1; }
  done < <(grep -oE '"\$OAL_INSTALL/[^"]+"' "$all" | tr -d '"')
}

@test "plasma.sh reads the desktop list and enables, never starts, its units" {
  plasma="$SRC/install/desktop/plasma.sh"
  grep -q 'agentarchy-desktop.packages' "$plasma"
  grep -q 'systemctl enable sddm.service' "$plasma"
  # A start/restart here would blow up in a chroot, where the ISO runs this.
  run grep -nE 'systemctl (start|restart)' "$plasma"
  [ "$status" -ne 0 ]
}

@test "the SDDM drop-in autologins into the Wayland session without the experimental greeter" {
  plasma="$SRC/install/desktop/plasma.sh"
  grep -q '/etc/sddm.conf.d/10-agentarchy.conf' "$plasma"
  grep -q 'Session=plasma' "$plasma"
  run grep -n 'DisplayServer=wayland' "$plasma"
  [ "$status" -ne 0 ]
}

@test "every shipped unit either has its binary or refuses to start without it" {
  # oal-fcitx5.service was enabled at first run on every machine while fcitx5 was in no package
  # list. With Restart=always and RestartSec=2 it failed at EXEC and kept failing until systemd's
  # rate limiter stopped it, on every single boot. Nothing noticed, because a user unit failing
  # quietly looks exactly like one that is not needed.
  local unit exec bin missing=""
  for unit in "$SRC"/default/systemd/user/*.service; do
    exec="$(grep -m1 '^ExecStart=' "$unit" | sed 's/^ExecStart=//' | awk '{print $1}')"
    [[ $exec == /* ]] || continue
    bin="$(basename "$exec")"
    # Ours, so it ships with the package and cannot go missing separately.
    [ -x "$SRC/bin/$bin" ] && continue
    # Anything else must decline to start rather than fail in a loop, whether or not we also list
    # the package. "It is in a package list" is not a guarantee: a package can be removed, and a
    # binary's name is frequently not its package's -- bt-agent comes from bluez-tools, which is
    # exactly the mapping this test cannot do offline and should not try to.
    grep -q "^ConditionPathExists=$exec" "$unit" && continue
    missing+="$(basename "$unit") -> $exec"$'\n'
  done
  [ -z "$missing" ] || {
    echo "units running a binary we do not ship, with no ConditionPathExists to guard it:"
    echo "$missing"; false; }
}
