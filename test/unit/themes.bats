#!/usr/bin/env bats
#
# All 22 themes, from the committed snapshots in test/fixtures/themes.
#
# Two different jobs here. The snapshot case says "these files changed, was that on purpose" -- it
# cannot know whether a colour is right, only that somebody chose it. The rest are invariants that
# hold for any palette worth shipping, and they are what a snapshot cannot give you: a fixture
# regenerated from a broken template matches itself perfectly.
#
# theme-kde.bats covers oal-theme-set-kde's own behaviour on one theme in depth. This file is the
# breadth pass, and it reads files on disk rather than running the generator 22 times.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIX="$SRC/test/fixtures/themes"
}

# The Breeze sections. A scheme missing one leaves that widget class on the previous theme's
# colours rather than falling back to something sane -- checked here for every theme, not just one.
SECTIONS=(
  "Colors:Button" "Colors:Complementary" "Colors:Header" "Colors:Selection"
  "Colors:Tooltip" "Colors:View" "Colors:Window" "General" "KDE" "WM"
)

# Sum of the three channels, 0-765. The same crude measure oal-theme-color uses to guess a mode when
# a theme does not declare one, so a test built on it agrees with the code by construction.
luminance() {
  local hex="${1#\#}"
  echo $(( 0x${hex:0:2} + 0x${hex:2:2} + 0x${hex:4:2} ))
}

value() { grep "^$2=" "$FIX/$1/sddm.theme.conf" | cut -d= -f2; }

themes() { ls "$SRC/themes"; }

@test "every theme has a snapshot, and every snapshot has a theme" {
  diff <(themes) <(ls "$FIX")
}

@test "the snapshots match what the templates render now" {
  # Deliberately delegated: the generator and the check have to agree, and the only way to be sure
  # of that is for them to be the same code. A failure here means run it and commit, or find out
  # why a palette moved.
  run env OAL_PATH="$SRC" "$SRC/bin/oal-dev-make-theme-fixtures" --check
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "every theme's colour scheme carries every Breeze section" {
  for slug in $(themes); do
    for s in "${SECTIONS[@]}"; do
      grep -qxF "[$s]" "$FIX/$slug/plasma.colors" || { echo "$slug is missing [$s]"; return 1; }
    done
  done
}

@test "every theme's colour scheme names itself" {
  for slug in $(themes); do
    grep -qE '^Name=OAL .+' "$FIX/$slug/plasma.colors" || { echo "$slug has no scheme name"; return 1; }
    grep -qE '^ColorScheme=OAL .+' "$FIX/$slug/plasma.colors" || { echo "$slug names no scheme"; return 1; }
  done
}

@test "every theme's konsole scheme carries all sixteen ANSI colours" {
  for slug in $(themes); do
    for i in $(seq 0 7); do
      grep -qxF "[Color$i]" "$FIX/$slug/konsole.colorscheme" || { echo "$slug: no [Color$i]"; return 1; }
      grep -qxF "[Color${i}Intense]" "$FIX/$slug/konsole.colorscheme" ||
        { echo "$slug: no [Color${i}Intense]"; return 1; }
    done
  done
}

@test "every colour in every scheme is an R,G,B triple in range" {
  for slug in $(themes); do
    while IFS= read -r line; do
      value="${line#*=}"
      [[ $value =~ ^([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3})$ ]] || { echo "$slug: $line"; return 1; }
      for c in "${BASH_REMATCH[@]:1:3}"; do
        (( c <= 255 )) || { echo "$slug: out of range in $line"; return 1; }
      done
    done < <(grep -hE '^(Background[A-Za-z]*|Foreground[A-Za-z]*|Decoration[A-Za-z]*|active[A-Za-z]*|inactive[A-Za-z]*|Color)=' \
      "$FIX/$slug/plasma.colors" "$FIX/$slug/konsole.colorscheme")
  done
}

@test "the theme that says it is light ships a light background" {
  # A declared mode that contradicts the palette is how you get dark icons on a white desktop. All
  # 22 declare one, so this is a cross-check rather than a fallback test.
  for slug in $(themes); do
    mode="$(value "$slug" mode)"
    lum="$(luminance "$(value "$slug" background)")"
    if [[ $mode == light ]]; then
      (( lum > 382 )) || { echo "$slug says light, background luminance $lum"; return 1; }
    else
      (( lum <= 382 )) || { echo "$slug says dark, background luminance $lum"; return 1; }
    fi
  done
}

@test "the light themes are the five we think they are" {
  # Named rather than counted: a theme silently flipping mode changes the icon set, the greeter and
  # the GTK preference at once, and "five light themes" would still be true afterwards.
  expected="catppuccin-latte flexoki-light lupine rose-pine white"
  actual="$(for slug in $(themes); do [[ "$(value "$slug" mode)" == light ]] && echo "$slug"; done | tr '\n' ' ')"
  [ "$(echo "$actual" | xargs)" = "$expected" ]
}

@test "foreground and background are far enough apart to read" {
  # Not a WCAG figure -- the channel sum is too crude for that. It is a floor: the closest theme
  # today sits at 422 of a possible 765, so anything under 250 is a palette that went wrong rather
  # than a palette with low contrast on purpose.
  for slug in $(themes); do
    bg="$(luminance "$(value "$slug" background)")"
    fg="$(luminance "$(value "$slug" foreground)")"
    delta=$(( bg > fg ? bg - fg : fg - bg ))
    (( delta >= 250 )) || { echo "$slug: foreground and background differ by only $delta"; return 1; }
  done
}

@test "the greeter's entry field has a visible edge on every theme" {
  # Main.qml fills the field with lighter_background and outlines it in muted. Two themes --
  # last-horizon and solitude -- define lighter_background as their background, so on those the
  # field is outlined rather than filled. That is a palette's choice and still legible, so the
  # invariant worth holding is the border: if it matched the screen there would be no field at all.
  for slug in $(themes); do
    [ "$(value "$slug" background)" != "$(value "$slug" muted)" ] ||
      { echo "$slug: greeter entry field has no visible edge"; return 1; }
  done
}
