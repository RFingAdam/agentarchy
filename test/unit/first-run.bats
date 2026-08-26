#!/usr/bin/env bats
#
# install/user/first-run/ -- the ISO's first-login path.
#
# The whole directory was dead code that read exactly like live code. bin/oal-provision-first-run
# runs it, is on PATH, and nothing anywhere called it: upstream drives it from a compositor autostart
# that was excluded from vendoring. Because it never ran, nobody noticed that its notification cards
# clicked through to four commands this tree does not have.
#
# These tests assert the two things that were wrong: that it has a caller, and that everything it
# offers can actually be reached.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  FR="$SRC/install/user/first-run"
  RUNNER="$SRC/bin/oal-provision-first-run"
  UNIT="$SRC/default/systemd/user/oal-first-run.service"
}

code() { grep -v '^[[:space:]]*#' "$@"; }

# The files the runner actually installs or executes. install-voxtype.hook is deliberately not one
# of them; see the test below.
active_files() {
  code "$RUNNER" | grep -oE 'first-run/[a-z-]+\.(sh|hook)' | sed "s|^|$SRC/install/user/|" | sort -u
}

@test "the runner has a caller, which is the thing that was missing" {
  [ -f "$UNIT" ]
  grep -q 'ExecStart=/usr/bin/oal-provision-first-run' "$UNIT"
  grep -q 'oal-first-run.service' "$SRC/install/agent/runtime.sh"
}

@test "the caller runs on the path a bootstrap install actually takes" {
  # install/user/first-run is the ISO's path and oal-bootstrap.sh does not run that directory, so
  # enabling this from there would have been enabling it from inside the thing that never ran.
  grep -q 'install/agent/runtime.sh' "$SRC/oal-bootstrap.sh"
  grep -A4 'for unit in' "$SRC/install/agent/runtime.sh" | grep -q 'oal-first-run.service'
}

@test "running it every login is harmless, because it guards itself" {
  grep -q 'oal-done check' "$RUNNER"
  grep -q 'exit 0' "$RUNNER"
}

@test "it needs a session, and says so rather than half-running without one" {
  grep -q 'ConditionEnvironment=WAYLAND_DISPLAY' "$UNIT"
}

@test "the package installs the unit where systemd looks" {
  grep -q 'usr/lib/systemd/user' "$SRC/PKGBUILD"
  grep -q 'default/systemd/user/\*\.service' "$SRC/PKGBUILD"
}

@test "every command the active hooks call resolves" {
  local f cmd missing=""
  while read -r f; do
    [ -f "$f" ] || continue
    while read -r cmd; do
      [ -n "$cmd" ] || continue
      # Unit names and PAM files share the prefix but are not commands.
      case "$cmd" in oal-*-fingerprint) [[ $cmd == oal-lock-fingerprint ]] && continue ;; esac
      [[ -e $SRC/default/systemd/user/$cmd.service || -e $SRC/default/systemd/user/$cmd.timer ]] && continue
      [ -x "$SRC/bin/$cmd" ] || missing+="$(basename "$f") -> $cmd"$'\n'
    done < <(code "$f" | grep -oE '\boal-[a-z0-9-]+\b' | sort -u)
  done < <(active_files)
  [ -z "$missing" ] || { echo "unresolvable:"; echo "$missing"; false; }
}

@test "every notification's click target resolves" {
  # This is the part that was broken and invisible: the send succeeds whatever --exec points at, so
  # a dead click target looks exactly like a working one until somebody clicks it.
  local f target cmd missing=""
  while read -r f; do
    [ -f "$f" ] || continue
    while read -r target; do
      cmd="${target%% *}"
      [[ $cmd == oal-* ]] || continue
      [ -x "$SRC/bin/$cmd" ] || missing+="$(basename "$f") --exec $cmd"$'\n'
    done < <(code "$f" | grep -oE -- '--exec +"[^"]+"|--exec +[^ ]+' |
             sed -e 's/^--exec  *//' -e 's/^"//' -e 's/"$//')
  done < <(active_files)
  [ -z "$missing" ] || { echo "dead click targets:"; echo "$missing"; false; }
}

@test "the dictation invitation is not installed, because dictation is not vendored" {
  # default/voxtype/** is excluded as compositor-bound, so oal-voxtype-install does not exist here.
  # An invitation to something unavailable is worse than none: it costs a click to find out.
  [ -f "$FR/install-voxtype.hook" ]
  ! code "$RUNNER" | grep -q 'install-voxtype.hook'
}

@test "the agent invitation asks the setting this machine actually keeps" {
  # It tested oal-default-agent, which does not exist, so the substitution came back empty and the
  # card fired whether or not an agent had been chosen.
  code "$FR/setup-agent.hook" | grep -q 'oal-brain-backend'
  ! code "$FR/setup-agent.hook" | grep -q 'oal-default-agent'
}

@test "the changes to vendored files are captured as patches" {
  # Or the next vendor sync silently reverts all of this.
  ls "$SRC"/upstream/patches/*first-run*.patch >/dev/null
}
