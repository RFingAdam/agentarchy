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

# A fixed report, for the tests about transition logic.
#
# Those tests used to run the real oal-doctor twice and compare the two results, which made them
# depend on this machine holding still between the scans. It does not: a unit fails, the disk crosses
# a threshold, another test writes a journal line, and the counts differ. #399 passed on two full
# runs and failed on a third.
#
# Shimming oal-doctor is not the mistake tasks/lessons.md warns about. That one is shimming the unit
# under test until it returns whatever the test wants, which is how the menu suite stayed green while
# the menu was dead. Here the unit under test is oal-watch's transition logic and oal-doctor is its
# input; fixing an input is what makes the logic observable at all.
#
# It has to go in a fake OAL_PATH rather than on PATH: oal-watch prepends its own bin to PATH on
# line 22, so the real oal-doctor wins over any shim placed merely ahead of it. That took a failing
# test to notice, which is the argument for the shim being a real one rather than a stub of the
# thing being tested.
#
# The first test below deliberately uses the real report, so the two stay known to fit together.
fixed_doctor() { # fixed_doctor <id>...
  local fake="$BATS_TEST_TMPDIR/tree" ids="" id f
  if [[ ! -d $fake/bin ]]; then
    mkdir -p "$fake/bin"
    for f in "$SRC"/bin/*; do ln -sfn "$f" "$fake/bin/${f##*/}"; done
    ln -sfn "$SRC/default" "$fake/default"
    ln -sfn "$SRC/agent" "$fake/agent"
  fi
  for id in "$@"; do ids+="{\"id\":\"$id\",\"severity\":\"problem\",\"summary\":\"$id is unhappy\"},"; done
  rm -f "$fake/bin/oal-doctor"
  cat >"$fake/bin/oal-doctor" <<SHIM
#!/bin/bash
printf '%s\n' '{"ok":false,"severity":"problem","checks":[${ids%,}]}'
exit 2
SHIM
  chmod +x "$fake/bin/oal-doctor"
  export OAL_PATH="$fake"
  PATH="$fake/bin:$PATH"
}

@test "the first pass records what is wrong and reports it" {
  # Deliberately the real oal-doctor, so the two are still known to fit together. Everything about
  # transition logic below uses a fixed report instead.
  run oal-watch --once --no-notify
  [ "$status" -eq 0 ]
  [ -f "$SEEN" ]
}

@test "a second pass says nothing, because nothing became news" {
  # A disk that was 96% full an hour ago and still is has not changed. A watcher that says so every
  # ten minutes is one people turn off, after which nothing is watched at all.
  fixed_doctor disk journal
  oal-watch --once --no-notify >/dev/null
  run oal-watch --once --no-notify
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a finding that goes away and comes back is news again" {
  # The other half of "only transitions". Nothing asserted this before, so a watcher that never
  # re-announced a recurring problem would have passed.
  fixed_doctor disk
  oal-watch --once --no-notify >/dev/null
  fixed_doctor            # nothing wrong any more
  oal-watch --once --no-notify >/dev/null
  fixed_doctor disk       # and back
  run oal-watch --once --no-notify
  [[ $output == *disk* ]]
}

@test "--reset makes everything news again" {
  fixed_doctor disk journal oom
  oal-watch --once --no-notify >/dev/null
  [ "$(wc -l <"$SEEN")" -eq 3 ]
  run oal-watch --reset
  [ "$status" -eq 0 ]
  [ ! -f "$SEEN" ]
  run oal-watch --once --no-notify
  [ "$status" -eq 0 ]
  # All three are news again, and reported, not merely recorded.
  [ "$(wc -l <"$SEEN")" -eq 3 ]
  for id in disk journal oom; do [[ $output == *"$id"* ]] || { echo "$id was not re-announced"; false; }; done
}

@test "only problems and warnings are announced, never unknown" {
  # A check that could not run is a gap in the report, not an event. Waking somebody for it teaches
  # them the notification means nothing.
  code "$SRC/bin/oal-watch" | grep -q 'severity == "problem" or .severity == "warn"'
  ! code "$SRC/bin/oal-watch" | grep -q 'severity == "unknown"'

  # And behaviourally, with a report that definitely contains an unknown rather than one that
  # happens to. This used to lean on pacman being absent, which stopped being true for these three
  # checks the day oal-doctor learned apt.
  local fake="$BATS_TEST_TMPDIR/tree"
  fixed_doctor disk
  cat >"$fake/bin/oal-doctor" <<'SHIM'
#!/bin/bash
printf '%s\n' '{"ok":false,"severity":"problem","checks":[
  {"id":"disk","severity":"problem","summary":"disk is unhappy"},
  {"id":"thermal","severity":"unknown","summary":"no sensors here"},
  {"id":"network","severity":"ok","summary":"fine"}]}'
exit 2
SHIM
  chmod +x "$fake/bin/oal-doctor"
  run oal-watch --once --no-notify
  grep -qx disk "$SEEN"        || { echo "the problem was not recorded"; false; }
  ! grep -qx thermal "$SEEN"   || { echo "announced an unknown check"; false; }
  ! grep -qx network "$SEEN"   || { echo "announced a passing check"; false; }
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
