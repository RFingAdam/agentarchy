#!/usr/bin/env bats
#
# The brain contract. What is being tested here is not that a backend answers -- backends are
# somebody else's software -- but that the boundary holds:
#
#   the verb set is what the documentation says it is,
#   a verb outside it is refused even when a backend would happily perform it, and
#   a verb inside it is still refused when the tool-call guard says no.
#
# The last one is the one worth having. Without it the verb table is the only control, and a verb
# table is exactly as good as whoever edited it last.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$XDG_STATE_HOME" "$HOME"
}

# A tree that is the real one except for the two files the contract is defined by, so a test can add
# a verb the distribution does not ship and watch what still refuses it.
fake_tree() {
  FAKE="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$FAKE/default/brain"
  ln -sfn "$SRC/bin" "$FAKE/bin"
  ln -sfn "$SRC/agent" "$FAKE/agent"
  ln -sfn "$SRC/themes" "$FAKE/themes"
  ln -sfn "$SRC/default/brain/adapters" "$FAKE/default/brain/adapters"
  cp "$SRC/default/brain/lib.sh" "$FAKE/default/brain/lib.sh"
  cp "$SRC/default/brain/VERBS" "$FAKE/default/brain/VERBS"
}

# add_verb <name> <command...> -- a verb in the set, resolving to whatever the caller wants.
add_verb() {
  local name="$1"; shift
  printf '%s | none | added by a test\n' "$name" >>"$FAKE/default/brain/VERBS"
  {
    printf '\nbrain_resolve_%s() {\n' "$name"
    printf "  printf '%%s\\\\0'"
    printf ' %q' "$@"
    printf '\n}\n'
  } >>"$FAKE/default/brain/lib.sh"
}

# --- the set is what the documentation says it is -------------------------------------------------

@test "every documented verb is implemented, and every implemented verb is documented" {
  local documented implemented
  documented="$(sed -n 's/^\([a-z][a-z-]*\) *|.*/\1/p' "$SRC/default/brain/VERBS" | sort)"
  implemented="$(sed -n 's/^brain_resolve_\([a-z_]*\)().*/\1/p' "$SRC/default/brain/lib.sh" | sort)"
  [ "$documented" = "$implemented" ]
}

@test "the verb set is small enough that someone has read all of it" {
  # Not a style rule. The contract's guarantee is that a person can hold the whole surface in their
  # head; a verb set that grew to thirty would be an allowlist nobody audits.
  local n
  n="$(sed -n '/^[a-z]/p' "$SRC/default/brain/VERBS" | wc -l)"
  [ "$n" -le 8 ]
}

# --- nothing is on by default ---------------------------------------------------------------------

@test "no backend is configured out of the box, and status stays quiet about it" {
  run oal-brain-status
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "nothing in the tree enables the resident service" {
  ! grep -rqE 'enable.*oal-brain\.service' "$SRC/bin" "$SRC/install" "$SRC/oal-bootstrap.sh"
}

@test "asking with no backend says so rather than failing silently" {
  run oal-brain-ask "anything"
  [ "$status" -ne 0 ]
  [[ $output == *"no brain backend"* ]]
}

# --- selecting one --------------------------------------------------------------------------------

@test "a backend round-trips, and --none puts it back" {
  run oal-brain-backend stub
  [ "$status" -eq 0 ]
  [ "$(oal-brain-backend)" = stub ]
  oal-brain-backend --none
  [ -z "$(oal-brain-backend)" ]
}

@test "a backend with no adapter is refused rather than recorded" {
  run oal-brain-backend not-a-real-backend
  [ "$status" -ne 0 ]
  [ -z "$(oal-brain-backend)" ]
}

@test "the shipped adapters are listed" {
  run oal-brain-backend --list
  [[ $output == *stub* ]]
  [[ $output == *claude-code* ]]
  [[ $output == *hermes* ]]
}

@test "a question round-trips through the configured backend" {
  oal-brain-backend stub >/dev/null
  run oal-brain-ask "what theme am I using"
  [ "$status" -eq 0 ]
  [ "$output" = "stub: what theme am I using" ]
}

@test "a prompt arrives whole, newlines and quotes included" {
  # The prompt goes to the adapter on stdin for this reason. In argv it is one bad quote from being
  # somebody else's bug.
  oal-brain-backend stub >/dev/null
  run bash -c "printf 'first line\nsecond \"quoted\" line\n' | oal-brain-ask"
  [ "$status" -eq 0 ]
  [[ $output == *'second "quoted" line'* ]]
}

# --- the boundary -----------------------------------------------------------------------------------

@test "a verb outside the set is refused" {
  run oal-brain-do reboot
  [ "$status" -ne 0 ]
  [[ $output == *"not in the verb set"* ]]
}

@test "a verb inside the set still checks its own arguments" {
  run oal-brain-do theme no-such-theme
  [ "$status" -ne 0 ]
  [[ $output == *"no theme called"* ]]

  # The check that makes 'open' a verb rather than a shell: an id, not a path.
  run oal-brain-do open /usr/bin/bash
  [ "$status" -ne 0 ]
  [[ $output == *"desktop entry id"* ]]
}

@test "a verb in the set is refused when the guard blocks what it resolves to" {
  # Defence in depth, and the case the whole design turns on. The verb table says yes; the guard
  # says no; no is the answer. Without this the table is the only control.
  fake_tree
  add_verb wipe oal-system-factory-reset --yes
  run env OAL_PATH="$FAKE" "$SRC/bin/oal-brain-do" wipe
  [ "$status" -ne 0 ]
  [[ $output == *"refused by the tool-call guard"* ]]
}

@test "a confirm-tier command is refused, not asked, because a brain has nobody to ask" {
  # The confirm tier means a person opts in per call. There is no person on this path, and treating
  # an absent one as consent is how the tier stops meaning anything.
  fake_tree
  add_verb install sudo pacman -S ripgrep
  run env OAL_PATH="$FAKE" "$SRC/bin/oal-brain-do" install
  [ "$status" -ne 0 ]
  [[ $output == *"nobody to ask"* ]]
}

@test "with the guard missing, nothing runs" {
  # Fail closed, for the same reason the guard does. A brain that acts when the control governing it
  # is absent is a brain with no control, and from the outside those look identical.
  fake_tree
  rm -f "$FAKE/agent"
  mkdir -p "$FAKE/agent/hooks"
  run env OAL_PATH="$FAKE" "$SRC/bin/oal-brain-do" state
  [ "$status" -ne 0 ]
  [[ $output == *"guard is not installed"* ]]
}

@test "oal-brain-notify goes through the boundary rather than around it" {
  # A shortcut to the notification service would be a hole with a friendly name.
  grep -q 'oal-brain-do" notify' "$SRC/bin/oal-brain-notify"
  ! grep -q 'oal-notification-send' "$SRC/bin/oal-brain-notify"
}

@test "an allowed verb actually runs" {
  run oal-brain-do state
  [ "$status" -eq 0 ]
  [[ $output == *"host:"* ]]
}

@test "every shipped adapter implements the contract it is judged by" {
  local a
  for a in "$SRC"/default/brain/adapters/*; do
    [ -x "$a" ] || { echo "not executable: $a"; return 1; }

    # describe: one line, always answerable. oal-brain-status prints it, so an adapter that needs a
    # reachable backend to say what it is makes the status output useless exactly when it is needed.
    run "$a" describe
    [ "$status" -eq 0 ]
    [ "$(wc -l <<<"$output")" -eq 1 ]

    # An unknown subcommand is an error, not a silent success. An adapter that exits 0 on anything
    # would make `probe` meaningless and every backend look reachable.
    run "$a" not-a-subcommand
    [ "$status" -ne 0 ]

    # probe must answer rather than hang: oal-agent-hud calls it on a timer.
    run timeout 20 "$a" probe
    [ "$status" -ne 124 ]
  done
}

@test "the resident service is installed where systemd looks, and still not enabled" {
  # It was shipped to /usr/share/agentarchy/default/systemd/user, which systemd never reads, so the
  # command docs/brain.md tells you to run answered "not-found". Shipped, documented, unusable.
  grep -q 'usr/lib/systemd/user' "$SRC/PKGBUILD"
  [ -f "$SRC/default/systemd/user/oal-brain.service" ]
  # Installing it must not enable it: an always-on process with tool access stays an explicit choice.
  # Comments are stripped first -- the sentence above explaining the fix matched this grep and failed
  # the test, which is the third time a check in this tree has caught its own prose.
  # oal-brain.service exactly. oal-brain-sweep.service IS enabled and should be -- it reads the task
  # journal and reports; it starts nothing. Matching the prefix caught it and failed this test.
  ! grep -rhE '^[^#]*systemctl[^#]*enable[^#]*oal-brain\.service' "$SRC/PKGBUILD" "$SRC/install" 2>/dev/null | grep -q .
}

@test "the hermes adapter drives the CLI, not an invented HTTP endpoint" {
  # It was first written against a guessed gateway -- POST /v1/chat, a bearer token, a jq filter over
  # the reply -- because no instance was available. Hermes drives from a command line. The guesses
  # were removed rather than kept as a fallback: an untested second path is a second thing to debug.
  local a="$SRC/default/brain/adapters/hermes"
  grep -q 'hermes -z' "$a"
  grep -q 'hermes serve' "$a"
  ! grep -E '^[^#]*(v1/chat|HERMES_URL|curl)' "$a" | grep -q .
}

@test "the hermes adapter answers serve --check, so it is not restarted forever" {
  # oal-brain-serve asks before running anything. A backend that answered a usage error here would be
  # restarted every five seconds for as long as the machine is up.
  #
  # The branch exists unconditionally; the answer depends on whether Hermes is installed, and
  # answering "yes, serve me" on a machine without it is exactly the restart loop --check prevents.
  # Asserting exit 0 everywhere made this pass on a developer's machine and fail in CI, which is a
  # test reporting where it ran rather than what the code does.
  grep -q 'check.*exit 0' "$SRC/default/brain/adapters/hermes"

  command -v hermes >/dev/null || skip "Hermes is not installed on this machine"
  run "$SRC/default/brain/adapters/hermes" serve --check
  [ "$status" -eq 0 ]
}

@test "the hermes adapter can be pointed at another machine's Hermes" {
  # "It should point to our existing instance" is one setting, not a different adapter. hermes peer
  # dm messages an agent on a registered peer and prints its reply.
  local a="$SRC/default/brain/adapters/hermes"
  grep -q 'hermes peer dm' "$a"
  grep -q 'HERMES_PEER' "$a"
  # The message goes on stdin for the same reason the contract does: a prompt is full of quotes and
  # newlines, and argv is where those become somebody else's bug.
  grep -q "printf '%s' \"\$prompt\" | hermes peer dm" "$a"
}

@test "asking a peer does not also ask the local agent" {
  # `exec` inside a pipeline replaces only that subshell. Written that way the script carried on to
  # the local branch and asked twice: once on the peer, once here, billing both.
  local a="$SRC/default/brain/adapters/hermes"
  ! grep -q '| exec hermes' "$a"
  grep -A2 'hermes peer dm "$peer"' "$a" | grep -q 'exit \$?'
}

@test "a peer that is not registered is not reported as reachable" {
  # Otherwise the panel shows a brain that cannot answer as up, and the first anyone hears of it is a
  # question that goes nowhere.
  command -v hermes >/dev/null || skip "Hermes is not installed on this machine"
  local cfg="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$cfg/oal/brain"
  printf 'HERMES_PEER=definitely-not-registered\n' >"$cfg/oal/brain/hermes.env"
  run env XDG_CONFIG_HOME="$cfg" "$SRC/default/brain/adapters/hermes" probe
  [ "$status" -ne 0 ]
}

@test "the hermes adapter can reach a Hermes over ssh" {
  # The mode that needs nothing changed on the remote. A Hermes worth pointing at is usually a
  # server, and a server's api_server is typically bound to 127.0.0.1 -- reaching that with peer dm
  # means exposing a port or running a tunnel, both decisions about somebody's infrastructure.
  local a="$SRC/default/brain/adapters/hermes"
  grep -q 'HERMES_SSH' "$a"
  # The prompt is read on the far side, so it is never a shell word on either hop.
  grep -q "hermes -z \"\\\$(cat)\"" "$a"
  # Same pipeline trap as the peer branch: exec would replace only the subshell and fall through.
  grep -A3 "remote 'hermes -z" "$a" | grep -q 'exit \$?'
}

@test "ssh mode wins over a peer, and a resident backend is not supervised from here" {
  local a="$SRC/default/brain/adapters/hermes"
  # over_ssh is tested before peer in ask, describe and probe.
  grep -q 'if \[\[ -n $over_ssh \]\]; then' "$a"
  # serve refuses over ssh: a resident process on another machine is that machine's business, and a
  # local unit babysitting it would restart something it does not own.
  grep -A3 '^  serve)' "$a" | grep -q 'over_ssh.*exit 1'
}

@test "an ssh host that is not reachable is not reported as a working brain" {
  local cfg="$BATS_TEST_TMPDIR/sshcfg"
  mkdir -p "$cfg/oal/brain"
  printf 'HERMES_SSH=definitely.not.a.host.invalid\n' >"$cfg/oal/brain/hermes.env"
  run env XDG_CONFIG_HOME="$cfg" "$SRC/default/brain/adapters/hermes" probe
  [ "$status" -ne 0 ]
}
