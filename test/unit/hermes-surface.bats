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

@test "the menu links to Hermes's dashboard instead of reimplementing it" {
  # The deep tree that used to be here -- board, task, action, confirm -- was six levels of a picker
  # that needs two clicks a level. Hermes has a dashboard built for driving boards; the OS's job is
  # to put it one click away.
  grep -q 'oal-hermes-dashboard' "$SRC/bin/oal-menu"
  [ ! -e "$SRC/bin/oal-hermes-do" ]
}

@test "the dashboard url is asked for, not assumed" {
  # 0.0.0.0 is where it listens, not somewhere a browser can go, and the port is whatever the running
  # process was started with.
  grep -q "oal-hermes dashboard --status" "$SRC/bin/oal-hermes-dashboard"
  grep -q 'ssh -G' "$SRC/bin/oal-hermes-dashboard"
  # A loopback-bound dashboard is explained with the tunnel, not opened at an address that cannot work.
  grep -q '127.0.0.1' "$SRC/bin/oal-hermes-dashboard"
}

@test "ssh connections are reused, or every click pays for a handshake" {
  # Measured in the VM before this: 30s for status, 11s for waiting, 7s for the dashboard -- each
  # opening a fresh connection. With multiplexing the second call was 1.5s. That gap is the whole
  # difference between a menu that feels broken and one that feels slow.
  grep -q 'ControlMaster=auto' "$SRC/bin/oal-hermes"
  grep -q 'ControlMaster=auto' "$SRC/default/brain/adapters/hermes"
  # Longer than the agent timer's interval, so the timer keeps the connection warm and a click never
  # pays for the handshake.
  grep -q 'ControlPersist=600' "$SRC/bin/oal-hermes"
}

@test "the menu opens on cached answers and says how old they are" {
  # A picker that hangs for seconds is one people stop opening. Live is still one command away.
  grep -q 'oal-hermes-status --cached' "$SRC/bin/oal-menu"
  grep -q 'oal-hermes-waiting --cached' "$SRC/bin/oal-menu"
  grep -q 'as of %s minute(s) ago' "$SRC/bin/oal-hermes-status"
}

@test "the panel lists real work, from the cache, never over the network" {
  # The applet runs inside plasmashell. Opening a popup must not be able to stall the shell.
  local q="$SRC/default/plasmoids/org.agentarchy.agent/contents/ui/main.qml"
  grep -q 'oal-hermes-waiting --cached --json' "$q"
  ! grep -qE 'oal-hermes-status[^-]|ssh ' "$q"
  # One click to the place the work is actually done.
  grep -q 'oal-hermes-dashboard' "$q"
}
