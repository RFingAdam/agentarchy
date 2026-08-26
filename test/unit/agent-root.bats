#!/usr/bin/env bats
#
# bin/oal-agent, and the family that could not run without it.
#
# Upstream's launcher was excluded from vendoring as terminal-bound. The commands that call it were
# not, so oal-agent-crash, oal-agent-prompt and the `a` alias in every shell on the machine all ended
# at exit 127. upstream/DANGLING.txt recorded every one of those broken references and nothing ever
# read the file.
#
# So these assert that the references RESOLVE, not that files exist. tasks/lessons.md already records
# why: the menu's test stayed green for the whole time the menu was dead, because it checked that a
# thing was present rather than that the thing consuming it could find it.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$XDG_STATE_HOME/oal/brain"
}

# Every oal-* command a file actually calls, minus its own comments.
#
# The trailing \*? and the filter matter: oal-crash-watch contains `[[ $name == oal-crash-* ]]`, and
# without it that glob reads as a call to a command named oal-crash, which does not exist and never
# did. A test that reports a pattern as a broken reference is a test people learn to ignore.
referenced_commands() {
  grep -v '^[[:space:]]*#' "$1" |
    grep -oE '\boal-[a-z0-9-]+\*?' |
    grep -v '\*$' |
    sort -u
}

@test "oal-agent resolves on PATH" {
  run command -v oal-agent
  [ "$status" -eq 0 ]
  [ -x "$SRC/bin/oal-agent" ]
}

@test "every oal-* command the agent family execs resolves" {
  # The generalisation of the bug. One missing root took out five commands, and the only reason
  # nobody noticed is that nothing asserted the edges.
  local f cmd missing=""
  for f in "$SRC/bin/oal-agent" "$SRC/bin/oal-agent-crash" "$SRC/bin/oal-agent-prompt" \
           "$SRC/bin/oal-agent-diagnose" "$SRC/bin/oal-crash-watch" "$SRC/bin/oal-watch" \
           "$SRC/bin/oal-ask" "$SRC/bin/oal-mcp-serve"; do
    [ -f "$f" ] || continue
    while read -r cmd; do
      [ -n "$cmd" ] || continue
      [ -x "$SRC/bin/$cmd" ] || missing+="$(basename "$f") -> $cmd"$'\n'
    done < <(referenced_commands "$f")
  done
  [ -z "$missing" ] || { echo "unresolvable references:"; echo "$missing"; false; }
}

@test "every oal-* command the shell aliases point at resolves" {
  # These are live in every shell on the machine. `a` was bound to a command that did not exist.
  local cmd missing=""
  while read -r cmd; do
    [ -n "$cmd" ] || continue
    [ -x "$SRC/bin/$cmd" ] || missing+="alias -> $cmd"$'\n'
  done < <(referenced_commands "$SRC/default/bash/aliases")
  [ -z "$missing" ] || { echo "$missing"; false; }
}

@test "the crash notification's exec target resolves and takes the arguments given" {
  # oal-crash-watch builds this string and hands it to the notification daemon. Clicking it was the
  # whole feature, and it landed on exit 127.
  grep -q "printf 'oal-agent-crash %q %q %q %q'" "$SRC/bin/oal-crash-watch"
  [ -x "$SRC/bin/oal-agent-crash" ]
  run oal-agent-crash
  # Refuses with usage rather than "command not found".
  [ "$status" -ne 127 ]
  [[ $output == *usage* ]]
}

@test "the health notification's exec target resolves" {
  grep -q "printf 'oal-agent-diagnose %q'" "$SRC/bin/oal-watch"
  [ -x "$SRC/bin/oal-agent-diagnose" ]
}

@test "oal-agent-diagnose refuses an unknown check and names the real ones" {
  run oal-agent-diagnose not-a-check
  [ "$status" -ne 0 ]
  [[ $output == *"no check called"* ]]
  [[ $output == *"Known checks:"* ]]
  [[ $output == *"failed-units"* ]]
}

@test "which agent runs comes from oal-brain-backend, not a second setting" {
  # Upstream had a separate default-agent command. A second source of truth for one question is how
  # the first one goes stale.
  grep -q 'brain_backend' "$SRC/bin/oal-agent"
  [ ! -e "$SRC/bin/oal-default-agent" ]
}

@test "with no backend configured it says how to choose one" {
  run oal-agent --prompt "hello"
  [ "$status" -ne 0 ]
  [[ $output == *"oal-brain-backend"* ]]
}

@test "a prompt is forwarded through oal-brain-ask, not straight to an adapter" {
  # So grounding, the posture and the guard are the same ones every other path answers to.
  grep -q 'oal-brain-ask -- "$prompt"' "$SRC/bin/oal-agent"
}

@test "every adapter answers the interactive subcommand without a usage error" {
  local a
  for a in "$SRC"/default/brain/adapters/*; do
    run "$a" interactive --check
    # 0 supported, 1 honestly unsupported. Anything else is the adapter not knowing the word.
    [ "$status" -le 1 ] || { echo "$(basename "$a") returned $status"; false; }
  done
}

@test "an adapter that cannot be interactive says so rather than guessing at an invocation" {
  # The hermes adapter was once written against an invented HTTP API and none of it was right.
  run "$SRC/default/brain/adapters/hermes" interactive --check
  [ "$status" -eq 1 ]
  run "$SRC/default/brain/adapters/stub" interactive --check
  [ "$status" -eq 1 ]
}

@test "it opens a terminal only when there is not one, and holds it open afterwards" {
  # Clicking a crash notification happens on the desktop, where there is no terminal at all. A
  # window that closes on the last line of the answer is the same as no window.
  grep -q 'relaunch_in_terminal' "$SRC/bin/oal-agent"
  grep -q -- '-t 1' "$SRC/bin/oal-agent"
  grep -q 'Press enter to close' "$SRC/bin/oal-agent"
}

@test "the references upstream records as dangling now resolve here" {
  # upstream/DANGLING.txt describes UPSTREAM's tree: which vendored files call a script that was
  # excluded from vendoring. It is computed from the pristine stage, before our patches, so entries
  # do not disappear when we answer them -- and that is right, because the record is about what we
  # inherited rather than what we ship.
  #
  # What has to be true is that every file we actually run can resolve its target. Six entries point
  # at oal-agent, which is why writing it fixed five commands at once.
  grep -q -- '-> oal-agent$' "$SRC/upstream/DANGLING.txt"
  local target
  while read -r target; do
    [ -n "$target" ] || continue
    [ -x "$SRC/bin/$target" ] || { echo "still unresolvable: $target"; false; }
  done < <(grep -E '^(bin/oal-agent-crash|bin/oal-agent-prompt|bin/oal-crash-watch|default/bash/aliases) -> ' \
             "$SRC/upstream/DANGLING.txt" | sed 's/.*-> //' | sort -u |
           grep -v '^oal-default-agent$')
}

@test "oal-crash-watch no longer gates every crash on a command that does not exist" {
  # It ran `[[ -n $(oal-default-agent) ]] || continue`. With that command missing the substitution
  # was empty, so the guard fired on every crash and the watcher announced nothing, ever.
  ! grep -v '^[[:space:]]*#' "$SRC/bin/oal-crash-watch" | grep -q 'oal-default-agent'
  grep -v '^[[:space:]]*#' "$SRC/bin/oal-crash-watch" | grep -q 'oal-brain-backend'
  # And the change is captured as a patch, or the next vendor sync silently reverts it.
  ls "$SRC"/upstream/patches/*crash-watch*.patch >/dev/null
}
