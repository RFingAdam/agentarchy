#!/usr/bin/env bats
#
# Long-running agent tasks. The property this suite exists for is what happens when the machine
# restarts underneath one: it is held and said out loud, never resumed. A task cut off partway may
# already have written files, pushed commits or sent mail, and neither the journal nor the agent can
# say which -- so repeating it is a person's decision.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$XDG_STATE_HOME" "$HOME"
  TASKS="$XDG_STATE_HOME/oal/brain/tasks"
  oal-brain-backend stub >/dev/null
}

# Wait for a task to leave the running states rather than sleeping a fixed amount.
settle() {
  local id="$1" i
  for i in $(seq 1 50); do
    case "$(oal-brain-tasks | awk -v id="$id" '$1 == id {print $2}')" in
      running|starting|"") sleep 0.2 ;;
      *) return 0 ;;
    esac
  done
  return 1
}

@test "a task runs, records what it was asked, and reaches done" {
  local id
  id="$(oal-brain-run "count to three")"
  settle "$id"
  [ "$(oal-brain-tasks | awk -v id="$id" '$1 == id {print $2}')" = done ]
  oal-brain-show "$id" | grep -q "count to three"
  oal-brain-show "$id" | grep -q "stub: count to three"
}

@test "with no backend it refuses instead of journalling a task that cannot run" {
  oal-brain-backend --none >/dev/null
  run oal-brain-run "anything"
  [ "$status" -ne 0 ]
  [[ $output == *"no brain backend"* ]]
  [ ! -d "$TASKS" ] || [ -z "$(ls -A "$TASKS" 2>/dev/null)" ]
}

@test "a task from a previous boot is held, whatever the pid table says now" {
  # The hazard this closes: across a restart the kernel reissues pids, so a recorded pid can match an
  # unrelated live process and a dead task would report itself as still running.
  local id dir
  id="$(oal-brain-run "long job")"
  settle "$id"
  dir="$TASKS/$id"
  # Put it back to running, owned by a pid that is certainly alive, from a boot that is not this one.
  printf 'state=running\npid=1\nboot=00000000-0000-0000-0000-000000000000\n' >>"$dir/meta"
  [ "$(oal-brain-tasks | awk -v id="$id" '$1 == id {print $2}')" = held ]
}

@test "the sweep reports held tasks and resumes nothing" {
  local id dir before
  id="$(oal-brain-run "long job")"
  settle "$id"
  dir="$TASKS/$id"
  before="$(cat "$dir/output")"
  printf 'state=running\npid=1\nboot=00000000-0000-0000-0000-000000000000\n' >>"$dir/meta"

  run oal-brain-sweep
  [ "$status" -eq 0 ]
  [[ $output == *"interrupted"* ]]
  [[ $output == *"held"* ]]

  # Held, persisted, and not restarted: the output must be exactly what it was.
  [ "$(oal-brain-tasks | awk -v id="$id" '$1 == id {print $2}')" = held ]
  [ "$(cat "$dir/output")" = "$before" ]
  [ "$(oal-brain-tasks --held | wc -l)" -eq 1 ]
}

@test "resuming is explicit, and makes a new task rather than pretending to continue" {
  local id dir new
  id="$(oal-brain-run "long job")"
  settle "$id"
  dir="$TASKS/$id"
  printf 'state=running\npid=1\nboot=00000000-0000-0000-0000-000000000000\n' >>"$dir/meta"

  new="$(oal-brain-resume "$id")"
  [ -n "$new" ]
  [ "$new" != "$id" ]
  settle "$new"
  # The prompt carries over; the old record is closed out rather than reopened.
  oal-brain-show "$new" | grep -q "long job"
  [ "$(oal-brain-tasks | awk -v id="$id" '$1 == id {print $2}')" = superseded ]
}

@test "a task that is still running cannot be resumed" {
  local id
  id="$(oal-brain-run "long job")"
  run oal-brain-resume "$id"
  [ "$status" -ne 0 ]
  settle "$id"
}

@test "nothing enables the resident brain, and the sweep is enabled" {
  # The sweep only reads a journal and reports, so there is no decision to hand over. The resident
  # brain is an always-on process with tool access and stays the owner's call.
  grep -A3 'for unit in' "$SRC/install/agent/runtime.sh" | grep -q 'oal-brain-sweep.service'
  grep -A3 'for unit in' "$SRC/install/agent/runtime.sh" | grep -q 'systemctl --user enable'
  ! grep -rhE '^[^#]*systemctl[^#]*enable[^#]*oal-brain\.service' "$SRC/install" "$SRC/PKGBUILD" 2>/dev/null | grep -q .
}
