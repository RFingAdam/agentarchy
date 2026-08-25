#!/usr/bin/env bash
# What "the theme actually applied" means, as executable assertions. Runs INSIDE the guest --
# test/vm/golden-path feeds it on stdin over ssh with the theme slug as $1, so it must not depend
# on the synced checkout; everything it reads is the installed tree under /usr/share/agentarchy.
#
# Phase 1's lesson, which this file exists because of: every assertion passed while the desktop
# rendered stock Breeze. Naming a colour scheme is not applying one. So these compare the values in
# kdeglobals against the scheme oal-theme-render produces for the same palette, rather than trusting
# that a name was written.
#
# Like assertions.sh, every check runs even after one fails.

set -u

slug="${1:?theme slug}"

# golden-path feeds this to `bash -s` over ssh, which is neither a login nor an interactive shell, so
# /etc/profile.d/oal.sh has not run and OAL_PATH is unset. oal-theme-dir reads it directly and would
# answer "/themes/<slug>". The oal-* commands that derive it themselves do not care either way.
export OAL_PATH="${OAL_PATH:-/usr/share/agentarchy}"
pass=0
fail=0
ok()  { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s: %s\n' "$1" "${2:-}"; fail=$((fail + 1)); }

theme_dir="$(oal-theme-dir "$slug")"
colors="$theme_dir/colors.toml"
[[ -f $colors ]] || { printf 'FAIL theme-dir: no colors.toml at %s\n' "$colors"; exit 1; }

title="$(echo "$slug" | tr '-' ' ' | sed -E 's/(^| )([a-z])/\1\u\2/g')"
scheme_name="OAL $title"
mode="$(oal-theme-color --file "$colors" mode)"

# The scheme this palette should have produced. Comparing against a fresh render rather than against
# hard-coded values keeps this honest when a template changes: if the template is wrong, the unit
# snapshots catch it; if the apply is wrong, this does.
expected="$(mktemp)"
trap 'rm -f -- "$expected"' EXIT
oal-theme-render plasma.colors --file "$colors" --name "$scheme_name" >"$expected"

want() { # want <group> <key> -- the value the rendered scheme carries
  awk -v g="[$1]" -v k="$2" '
    $0 == g { in_g = 1; next }
    /^\[/   { in_g = 0 }
    in_g && index($0, k "=") == 1 { sub(/^[^=]*=/, ""); print; exit }
  ' "$expected"
}

# --- the colour scheme ---------------------------------------------------------------------------

got="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
[[ $got == "$scheme_name" ]] && ok colorscheme-name || bad colorscheme-name "kdeglobals says '$got', wanted '$scheme_name'"

# A representative spread rather than all ninety keys: the window and view backgrounds are what you
# see, the WM colours are the titlebar, and the negative colour is the one a half-applied scheme
# most often leaves on the previous palette.
for pair in "Colors:Window BackgroundNormal" "Colors:View BackgroundNormal" \
            "Colors:Window ForegroundNormal" "Colors:Button BackgroundNormal" \
            "WM activeBackground" "Colors:Window ForegroundNegative"; do
  set -- $pair
  w="$(want "$1" "$2")"
  g="$(kreadconfig6 --file kdeglobals --group "$1" --key "$2" 2>/dev/null)"
  if [[ -z $w ]]; then
    bad "colours-$1-$2" "the rendered scheme has no such key"
  elif [[ $g == "$w" ]]; then
    ok "colours-$1-$2"
  else
    bad "colours-$1-$2" "kdeglobals has '$g', the palette says '$w'"
  fi
done

# --- icons ----------------------------------------------------------------------------------------

got="$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null)"
[[ $got == OAL ]] && ok "icons-$mode" || bad "icons-$mode" "kdeglobals says '$got', wanted 'OAL'"

# The polarity still has to be right underneath: light folders inherited from Papirus-Dark on a
# white desktop is the same bug the old Breeze check existed to catch.
want_base=Papirus-Dark
[[ $mode == light ]] && want_base=Papirus-Light
index="${XDG_DATA_HOME:-$HOME/.local/share}/icons/OAL/index.theme"
grep -q "^Inherits=$want_base," "$index" 2>/dev/null &&
  ok "icons-inherits-$mode" || bad "icons-inherits-$mode" "$index does not inherit $want_base"

# And the folder actually points at the colour this palette resolves to. Naming an icon theme is not
# applying one -- the same lesson the colour-scheme checks above exist because of.
want_colour="$(oal-theme-set-icons --file "$colors" --print-colour 2>/dev/null)"
link="$(readlink -f "${XDG_DATA_HOME:-$HOME/.local/share}/icons/OAL/64x64/places/folder.svg" 2>/dev/null)"
if [[ -z $want_colour ]]; then
  bad icons-folder-colour "oal-theme-set-icons resolved no colour for this palette"
elif [[ $(basename "${link:-}") == "folder-$want_colour.svg" ]]; then
  # The ordinary-folder alias too. Checking only folder.svg passed while every plain folder on the
  # desktop was still blue, because KDE never asks for folder -- it asks for inode-directory.
  inode="$(readlink -f "${XDG_DATA_HOME:-$HOME/.local/share}/icons/OAL/64x64/places/inode-directory.svg" 2>/dev/null)"
  if [[ $(basename "${inode:-}") == "folder-$want_colour.svg" ]]; then
    ok "icons-folder-$want_colour"
  else
    bad icons-folder-colour "inode-directory.svg -> ${inode:-nothing}, wanted folder-$want_colour.svg"
  fi
else
  bad icons-folder-colour "folder.svg -> ${link:-nothing}, wanted folder-$want_colour.svg"
fi

# --- konsole ---------------------------------------------------------------------------------------

profile="${XDG_DATA_HOME:-$HOME/.local/share}/konsole/Agentarchy.profile"
got="$(kreadconfig6 --file "$profile" --group Appearance --key ColorScheme 2>/dev/null)"
[[ $got == "$scheme_name" ]] && ok konsole-profile || bad konsole-profile "profile says '$got', wanted '$scheme_name'"
scheme_file="${XDG_DATA_HOME:-$HOME/.local/share}/konsole/$scheme_name.colorscheme"
[[ -s $scheme_file ]] && ok konsole-scheme-file || bad konsole-scheme-file "missing or empty: $scheme_file"

# --- wallpaper -------------------------------------------------------------------------------------

# plasma-apply-wallpaperimage writes into the shell's containment config. Assert the path it names
# belongs to this theme and still exists: a wallpaper key pointing at last theme's file is exactly
# the failure the desktop shows and no other check notices.
appletsrc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
if [[ -f $appletsrc ]]; then
  paper="$(grep -oE '^Image=.*' "$appletsrc" | tail -n1 | cut -d= -f2-)"
  paper="${paper#file://}"
  if [[ -z $paper ]]; then
    bad wallpaper "no Image= in $appletsrc"
  elif [[ $paper != "$theme_dir"/* ]]; then
    bad wallpaper "points outside the theme: $paper"
  elif [[ ! -f $paper ]]; then
    bad wallpaper "names a file that does not exist: $paper"
  else
    ok wallpaper
  fi
else
  bad wallpaper "no $appletsrc (has plasmashell ever run?)"
fi

# --- lock screen -------------------------------------------------------------------------------------

lock="$(kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image \
  --group General --key Image 2>/dev/null)"
lock="${lock#file://}"
if [[ -z $lock ]]; then
  bad lock-wallpaper "kscreenlockerrc carries no Image"
elif [[ $lock != "$theme_dir"/* ]]; then
  bad lock-wallpaper "points outside the theme: $lock"
elif [[ ! -f $lock ]]; then
  bad lock-wallpaper "names a file that does not exist: $lock"
else
  ok lock-wallpaper
fi

# --- the two halves agree -----------------------------------------------------------------------

# oal-theme-set-kde moves the desktop; oal-theme-set's template pass moves the eighteen config files
# that terminals, editors and the prompt read. Nothing forces them to be the same theme, and when
# they are not the machine is visibly in two themes at once -- amber desktop, blue prompt. This is
# the check that says so.
name_file="$HOME/.local/state/oal/current/theme.name"
if [[ -f $name_file ]]; then
  templated="$(<"$name_file")"
  [[ $templated == "$slug" ]] && ok templates-match-desktop ||
    bad templates-match-desktop "desktop is '$slug', templated configs are '$templated'"
else
  bad templates-match-desktop "no $name_file: the template pass has never run"
fi

printf '\n%s: %d passed, %d failed\n' "$slug" "$pass" "$fail"
(( fail == 0 ))
