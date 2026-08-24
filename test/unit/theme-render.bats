#!/usr/bin/env bats
#
# oal-theme-render is the single substitution path for themed templates outside a theme-set. Its
# contract is narrow and worth pinning: same placeholders as the vendored renderer, user templates
# win, and a placeholder the palette cannot fill is an error rather than a half-written config.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  COLORS="$SRC/themes/tokyo-night/colors.toml"
  HOME="$BATS_TEST_TMPDIR/home"        # keep the real ~/.config/oal out of every case
  mkdir -p "$HOME"
  export HOME
  render() { env OAL_PATH="$SRC" "$SRC/bin/oal-theme-render" "$@"; }
}

@test "renders a template with nothing left unsubstituted" {
  run render plasma.colors --file "$COLORS"
  [ "$status" -eq 0 ]
  [[ $output != *"{{"* ]]
  [[ $output == *"[Colors:Window]"* ]]
}

@test "hex, stripped-hex and rgb forms of a colour are all available" {
  cat >"$BATS_TEST_TMPDIR/probe.tpl" <<'TPL'
hex={{ accent }}
strip={{ accent_strip }}
rgb={{ accent_rgb }}
TPL
  mkdir -p "$HOME/.config/oal/themed"
  cp "$BATS_TEST_TMPDIR/probe.tpl" "$HOME/.config/oal/themed/probe.tpl"
  run render probe --file "$COLORS"
  [ "$status" -eq 0 ]
  [[ $output == *"hex=#7aa2f7"* ]]
  [[ $output == *"strip=7aa2f7"* ]]
  [[ $output == *"rgb=122,162,247"* ]]
}

@test "the scheme name defaults to the theme directory and can be overridden" {
  run render plasma.colors --file "$COLORS"
  [[ $output == *"Name=OAL Tokyo Night"* ]]
  run render plasma.colors --file "$COLORS" --name "Something Else"
  [[ $output == *"Name=Something Else"* ]]
}

@test "a user template beats the packaged one" {
  mkdir -p "$HOME/.config/oal/themed"
  echo 'mine={{ background }}' >"$HOME/.config/oal/themed/plasma.colors.tpl"
  run render plasma.colors --file "$COLORS"
  [ "$status" -eq 0 ]
  [ "$output" = "mine=#1a1b26" ]
}

@test "a placeholder the palette cannot fill fails loudly" {
  mkdir -p "$HOME/.config/oal/themed"
  echo 'x={{ no_such_colour }}' >"$HOME/.config/oal/themed/broken.tpl"
  run render broken --file "$COLORS"
  [ "$status" -ne 0 ]
  [[ $output == *"no_such_colour"* ]]
}

@test "an unknown template and a missing palette both fail" {
  run render nope --file "$COLORS"
  [ "$status" -ne 0 ]
  run render plasma.colors --file "$BATS_TEST_TMPDIR/absent.toml"
  [ "$status" -ne 0 ]
}

@test "every shipped theme renders both KDE templates" {
  for dir in "$SRC"/themes/*/; do
    [ -f "$dir/colors.toml" ] || continue
    for tpl in plasma.colors konsole.colorscheme; do
      run render "$tpl" --file "$dir/colors.toml"
      [ "$status" -eq 0 ] || { echo "$(basename "$dir") / $tpl failed: $output"; return 1; }
      [[ $output != *"{{"* ]] || { echo "$(basename "$dir") / $tpl left a placeholder"; return 1; }
    done
  done
}
