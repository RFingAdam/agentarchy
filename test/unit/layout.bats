#!/usr/bin/env bats
#
# Panel layouts. The scripts themselves can only be judged by a running Plasma, so what is pinned
# here is everything around them: that the presets exist and are well formed, that the command
# refuses clearly when there is nothing to apply them to, and that it does not reconfigure a desktop
# when run with no arguments.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  layout() { run "$SRC/bin/oal-layout-set" "$@"; }
}

@test "both presets are listed" {
  layout --list
  [ "$status" -eq 0 ]
  grep -qx ubuntu <<<"$output"
  grep -qx mint <<<"$output"
}

@test "with no argument it reports rather than acts" {
  # A command that reconfigures a desktop when run bare is a command people run once.
  layout
  [ "$status" -eq 0 ]
  [[ $output == *"none recorded"* ]]
}

@test "an unknown layout is refused and names the way to find the real ones" {
  layout sway
  [ "$status" -ne 0 ]
  [[ $output == *"sway"* && $output == *"--list"* ]]
}

@test "without a graphical session it refuses instead of half-applying" {
  # Applying a preset removes every panel. Doing that with no session to apply it to would be the
  # worst of both: the arrangement gone and nothing put back.
  run env -u WAYLAND_DISPLAY -u DISPLAY OAL_PATH="$SRC" XDG_STATE_HOME="$XDG_STATE_HOME" \
    "$SRC/bin/oal-layout-set" ubuntu
  [ "$status" -ne 0 ]
  [[ $output == *"no graphical session"* ]]
  [ ! -e "$XDG_STATE_HOME/oal/layout" ]
}

@test "every preset removes the panels it is replacing" {
  # A preset that adds panels without clearing the old ones stacks them, which looks like a bug in
  # Plasma rather than in us.
  for f in "$SRC"/default/layouts/*.js; do
    grep -q 'panels().forEach' "$f" || { echo "$(basename "$f") does not clear existing panels"; return 1; }
  done
}

@test "every preset provides a way to reach running windows" {
  # The dock replaced the task list, and the spike left this open: a dock of pure launchers would
  # have removed window switching and put nothing in its place.
  for f in "$SRC"/default/layouts/*.js; do
    grep -qE 'plasma\.(icontasks|taskmanager)' "$f" ||
      { echo "$(basename "$f") has no task manager, so there is no way to switch windows"; return 1; }
  done
}

@test "every preset provides a launcher and a clock" {
  for f in "$SRC"/default/layouts/*.js; do
    grep -q 'plasma.kickoff' "$f" || { echo "$(basename "$f") has no launcher"; return 1; }
    grep -q 'plasma.digitalclock' "$f" || { echo "$(basename "$f") has no clock"; return 1; }
  done
}

@test "the first-login entry runs once and is wired to the command" {
  entry="$SRC/config/autostart/oal-layout-first-login.desktop"
  grep -q '^Exec=oal-layout-first-login' "$entry"
  grep -q '^OnlyShowIn=KDE;' "$entry"
  # The guard that stops it flattening a customised desktop at every login.
  grep -q 'state' "$SRC/bin/oal-layout-first-login"
  grep -qE '\[\[ -e \$state \]\] && exit 0' "$SRC/bin/oal-layout-first-login"
}
