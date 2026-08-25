#!/usr/bin/env bash
# What "Agentarchy booted correctly" means, as executable assertions. Runs INSIDE the guest --
# test/vm/golden-path feeds it on stdin over ssh, so it must not depend on the repo being synced.
#
# Every assertion runs even after one fails: a boot that reaches Plasma but has a dead pacman is a
# different bug from one that never reaches Plasma, and a run that stops at the first failure hides
# the second. Prints one PASS/FAIL line per check and exits 1 if any failed.

set -u

pass=0
fail=0
ok()   { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf 'FAIL %s: %s\n' "$1" "${2:-}"; fail=$((fail + 1)); }

# assert <name> <command...> -- passes when the command exits 0, and reports its output when not.
assert() {
  local name="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then ok "$name"; else bad "$name" "${out:-exit $?}"; fi
}

XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR

# --- the desktop session ------------------------------------------------------------------------

session_id="$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | head -n1)"
if [[ -z $session_id ]]; then
  bad session "no logind session at all"
else
  session_props="$(loginctl show-session "$session_id" -p Type -p Class -p State 2>/dev/null)"
  grep -q '^Type=wayland' <<<"$session_props" && ok session-wayland || bad session-wayland "$session_props"
  grep -q '^Class=user'   <<<"$session_props" && ok session-user    || bad session-user "$session_props"
  grep -q '^State=active' <<<"$session_props" && ok session-active  || bad session-active "$session_props"
fi

socket="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' 2>/dev/null | head -n1)"
[[ -n $socket ]] && ok wayland-socket || bad wayland-socket "nothing matching wayland-* in $XDG_RUNTIME_DIR"

assert compositor pgrep -x kwin_wayland
assert plasmashell pgrep -x plasmashell
assert plasmashell-unit systemctl --user is-active plasma-plasmashell.service
assert sddm-active systemctl is-active sddm
assert sddm-enabled systemctl is-enabled sddm

# The login screen's palette. The greeter runs as the sddm user before any session exists, so the
# only channel it has is theme.conf under /usr/share -- and the copy that ships carries a [General]
# header and no keys, which renders on Main.qml's literal fallbacks in a palette nobody chose.
assert greeter-sync-enabled systemctl is-enabled oal-greeter-sync.service
greeter_conf=/usr/share/sddm/themes/oal/theme.conf
greeter_bg="$(sed -n 's/^background=//p' "$greeter_conf" 2>/dev/null)"
want_bg="$(oal-theme-color --file "/usr/share/agentarchy/themes/$(oal-theme-default)/colors.toml" background 2>/dev/null)"
if [[ -z $greeter_bg ]]; then
  bad greeter-palette "no background= in $greeter_conf -- the greeter is on Main.qml's fallbacks"
elif [[ $greeter_bg != "$want_bg" ]]; then
  bad greeter-palette "greeter background=$greeter_bg, installed theme is $want_bg"
else
  ok greeter-palette
fi

target="$(systemctl get-default 2>/dev/null)"
[[ $target == graphical.target ]] && ok default-target || bad default-target "get-default = $target"

# --- the installed system -----------------------------------------------------------------------

assert package-installed pacman -Q agentarchy

version="$(oal-version 2>/dev/null)"
[[ -n $version ]] && ok oal-version || bad oal-version "printed nothing"

commands="$(compgen -c 'oal-' 2>/dev/null | sort -u | wc -l)"
(( commands > 100 )) && ok oal-commands || bad oal-commands "only $commands oal-* commands on PATH"

# Repo tooling resolves the checkout by finding upstream/PIN above itself, so it is meaningless on an
# installed system. Its presence would mean the PKGBUILD linked the whole bin/ directory blindly.
dev_tools="$(ls /usr/bin/oal-dev-* 2>/dev/null | wc -l)"
(( dev_tools == 0 )) && ok no-dev-tools || bad no-dev-tools "$dev_tools oal-dev-* commands in /usr/bin"

# A login shell must have OAL_PATH: vendored commands resolve their own tree through it, and a
# shell without it reads from '/' and silently does nothing.
login_path="$(bash -lc 'printf %s "${OAL_PATH:-}"' 2>/dev/null)"
[[ $login_path == /usr/share/agentarchy ]] && ok oal-path-login || bad oal-path-login "OAL_PATH='${login_path:-unset}' in a login shell"

logo="$(bash -lc 'oal-show-logo' 2>/dev/null | tr -d '[:space:]')"
[[ -n $logo ]] && ok branding-logo || bad branding-logo "oal-show-logo printed nothing"

# The dock pins launchers by desktop entry id. An id nothing installed draws a blank icon that does
# nothing when clicked, and neither Plasma nor the layout script complains -- the layout applies
# cleanly and the panel count is right, so every assertion around it passes.
missing_launchers=""
for id in $(grep -ho 'applications:[a-zA-Z0-9._-]*\.desktop' /usr/share/agentarchy/default/layouts/*.js 2>/dev/null |
            sed 's/applications://' | sort -u); do
  [[ -f /usr/share/applications/$id || -f $HOME/.local/share/applications/$id ]] ||
    missing_launchers="$missing_launchers $id"
done
[[ -z $missing_launchers ]] && ok layout-launchers ||
  bad layout-launchers "pinned but not installed:$missing_launchers"

# --- theming ------------------------------------------------------------------------------------

scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
[[ $scheme == OAL\ * ]] && ok colour-scheme || bad colour-scheme "kdeglobals ColorScheme = '${scheme:-unset}'"

# Naming a scheme is not wearing it. kdeglobals has to carry the colours themselves, or the session
# renders stock Breeze while claiming to be themed -- the exact bug the first golden-path run hid.
kde_bg="$(kreadconfig6 --file kdeglobals --group Colors:Window --key BackgroundNormal 2>/dev/null)"
scheme_file="$HOME/.local/share/color-schemes/$scheme.colors"
if [[ ! -f $scheme_file ]]; then
  bad colour-applied "no scheme file at $scheme_file"
elif [[ -z $kde_bg ]]; then
  bad colour-applied "kdeglobals has no Colors:Window BackgroundNormal"
else
  want="$(awk -F= '/^\[Colors:Window\]/ { f = 1; next } f && /^BackgroundNormal=/ { print $2; exit }' "$scheme_file")"
  [[ $kde_bg == "$want" ]] && ok colour-applied || bad colour-applied "kdeglobals has $kde_bg, the scheme says $want"
fi

# --- pacman really works ------------------------------------------------------------------------

# The vendored pacman stubs pointed every repo at *.invalid hosts. They are excluded from vendoring
# now, and this is the assertion that keeps them out: a mirrorlist that cannot resolve turns every
# later phase's install step into a mystery.
if grep -rqs '\.invalid' /etc/pacman.conf /etc/pacman.d/mirrorlist; then
  bad pacman-config "an .invalid host is still configured"
else
  ok pacman-config
fi
assert pacman-sync sudo pacman -Syy --noconfirm

# --- shipped user configuration -------------------------------------------------------------------

# config/ is ~/.config, delivered through /etc/skel. It was vendored and never installed, so none of
# it reached a home directory -- and four of these files `include` a path the theme engine renders on
# every theme change, which meant the terminal half of the theme engine was writing files that no
# config opened. Checked here rather than per theme: delivery is an install-time property.
for pair in "ghostty/config" "kitty/kitty.conf" "alacritty/alacritty.toml" "foot/foot.ini"; do
  cfg="$HOME/.config/$pair"
  name="config-${pair%%/*}"
  if [[ ! -f $cfg ]]; then
    bad "$name" "not delivered to \$HOME/.config"
    continue
  fi
  # And the themed file it points at has to exist, or the include is decoration.
  # '=' is excluded from the leading class because foot.ini writes `include=~/path` with no space,
  # and a greedy match swallows the `include=` prefix and then looks for a file by that name.
  target="$(grep -oE '[^ "=]*current/theme/[^ ",]*' "$cfg" | head -n1)"
  target="${target/#\~/$HOME}"
  if [[ -z $target ]]; then
    bad "$name" "no themed include"
  elif [[ -f $target ]]; then
    ok "$name"
  else
    bad "$name" "includes $target, which does not exist"
  fi
done

# --- the SSH lockout regression -------------------------------------------------------------------

# Phase 1 found this the hard way: ufw came up with 'default deny incoming' and closed the only way
# back into the machine. The desktop default stays closed; a box running sshd must keep 22 open.
if systemctl is-enabled sshd.service >/dev/null 2>&1; then
  if sudo ufw status 2>/dev/null | grep -qE '^22/tcp +ALLOW'; then
    ok ufw-ssh-open
  else
    bad ufw-ssh-open "sshd is enabled but ufw does not allow 22/tcp"
  fi
else
  ok ufw-ssh-open  # no sshd, nothing to keep open
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
