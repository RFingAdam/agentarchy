#!/usr/bin/env bats
#
# The Hermes surface. The brain contract is four backend-neutral verbs on purpose; boards, gateways
# and workers are things one particular agent has. Putting them behind the neutral verb set would
# either bloat the contract with things only Hermes can do, or waste the machine we actually run.
#
# So this is separate, opinionated, and absent unless Hermes is configured.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$HOME"
}

@test "with no Hermes anywhere it says so instead of failing obscurely" {
  local bare="$BATS_TEST_TMPDIR/bare"
  mkdir -p "$bare"
  for c in bash printf cat; do
    p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$bare/$c"
  done
  run env PATH="$bare" "$SRC/bin/oal-hermes" gateway list
  [ "$status" -ne 0 ]
  [[ $output == *"HERMES_SSH"* ]]
}

@test "it asks the same config the adapter reads, so the two cannot disagree" {
  # One answer to "where is Hermes". Two would drift, and the symptom would be a panel disagreeing
  # with the terminal about a machine neither of them can reach.
  grep -q 'oal/brain/hermes.env' "$SRC/bin/oal-hermes"
  grep -q 'HERMES_SSH' "$SRC/bin/oal-hermes"
}

@test "remote arguments are quoted for the shell that will re-parse them" {
  # ssh hands the command to a shell on the far side. An unquoted board name with a space, or any
  # metacharacter in a task title, would be re-split there.
  grep -q "printf '%q'" "$SRC/bin/oal-hermes"
}

@test "the status command counts only states that still owe something" {
  # done and archived are not attention. A count that included them would read as hundreds of open
  # items on a board that is finished.
  grep -q 'ATTENTION_STATES=' "$SRC/bin/oal-hermes-status"
  ! grep -E '^ATTENTION_STATES=' "$SRC/bin/oal-hermes-status" | grep -qE 'done|archived'
}

@test "the panel reads Hermes from the cache, never over ssh on repaint" {
  # The applet runs inside plasmashell. An ssh round trip on the paint path would stall the shell.
  grep -q 'oal-hermes-status --brief' "$SRC/bin/oal-agent-hud"
  ! grep -qE 'oal-hermes|ssh' "$SRC/default/plasmoids/org.agentarchy.agent/contents/ui/main.qml"
  grep -q 'j.attention' "$SRC/default/plasmoids/org.agentarchy.agent/contents/ui/main.qml"
}

@test "the menu offers Hermes and every command it names exists" {
  grep -q 'Hermes) menu_hermes' "$SRC/bin/oal-menu"
  local c
  for c in oal-hermes oal-hermes-status; do
    [ -x "$SRC/bin/$c" ] || { echo "menu names $c and it is not here"; return 1; }
  done
}

@test "brief mode is three numbers, so the prompt path has nothing to parse" {
  # It is read on a timer by oal-agent-hud. A table would mean a parser on the hot path.
  grep -q "printf 'up=%s down=%s attention=%s" "$SRC/bin/oal-hermes-status"
}

@test "ssh queries close stdin, or they hang wherever the OS actually runs them" {
  # ssh forwards stdin and waits for an EOF that never arrives when the caller's stdin is an open
  # pipe -- inside a command substitution, a systemd unit, or another ssh session. It worked by
  # accident on a developer's terminal and hung in the VM, which is every place that matters.
  grep -q 'ssh -n -T' "$SRC/bin/oal-hermes"
  # The adapter closes it at the probe and describe call sites rather than in remote(), because the
  # ask path genuinely wants stdin.
  grep -q "remote 'command -v hermes >/dev/null' </dev/null" "$SRC/default/brain/adapters/hermes"
}

@test "no action happens without a confirmation" {
  # These land on real infrastructure and a panel click is a cheap gesture. --yes exists for scripts;
  # a person gets asked, by name.
  local d="$SRC/bin/oal-hermes-do"
  grep -q 'confirm()' "$d"
  # Every mutating branch asks first.
  local verb
  for verb in claim complete promote changes; do
    grep -A4 "^      $verb)" "$d" | grep -q 'confirm ' || { echo "$verb does not confirm"; return 1; }
  done
  # A wider window than the task verbs: this branch carries the explanation of why Hermes only
  # starts the profile it is on.
  grep -A9 'gateway-start|gateway-stop|gateway-restart' "$d" | grep -q 'confirm '
}

@test "the confirmation names the task rather than its id" {
  # "t_f15b66ee" is not something anyone recognises, and approving the wrong one is not recoverable
  # by reading the id afterwards.
  grep -q 'task_title()' "$SRC/bin/oal-hermes-do"
  grep -q 'title="$(task_title' "$SRC/bin/oal-hermes-do"
  grep -qE 'confirm "(Claim|Complete|Approve and promote|Request changes on): \$title"' "$SRC/bin/oal-hermes-do"
}

@test "a task id that does not exist is refused before anything is attempted" {
  grep -q 'no task .\$task. on this Hermes' "$SRC/bin/oal-hermes-do"
}

@test "an agent cannot reach these actions" {
  # default/brain/VERBS is the whole surface a backend can drive. Completing somebody's tasks and
  # restarting their gateway are not on it, and that is the point: a person does this.
  local v
  for v in claim complete promote changes gateway; do
    ! grep -qE "^$v[[:space:]]*\|" "$SRC/default/brain/VERBS" || { echo "$v is a brain verb"; return 1; }
  done
}

@test "with no way to ask, it says nothing was done" {
  # A picker only counts if it has a backend. Checking oal-menu-select alone sent this down the
  # graphical path on a machine with neither kdialog nor fuzzel, where the failure read as a crash.
  grep -q 'command -v kdialog >/dev/null || command -v fuzzel >/dev/null' "$SRC/bin/oal-hermes-do"
  grep -q 'nothing done: no way to ask you here' "$SRC/bin/oal-hermes-do"
}
