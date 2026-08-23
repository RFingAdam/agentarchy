#!/usr/bin/env bats
#
# oal-theme-set-kde turns a theme's colors.toml into the two files KDE reads: a Plasma colour
# scheme and a Konsole scheme. Applying them needs a running Plasma session, so everything that
# can be tested offline is tested through --dry-run --out: the generation is pure, the apply is
# not. A malformed .colors file does not fail loudly in Plasma, it just renders wrong, which is
# why the structural assertions here are picky about sections and about R,G,B triples.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  OUT="$BATS_TEST_TMPDIR"
  run env OAL_PATH="$SRC" "$SRC/bin/oal-theme-set-kde" tokyo-night --dry-run --out "$OUT"
  [ "$status" -eq 0 ] || { echo "generation failed: $output"; return 1; }
  COLORS="$OUT/color-schemes/OAL Tokyo Night.colors"
  KONSOLE="$OUT/konsole/OAL Tokyo Night.colorscheme"
}

# Every section Breeze ships. A scheme missing one of these leaves that widget class on the
# previous theme's colours instead of falling back to something sane.
SECTIONS=(
  "Colors:Button" "Colors:Complementary" "Colors:Header" "Colors:Selection"
  "Colors:Tooltip" "Colors:View" "Colors:Window" "General" "KDE" "WM"
)

@test "generates both files" {
  [ -s "$COLORS" ]
  [ -s "$KONSOLE" ]
}

@test "the colour scheme has every section Breeze ships" {
  for s in "${SECTIONS[@]}"; do
    grep -qxF "[$s]" "$COLORS" || { echo "missing section [$s]"; return 1; }
  done
}

@test "the scheme names itself after the theme" {
  grep -qxF "Name=OAL Tokyo Night" "$COLORS"
  grep -qxF "ColorScheme=OAL Tokyo Night" "$COLORS"
}

@test "every colour value is an R,G,B triple in range" {
  while IFS= read -r line; do
    value="${line#*=}"
    [[ $value =~ ^([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3})$ ]] || { echo "not a triple: $line"; return 1; }
    for c in "${BASH_REMATCH[@]:1:3}"; do
      (( c >= 0 && c <= 255 )) || { echo "out of range: $line"; return 1; }
    done
  done < <(grep -E '^(Background|Foreground|Decoration|active|inactive)[A-Za-z]*=' "$COLORS")
}

@test "the palette lands where the spec says it lands" {
  # background #1a1b26, accent #7aa2f7, muted #414868 for tokyo-night.
  grep -A9 -xF '[Colors:Window]' "$COLORS" | grep -qxF 'BackgroundNormal=26,27,38'
  grep -A9 -xF '[Colors:Window]' "$COLORS" | grep -qxF 'DecorationFocus=122,162,247'
  grep -A9 -xF '[Colors:Window]' "$COLORS" | grep -qxF 'ForegroundInactive=65,72,104'
  grep -A6 -xF '[WM]' "$COLORS" | grep -qxF 'activeBackground=122,162,247'
}

@test "the konsole scheme carries all sixteen ANSI colours" {
  for i in 0 1 2 3 4 5 6 7; do
    grep -qxF "[Color$i]" "$KONSOLE" || { echo "missing [Color$i]"; return 1; }
    grep -qxF "[Color${i}Intense]" "$KONSOLE" || { echo "missing [Color${i}Intense]"; return 1; }
  done
  grep -qxF "[Background]" "$KONSOLE"
  grep -qxF "[Foreground]" "$KONSOLE"
}

@test "konsole colours are R,G,B triples and match the palette" {
  while IFS= read -r line; do
    [[ ${line#Color=} =~ ^[0-9]{1,3},[0-9]{1,3},[0-9]{1,3}$ ]] || { echo "not a triple: $line"; return 1; }
  done < <(grep -E '^Color=' "$KONSOLE")
  grep -A2 -xF '[Background]' "$KONSOLE" | grep -qxF 'Color=26,27,38'
  grep -A2 -xF '[Color1]' "$KONSOLE" | grep -qxF 'Color=247,118,142'      # red  #f7768e
  grep -A2 -xF '[Color1Intense]' "$KONSOLE" | grep -qxF 'Color=255,122,147' # bright_red #ff7a93
}

@test "a display name with spaces and capitals resolves to the same theme" {
  run env OAL_PATH="$SRC" "$SRC/bin/oal-theme-set-kde" "Tokyo Night" --dry-run --out "$BATS_TEST_TMPDIR/alt"
  [ "$status" -eq 0 ]
  [ -s "$BATS_TEST_TMPDIR/alt/color-schemes/OAL Tokyo Night.colors" ]
}

@test "an unknown theme fails loudly" {
  run env OAL_PATH="$SRC" "$SRC/bin/oal-theme-set-kde" no-such-theme --dry-run --out "$BATS_TEST_TMPDIR/nope"
  [ "$status" -ne 0 ]
  [[ $output == *"no-such-theme"* ]]
}

@test "every shipped theme generates a well-formed scheme" {
  for dir in "$SRC"/themes/*/; do
    name="$(basename "$dir")"
    [ -f "$dir/colors.toml" ] || continue
    run env OAL_PATH="$SRC" "$SRC/bin/oal-theme-set-kde" "$name" --dry-run --out "$BATS_TEST_TMPDIR/all/$name"
    [ "$status" -eq 0 ] || { echo "$name failed: $output"; return 1; }
    file="$(find "$BATS_TEST_TMPDIR/all/$name/color-schemes" -name '*.colors' | head -1)"
    [ -s "$file" ] || { echo "$name produced no scheme"; return 1; }
    while IFS= read -r line; do
      [[ ${line#*=} =~ ^[0-9]{1,3},[0-9]{1,3},[0-9]{1,3}$ ]] || { echo "$name: bad value $line"; return 1; }
    done < <(grep -E '^(Background|Foreground|Decoration|active|inactive)[A-Za-z]*=' "$file")
  done
}

# The install path, with a stub kwriteconfig6 standing in for a Plasma that is not installed here.
# This is the case the first golden-path run got wrong: a session that names a colour scheme whose
# colours were never written renders stock Breeze while every check says it is themed.
@test "with no Plasma session the whole scheme is seeded into kdeglobals" {
  stub="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub"
  cat >"$stub/kwriteconfig6" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$KWRITE_LOG"
STUB
  chmod +x "$stub/kwriteconfig6"

  KWRITE_LOG="$BATS_TEST_TMPDIR/kwrite.log"
  export KWRITE_LOG
  run env PATH="$stub:/usr/bin:/bin" HOME="$BATS_TEST_TMPDIR/home" KWRITE_LOG="$KWRITE_LOG" \
    OAL_PATH="$SRC" "$SRC/bin/oal-theme-set-kde" tokyo-night
  [ "$status" -eq 0 ]
  [[ $output == *"seeded kdeglobals"* ]]

  # Every colour section reaches kdeglobals, not just the name.
  grep -q -- '--file kdeglobals --group Colors:Window --key BackgroundNormal 26,27,38' "$KWRITE_LOG"
  grep -q -- '--file kdeglobals --group WM --key activeBackground 122,162,247' "$KWRITE_LOG"
  grep -q -- '--file kdeglobals --group General --key ColorScheme OAL Tokyo Night' "$KWRITE_LOG"
  [ "$(grep -c -- '--file kdeglobals' "$KWRITE_LOG")" -gt 80 ]
}
