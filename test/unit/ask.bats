#!/usr/bin/env bats
#
# oal-ask is the desktop end of the brain contract, and the only part of the agent layer that is
# visible without a terminal open. What matters here is that it stays a thin front on
# oal-brain-ask -- a second path to a model would be a second path around the guard.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$XDG_STATE_HOME" "$HOME"
}

@test "with no backend it says how to get one rather than failing mutely" {
  run oal-ask "anything"
  [ "$status" -ne 0 ]
  [[ $output == *"oal-brain-backend"* ]]
}

@test "a question round-trips and the answer lands on stdout" {
  oal-brain-backend stub >/dev/null
  run oal-ask "what theme am I using"
  [ "$status" -eq 0 ]
  [ "$output" = "stub: what theme am I using" ]
}

@test "the full answer is kept on disk, because a notification truncates" {
  oal-brain-backend stub >/dev/null
  oal-ask "a question" >/dev/null
  [ -s "$XDG_STATE_HOME/oal/last-answer.txt" ]
  grep -q "stub: a question" "$XDG_STATE_HOME/oal/last-answer.txt"
}

@test "it goes through oal-brain-ask rather than reaching for an adapter itself" {
  # The whole point of the contract is one enforcement path. A shortcut here would be a way round
  # the verb set and the guard that happens to have a friendly keyboard binding.
  grep -q 'oal-brain-ask' "$SRC/bin/oal-ask"
  ! grep -qE 'brain/adapters|brain_adapter' "$SRC/bin/oal-ask"
}

@test "an empty question is a cancelled one, not an empty prompt sent to a model" {
  oal-brain-backend stub >/dev/null
  run oal-ask "   "
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the menu offers it, and the desktop entry the shortcut names exists" {
  grep -q 'ask) oal-ask' "$SRC/bin/oal-menu"
  [ -f "$SRC/applications/oal-ask.desktop" ]
  grep -q '^Exec=oal-ask$' "$SRC/applications/oal-ask.desktop"
  # The shortcut binds by desktop entry id, so the package has to install that id.
  grep -q "usr/share/applications/oal-ask.desktop" "$SRC/PKGBUILD"
  grep -q 'oal-ask.desktop' "$SRC/bin/oal-layout-first-login"
}
