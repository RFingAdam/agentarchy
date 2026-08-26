#!/usr/bin/env bats
#
# oal-watch: noticing that something broke.
#
# Upstream watches for exactly one event, a core dump, and hands the facts to an agent with a skill
# describing the method. The mechanism is right; the scope was one row long. This generalises it
# without inventing a second table, because oal-doctor already enumerates what can be wrong with this
# machine and a parallel list is two things to keep in step with one destined to go stale.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$XDG_STATE_HOME/oal"
  SEEN="$XDG_STATE_HOME/oal/watch-seen"
  # Belt and braces with --no-notify below. Each test gets a fresh state directory, so every run
  # sees every finding as new -- which on a developer's own desktop meant a burst of real popups
  # every time the suite ran.
  export OAL_WATCH_NO_NOTIFY=1
}

code() { grep -v '^[[:space:]]*#' "$1"; }

@test "the first pass records what is wrong and reports it" {
  run oal-watch --once --no-notify
  [ "$status" -eq 0 ]
  [ -f "$SEEN" ]
}

@test "a second pass says nothing, because nothing became news" {
  # A disk that was 96% full an hour ago and still is has not changed. A watcher that says so every
  # ten minutes is one people turn off, after which nothing is watched at all.
  oal-watch --once --no-notify >/dev/null
  run oal-watch --once --no-notify
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--reset makes everything news again" {
  oal-watch --once --no-notify >/dev/null
  local first_run_found
  first_run_found="$(wc -l <"$SEEN")"
  run oal-watch --reset
  [ "$status" -eq 0 ]
  [ ! -f "$SEEN" ]
  run oal-watch --once --no-notify
  [ "$(wc -l <"$SEEN")" -eq "$first_run_found" ]
}

@test "only problems and warnings are announced, never unknown" {
  # A check that could not run is a gap in the report, not an event. Waking somebody for it teaches
  # them the notification means nothing.
  code "$SRC/bin/oal-watch" | grep -q 'severity == "problem" or .severity == "warn"'
  ! code "$SRC/bin/oal-watch" | grep -q 'severity == "unknown"'

  # And behaviourally, not just in the source. This suite runs in CI on Ubuntu, where pacman does
  # not exist, so the three package checks genuinely report unknown and must never be recorded.
  if ! command -v pacman >/dev/null; then
    oal-watch --once --no-notify >/dev/null
    local id
    for id in updates orphans pacnew; do
      ! grep -qx "$id" "$SEEN" || { echo "announced an unknown check: $id"; false; }
    done
  fi
}

@test "it invents no second event table" {
  # The whole design decision. oal-doctor's checks are the events.
  code "$SRC/bin/oal-watch" | grep -q 'oal-doctor --json'
  [ ! -e "$SRC/default/oal/watch-table" ]
}

@test "the click target is quoted, so a summary full of punctuation survives it" {
  code "$SRC/bin/oal-watch" | grep -q "printf 'oal-agent-diagnose %q'"
}

@test "the unit and its timer both ship, and the package installs both" {
  # The glob in PKGBUILD was *.service only, so this timer would have shipped to
  # /usr/share/agentarchy and been impossible to enable -- the same failure that block exists to fix,
  # one file extension later.
  [ -f "$SRC/default/systemd/user/oal-watch.service" ]
  [ -f "$SRC/default/systemd/user/oal-watch.timer" ]
  grep -q 'default/systemd/user/\*\.timer' "$SRC/PKGBUILD"
  grep -q 'usr/lib/systemd/user' "$SRC/PKGBUILD"
}

@test "the install enables it, on the path the install actually takes" {
  # install/user/first-run/ is the ISO's path and nothing in oal-bootstrap.sh runs that directory at
  # all, which is why the crash watcher had never once started on a bootstrap install.
  grep -q 'oal-watch.timer' "$SRC/install/agent/runtime.sh"
  grep -q 'oal-crash-watch.service' "$SRC/install/agent/runtime.sh"
  grep -q 'install/agent/runtime.sh' "$SRC/oal-bootstrap.sh"
}

@test "turning it off survives a reinstall that re-enables shipped units" {
  # A state file the unit's own condition reads, mirroring oal-toggle-crash-capture, rather than
  # disabling the unit -- which the next install would undo without telling anyone.
  grep -q 'ConditionPathExists=!%h/.local/state/oal/toggles/health-watch-off' \
    "$SRC/default/systemd/user/oal-watch.service"
  run oal-toggle-health-watch off
  [ "$status" -eq 0 ]
  [ -e "$XDG_STATE_HOME/oal/toggles/health-watch-off" ]
  run oal-toggle-health-watch
  [ "$output" = off ]
  run oal-toggle-health-watch on
  run oal-toggle-health-watch
  [ "$output" = on ]
}

@test "it needs a session to notify, and says so in the unit" {
  # Without one it would run, find things, and tell nobody.
  grep -q 'ConditionEnvironment=WAYLAND_DISPLAY' "$SRC/default/systemd/user/oal-watch.service"
}

@test "the skill it points at exists and describes every check oal-doctor can report" {
  local skill="$SRC/default/agents/skills/diagnose-system/SKILL.md"
  [ -f "$skill" ]
  # Not a list somebody has to remember to update: pulled from the report itself.
  local id
  for id in $(oal-doctor --json | jq -r '.checks[].id'); do
    grep -q -- "$id" "$skill" || { echo "the skill never mentions the '$id' check"; false; }
  done
}

@test "it puts nothing on screen when no agent has been chosen" {
  # The toast's only offer is a diagnosis, so it has nothing to offer until a backend exists. Same
  # rule oal-crash-watch follows. A machine that never opted into an agent gets no popups from it.
  local shim="$BATS_TEST_TMPDIR/shim"
  mkdir -p "$shim"
  cat >"$shim/oal-notification-send" <<SH
#!/bin/bash
printf 'NOTIFIED %s\n' "\$*" >>"$BATS_TEST_TMPDIR/notified"
SH
  chmod +x "$shim/oal-notification-send"
  rm -f "$XDG_STATE_HOME/oal/brain/backend"

  PATH="$shim:$SRC/bin:$PATH" OAL_WATCH_NO_NOTIFY= run "$SRC/bin/oal-watch" --once
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TEST_TMPDIR/notified" ] || { echo "$(cat "$BATS_TEST_TMPDIR/notified")"; false; }
}

@test "--no-notify reports findings without raising one" {
  # This is what the suite itself uses. Running the real command was firing real desktop
  # notifications on the developer's machine, several per suite run, because every test gets a fresh
  # state directory and so sees every finding as new.
  local shim="$BATS_TEST_TMPDIR/shim2"
  mkdir -p "$shim" "$XDG_STATE_HOME/oal/brain"
  cat >"$shim/oal-notification-send" <<SH
#!/bin/bash
printf 'NOTIFIED\n' >>"$BATS_TEST_TMPDIR/notified2"
SH
  chmod +x "$shim/oal-notification-send"
  echo stub >"$XDG_STATE_HOME/oal/brain/backend"

  PATH="$shim:$SRC/bin:$PATH" OAL_WATCH_NO_NOTIFY= run "$SRC/bin/oal-watch" --once --no-notify
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TEST_TMPDIR/notified2" ]
  # It still says what it found, on stdout, which is the whole point of the flag.
  [ -n "$output" ]
}
