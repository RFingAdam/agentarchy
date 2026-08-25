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
  [[ $output == *"fuzzel is not installed"* ]]
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
