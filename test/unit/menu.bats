#!/usr/bin/env bats
#
# The menu. Its entries cannot be clicked from a test, so what is pinned here is the constraint that
# made it worth rewriting: every command an entry runs has to exist on this tree.
#
# The inherited menu failed exactly that. It was a client for a Quickshell shell this distribution
# does not ship, so all of it exited 127 -- present, listed, and doing nothing.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
}

@test "every command the menu invokes exists" {
  # Pulled out of the source rather than listed here, so an entry added later is covered without
  # anyone remembering to update a test.
  local missing=()
  while read -r cmd; do
    [[ -n $cmd ]] || continue
    [[ -x "$SRC/bin/$cmd" ]] || command -v "$cmd" >/dev/null || missing+=("$cmd")
  done < <(grep -oE '^\s*(oal-[a-z-]+|loginctl|qdbus6)' "$SRC/bin/oal-menu" | tr -d ' ' | sort -u)
  [ ${#missing[@]} -eq 0 ] || { echo "menu calls commands that do not exist: ${missing[*]}"; return 1; }
}

@test "the menu no longer depends on the shell that was never vendored" {
  # Non-comment lines only. Both files explain in a comment what they used to call, and a naive
  # grep matches the explanation and fails on a correct file.
  for f in oal-menu oal-menu-select; do
    run bash -c "grep -v '^[[:space:]]*#' '$SRC/bin/$f' | grep -c 'oal-shell'"
    [ "$output" = "0" ] || { echo "$f still calls oal-shell"; return 1; }
  done
}

@test "an unknown route is refused and names the real ones" {
  run "$SRC/bin/oal-menu" nosuchroute
  [ "$status" -ne 0 ]
  [[ $output == *"theme"* && $output == *"agent"* ]]
}

@test "the picker keeps upstream's contract" {
  # Other commands already call oal-menu-select and expect: label alone for a plain option, and
  # "label<TAB>subtext" when a subtext is present. Changing the backend must not change that.
  grep -q 'oal:args=prompt \[option\.\.\.\]' "$SRC/bin/oal-menu-select"
  grep -q 'mapfile -t options' "$SRC/bin/oal-menu-select"   # options may arrive on stdin
  grep -qE 'value\+=\("\$b"\$.\\t.\"\$c"\)' "$SRC/bin/oal-menu-select"
}

@test "the picker refuses clearly when its backend is absent" {
  local bare="$BATS_TEST_TMPDIR/bare"
  mkdir -p "$bare"
  for c in bash env printf mapfile read; do
    p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$bare/$c"
  done
  run env PATH="$bare" "$SRC/bin/oal-menu-select" Prompt one two
  [ "$status" -ne 0 ]
  [[ $output == *"neither kdialog nor fuzzel is installed"* ]]
}

@test "the picker prefers the backend that works with a mouse" {
  # kdialog first, fuzzel behind it. fuzzel is the better looking picker and it is keyboard-
  # excellent, but clicking an entry does not select it on this desktop -- reported twice from a
  # real mouse. A menu whose entries do nothing when clicked is not a menu.
  local src="$SRC/bin/oal-menu-select"
  grep -q 'command -v kdialog' "$src"
  # The escape hatch stays, so the old picker is one variable away.
  grep -q 'OAL_MENU_BACKEND' "$src"
  # kdialog answers with the tag, so the value is matched back by index with no string round-trip.
  grep -q 'kargs+=("$i" "${display\[$i\]}")' "$src"
}

@test "the picker matches the selection back by index, not by splitting the answer" {
  # A label containing the separator would break a parse of the returned string, and labels are
  # arbitrary text from whatever called it.
  grep -q 'for i in "${!display\[@\]}"' "$SRC/bin/oal-menu-select"
}

@test "fuzzel renders for every theme with nothing left unsubstituted" {
  for dir in "$SRC"/themes/*/; do
    out="$(env OAL_PATH="$SRC" "$SRC/bin/oal-theme-render" fuzzel.ini --file "$dir/colors.toml")" ||
      { echo "$(basename "$dir") failed"; return 1; }
    [[ $out != *"{{"* ]] || { echo "$(basename "$dir") left a placeholder"; return 1; }
    # fuzzel wants RRGGBBAA, and a leading # is silently accepted and then ignored, which shows up
    # as a menu with no colours rather than as an error.
    grep -qE '^background=[0-9a-fA-F]{8}$' <<<"$out" || { echo "$(basename "$dir"): bad colour form"; return 1; }
  done
}

@test "every launcher a layout pins is a desktop entry the package installs" {
  # The dock pins launchers by desktop entry id, and an id nothing installs draws a blank icon that
  # does nothing when clicked. oal-menu.desktop was in applications/ and copied only into
  # /usr/share/agentarchy, which is not a directory any desktop environment reads.
  local SRC id
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  for id in $(grep -ho 'applications:oal-[a-zA-Z0-9._-]*\.desktop' "$SRC"/default/layouts/*.js |
              sed 's/applications://' | sort -u); do
    grep -q "usr/share/applications/$id" "$SRC/PKGBUILD" ||
      { echo "$id is pinned by a layout but PKGBUILD never installs it to /usr/share/applications"; return 1; }
  done
}

@test "a row with an empty glyph returns the label, not the subtext" {
  # The bug that made the menu open and do nothing, through two different pickers. Rows arrive as
  # glyph<TAB>label<TAB>subtext and every menu row has an empty glyph. `IFS=$'\t' read -r a b c`
  # silently drops that leading empty field, so the label landed in the glyph and the subtext in the
  # label -- and the value handed back was the subtext. oal-menu compared it against "Theme",
  # "Layout", "Agent", "System", matched nothing, and exited silently.
  local fake="$BATS_TEST_TMPDIR/fake"
  mkdir -p "$fake"
  # Stand in for the picker so the real value construction runs with no display attached. It answers
  # with a tag, which is what kdialog returns.
  printf '#!/bin/bash\necho 1\n' >"$fake/kdialog"
  chmod +x "$fake/kdialog"

  run env PATH="$fake:$PATH" bash -c "printf '\tAlpha\tfirst\n\tBeta\tsecond\n' | '$SRC/bin/oal-menu-select' Test"
  [ "$status" -eq 0 ]
  # The label must lead, because oal-menu dispatches on everything before the first tab.
  [ "${lines[0]%%$'\t'*}" = Beta ]
}

@test "the dispatch key survives a row that has no subtext" {
  local fake="$BATS_TEST_TMPDIR/fake2"
  mkdir -p "$fake"
  printf '#!/bin/bash\necho 0\n' >"$fake/kdialog"
  chmod +x "$fake/kdialog"
  run env PATH="$fake:$PATH" bash -c "printf '\tgruvbox\n' | '$SRC/bin/oal-menu-select' Theme"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = gruvbox ]
}
