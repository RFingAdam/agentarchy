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

@test "the health route offers real findings and dispatches the one chosen" {
  # kdialog is shimmed, not oal-menu-select. tasks/lessons.md records why: shimming the picker made
  # the menu's own test return the value oal-menu expected, and it stayed green for the entire time
  # the menu was completely dead.
  local shim="$BATS_TEST_TMPDIR/shim"
  mkdir -p "$shim"

  # kdialog answers with the index tag, so 0 is "pick the first row offered".
  cat >"$shim/kdialog" <<'SH'
#!/bin/bash
printf '%s\n' 0
SH
  # Record what the menu decided to diagnose, rather than actually launching an agent.
  cat >"$shim/oal-agent-diagnose" <<SH
#!/bin/bash
printf '%s' "\$1" >"$BATS_TEST_TMPDIR/diagnosed"
SH
  chmod +x "$shim/kdialog" "$shim/oal-agent-diagnose"

  PATH="$shim:$SRC/bin:$PATH" OAL_PATH="$SRC" run "$SRC/bin/oal-menu" health
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/diagnosed" ]

  # It has to be an id oal-doctor actually reports, not the summary the picker displayed.
  local chose
  chose="$(cat "$BATS_TEST_TMPDIR/diagnosed")"
  [ -n "$chose" ]
  "$SRC/bin/oal-doctor" --json | jq -e --arg id "$chose" 'any(.checks[]; .id == $id)' >/dev/null
}

@test "the health route puts problems above passing checks" {
  # The finding worth acting on should be the row under the cursor, not the eleventh entry.
  local shim="$BATS_TEST_TMPDIR/shim2"
  mkdir -p "$shim"
  cat >"$shim/kdialog" <<SH
#!/bin/bash
# Record the order the menu offered, then cancel.
printf '%s\n' "\$@" >"$BATS_TEST_TMPDIR/offered"
exit 1
SH
  chmod +x "$shim/kdialog"
  PATH="$shim:$SRC/bin:$PATH" OAL_PATH="$SRC" run "$SRC/bin/oal-menu" health
  [ -f "$BATS_TEST_TMPDIR/offered" ]

  # Whatever the worst severity present is, its first row must come before any 'ok' row.
  local worst_line ok_line
  worst_line="$(grep -nE 'problem|warn' "$BATS_TEST_TMPDIR/offered" | head -1 | cut -d: -f1)"
  ok_line="$(grep -n 'ok$' "$BATS_TEST_TMPDIR/offered" | head -1 | cut -d: -f1)"
  if [ -n "$worst_line" ] && [ -n "$ok_line" ]; then
    [ "$worst_line" -lt "$ok_line" ]
  fi
}

# --- #49: the five menu commands that called the compositor shell ----------------------------------
# Each is driven with kdialog (and, where needed, qdbus6 or timedatectl) shimmed, never with
# oal-menu-select shimmed, so the real picker runs between the command and the answer.

shim_dir() {
  local d="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$d"
  printf '%s' "$d"
}

@test "the five ported menu commands no longer call the shell that was never vendored" {
  for f in oal-menu-emoji oal-menu-clipboard oal-menu-images oal-menu-timezone oal-menu-input; do
    run bash -c "grep -v '^[[:space:]]*#' '$SRC/bin/$f' | grep -c 'oal-shell'"
    [ "$output" = "0" ] || { echo "$f still calls oal-shell"; return 1; }
  done
}

@test "the tools route reaches emoji, clipboard and timezone" {
  local shim
  shim="$(shim_dir tools)"
  for c in oal-menu-emoji oal-menu-clipboard oal-menu-timezone; do
    printf '#!/bin/bash\nprintf %%s %s >"%s/ran"\n' "$c" "$BATS_TEST_TMPDIR" >"$shim/$c"
    chmod +x "$shim/$c"
  done
  local i=0
  for c in oal-menu-emoji oal-menu-clipboard oal-menu-timezone; do
    printf '#!/bin/bash\necho %s\n' "$i" >"$shim/kdialog"
    chmod +x "$shim/kdialog"
    rm -f "$BATS_TEST_TMPDIR/ran"
    PATH="$shim:$SRC/bin:$PATH" run "$SRC/bin/oal-menu" tools
    [ "$status" -eq 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/ran")" = "$c" ] || { echo "row $i did not run $c"; return 1; }
    i=$((i + 1))
  done
  # And Tools is on the root menu, so it is reachable from the dock and Meta+Space.
  grep -q $'Tools) menu_tools' "$SRC/bin/oal-menu"
}

@test "clipboard offers Klipper's history and puts the chosen entry back whole" {
  local shim
  shim="$(shim_dir clip)"
  # Three entries, the middle one on two lines: it must still be one row and come back whole.
  cat >"$shim/qdbus6" <<SH
#!/bin/bash
case "\$3" in
  *getClipboardHistoryItem)
    case "\$4" in
      0) echo first ;;
      1) printf 'second line one\nsecond line two\n' ;;
      2) echo third ;;
      *) echo ;;
    esac ;;
  *setClipboardContents) printf '%s' "\$4" >"$BATS_TEST_TMPDIR/clipboard" ;;
esac
SH
  # Record the rows offered, then pick the second.
  cat >"$shim/kdialog" <<SH
#!/bin/bash
printf '%s\n' "\$@" >"$BATS_TEST_TMPDIR/offered"
echo 1
SH
  chmod +x "$shim/qdbus6" "$shim/kdialog"
  PATH="$shim:$SRC/bin:$PATH" run "$SRC/bin/oal-menu-clipboard"
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/clipboard")" = $'second line one\nsecond line two' ]
  # Three rows (tags 0, 1, 2), not four: the two-line entry did not split.
  run grep -cxE '[0-9]+' "$BATS_TEST_TMPDIR/offered"
  [ "$output" = "3" ]
}

@test "images go through the picker and return the path, or the name with --print-name" {
  local shim dir
  shim="$(shim_dir img)"
  dir="$BATS_TEST_TMPDIR/pics"
  mkdir -p "$dir"
  : >"$dir/aurora.png"; : >"$dir/beach.jpg"
  printf '#!/bin/bash\necho 1\n' >"$shim/kdialog"
  chmod +x "$shim/kdialog"
  # --lazy-thumbnails, so rows exist without vipsthumbnail; the picker shows names, not thumbnails.
  XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache" PATH="$shim:$SRC/bin:$PATH" \
    run "$SRC/bin/oal-menu-images" --lazy-thumbnails "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$dir/beach.jpg" ]
  XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache" PATH="$shim:$SRC/bin:$PATH" \
    run "$SRC/bin/oal-menu-images" --print-name --lazy-thumbnails "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "beach" ]
}

@test "input returns what was typed and fails when cancelled" {
  local shim
  shim="$(shim_dir input)"
  printf '#!/bin/bash\n[[ " $* " == *" --inputbox "* ]] || exit 9\necho "in ten minutes"\n' >"$shim/kdialog"
  chmod +x "$shim/kdialog"
  PATH="$shim:$PATH" run "$SRC/bin/oal-menu-input" "Reminder" --width 400
  [ "$status" -eq 0 ]
  [ "$output" = "in ten minutes" ]

  printf '#!/bin/bash\nexit 1\n' >"$shim/kdialog"
  PATH="$shim:$PATH" run "$SRC/bin/oal-menu-input" "Reminder"
  [ "$status" -ne 0 ]
}

@test "timezone sets the zone through timedated, with no sudo and no terminal" {
  local shim
  shim="$(shim_dir tz)"
  cat >"$shim/timedatectl" <<SH
#!/bin/bash
case "\$1" in
  list-timezones) printf '%s\n' America/Chicago Europe/Berlin ;;
  set-timezone) printf '%s' "\$2" >"$BATS_TEST_TMPDIR/tz.set" ;;
esac
SH
  printf '#!/bin/bash\necho 0\n' >"$shim/kdialog"
  printf '#!/bin/bash\nexit 0\n' >"$shim/oal-notification-send"
  printf '#!/bin/bash\necho sudo was called >&2; exit 1\n' >"$shim/sudo"
  chmod +x "$shim"/*
  PATH="$shim:$SRC/bin:$PATH" run "$SRC/bin/oal-menu-timezone"
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/tz.set")" = America/Chicago ]
}

@test "emoji opens Plasma's own selector and says so when it is missing" {
  local shim bare
  shim="$(shim_dir emoji)"
  printf '#!/bin/bash\ntouch "%s/emojier"\n' "$BATS_TEST_TMPDIR" >"$shim/plasma-emojier"
  chmod +x "$shim/plasma-emojier"
  PATH="$shim:$PATH" run "$SRC/bin/oal-menu-emoji"
  [ "$status" -eq 0 ]
  [ -e "$BATS_TEST_TMPDIR/emojier" ]

  bare="$(shim_dir emoji-bare)"
  ln -sf "$(command -v bash)" "$bare/bash"
  PATH="$bare" run "$SRC/bin/oal-menu-emoji"
  [ "$status" -ne 0 ]
  [[ $output == *"plasma-emojier is not installed"* ]]
}
