#!/usr/bin/env bats
#
# The folder colour a palette gets. This is the part of the desktop that used to read as somebody
# else's distribution -- bright blue folders on a warm amber ground -- so the mapping is the feature,
# and a mapping nobody checks drifts into nonsense the first time the scoring is touched.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export PATH="$SRC/bin:$PATH"
  export OAL_PATH="$SRC"
  pick() { oal-theme-set-icons --file "$SRC/themes/$1/colors.toml" --print-colour; }
}

@test "every shipped theme resolves to a folder colour Papirus actually has" {
  # The colour names are Papirus's, not ours: a typo here is a folder icon that silently stays blue.
  local known=" red carmine pink magenta violet indigo blue nordic bluegrey cyan darkcyan teal green yellow orange deeporange brown palebrown paleorange grey black white "
  local d slug got
  for d in "$SRC"/themes/*/; do
    slug="$(basename "$d")"
    got="$(pick "$slug")"
    [ -n "$got" ] || { echo "$slug resolved to nothing"; return 1; }
    [[ $known == *" $got "* ]] || { echo "$slug -> '$got', which Papirus does not ship"; return 1; }
  done
}

@test "the accent's hue is what decides, not its lightness" {
  # Every one of these came out wrong under RGB distance, which lightness dominates: a mint green
  # accent and a lavender one both landed on "palebrown", and a jade one on "bluegrey".
  [ "$(pick hackerman)" != palebrown ]
  [ "$(pick rose-pine)" = violet ]
  [ "$(pick osaka-jade)" = darkcyan ]
  [ "$(pick miasma)" = green ]
}

@test "the warm default gets warm folders and the blue themes get blue ones" {
  [ "$(pick agentarchy)" = orange ]
  [ "$(pick tokyo-night)" = blue ]
  [ "$(pick catppuccin)" = blue ]
}

@test "nord gets the folder colour Papirus named after it" {
  # Papirus ships a "nordic" folder set drawn from this exact palette. Landing anywhere else would
  # mean the scoring is not tracking hue.
  [ "$(pick nord)" = nordic ]
}

@test "a grey accent gets a grey folder rather than a brown one" {
  # Greys and colours never compete: without that guard a desaturated accent scores closest to
  # whichever brown happens to share its lightness.
  local got
  got="$(pick vantablack)"
  [[ $got == grey || $got == black || $got == white ]]
}

@test "without Papirus installed it says so and falls back rather than half-theming the desktop" {
  run env HOME="$BATS_TEST_TMPDIR" oal-theme-set-icons --file "$SRC/themes/agentarchy/colors.toml"
  [ "$status" -eq 0 ]
  # On a machine with Papirus this builds the theme; on one without it explains itself. Either is a
  # pass -- what must never happen is a non-zero exit that takes the whole theme change down.
  [[ $output == *"Papirus"* || $output == *"icons:"* ]]
}
