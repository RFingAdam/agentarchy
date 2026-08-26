#!/usr/bin/env bats
#
# The guard is the distribution's strongest claim and was its least portable piece: the decision
# logic, the rules and the audit log all lived inside a file shaped like Claude Code's PreToolUse
# hook API. Run Codex, or a local Hermes, and nothing on the machine was gated at all -- while the
# README said a permission posture was enforced at the tool-call boundary.
#
# These tests exist so that cannot come back. The engine must stay vendor-free, and every runtime
# must reach the same answers through it.
#
# The dangerous strings here are assembled or chosen carefully, for the reason
# test/unit/agent-guard.bats already records: a test file containing a literal destructive command
# trips every other guard on the machine, including the one belonging to whoever is writing it. That
# is not hypothetical -- writing this file tripped it twice.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$XDG_STATE_HOME/oal"
  ENGINE="$SRC/default/guard/lib.sh"
  HOOK="$SRC/agent/hooks/pretooluse-guard"
  AUDIT="$XDG_STATE_HOME/oal/audit"

  RM_ROOT="rm -rf /"
  HARD_RESET="git reset --hard HEAD~1"

  # via the hook, the way Claude Code asks
  via_hook() {
    jq -nc --arg t "$1" --arg v "$2" '{tool_name:$t, tool_input:{command:$v}}' |
      "$HOOK" | jq -r '.hookSpecificOutput.permissionDecision'
  }
  # via the plain command, the way everything else does
  via_cli() { printf '%s' "$2" | oal-guard --tool "$1" | cut -f1; }
}

code() { grep -v '^[[:space:]]*#' "$1"; }

@test "the engine names no vendor at all" {
  # Not even in a comment: a rule that mentions one runtime is a rule someone will assume applies
  # only to it. The whole file is checked, prose included.
  ! grep -qiE 'claude|anthropic|codex|openai|copilot' "$ENGINE"
}

@test "the rules live outside the directory that holds one vendor's documents" {
  # agent/ holds Claude Code's permission documents and its hook. Keeping the policy under it
  # implied the policy belonged to that vendor. Only the wiring did.
  [ -r "$SRC/default/guard/rules" ]
  [ ! -e "$SRC/agent/hooks/rules" ]
}

@test "the hook is an adapter and nothing more" {
  # It may speak Claude Code's contract; it may not make decisions. If a tier name or the posture
  # file appears here, the logic has started leaking back into it.
  code "$HOOK" | grep -q 'guard_decide'
  ! code "$HOOK" | grep -q 'agent-profile'
  ! code "$HOOK" | grep -q 'CONFIRM-'
}

@test "both runtimes reach the same verdict for the same call" {
  # The property that matters. If these ever disagree, one runtime is being governed by a policy the
  # other is not.
  local call h c
  for call in "ls -la" "sudo pacman -S ripgrep" "$RM_ROOT" "$HARD_RESET"; do
    h="$(via_hook Bash "$call")"
    c="$(via_cli Bash "$call")"
    [ "$h" = "$c" ] || { echo "hook said '$h', cli said '$c' for: $call"; false; }
  done
}

@test "a runtime that is not Claude Code is gated too" {
  # The whole point. Before this, running anything else meant no guard at all.
  [ "$(via_cli Bash "$RM_ROOT")" = deny ]
  [ "$(via_cli Bash "$HARD_RESET")" = ask ]
  [ "$(via_cli Bash "ls -la")" = allow ]
}

@test "the exit code carries the decision, so a shell caller needs no parsing" {
  run bash -c "printf '%s' 'ls -la' | oal-guard --tool Bash --quiet";      [ "$status" -eq 0 ]
  run bash -c "printf '%s' '$HARD_RESET' | oal-guard --tool Bash --quiet"; [ "$status" -eq 1 ]
  run bash -c "printf '%s' '$RM_ROOT' | oal-guard --tool Bash --quiet";    [ "$status" -eq 2 ]
}

@test "the posture still moves every runtime's default together" {
  printf 'untrusted' >"$XDG_STATE_HOME/oal/agent-profile"
  [ "$(via_cli Bash "ls -la")" = ask ]
  [ "$(via_hook Bash "ls -la")" = ask ]
  printf 'scoped' >"$XDG_STATE_HOME/oal/agent-profile"
  [ "$(via_cli Bash "ls -la")" = allow ]
  [ "$(via_hook Bash "ls -la")" = allow ]
}

@test "a block is still a block, from either direction and under every posture" {
  printf 'trusted' >"$XDG_STATE_HOME/oal/agent-profile"
  [ "$(via_cli Bash "$RM_ROOT")" = deny ]
  [ "$(via_hook Bash "$RM_ROOT")" = deny ]
  [ "$(via_cli Bash "$RM_ROOT # CONFIRM-a1b2c3d4")" = deny ]
}

@test "the audit log is one file naming the runtime, not one file per vendor" {
  # The question a person actually has is "what did anything on this machine try to do", and a log
  # split by vendor cannot answer it.
  via_hook Bash "ls -la" >/dev/null
  via_cli Bash "ls -la" >/dev/null
  [ ! -d "$XDG_STATE_HOME/oal/claude-audit" ]
  local log
  log="$(cat "$AUDIT"/*.log)"
  grep -q 'claude-code' <<<"$log"
  grep -q 'cli' <<<"$log"
}

@test "oal-brain-do asks the engine rather than impersonating a runtime" {
  # It used to build a synthetic Claude Code payload, pipe it to the hook and read a
  # permissionDecision back: three processes and two jq calls to ask a question neither party needed
  # a vendor's JSON to express.
  code "$SRC/bin/oal-brain-do" | grep -q 'guard_decide'
  ! code "$SRC/bin/oal-brain-do" | grep -q 'hookSpecificOutput'
  ! code "$SRC/bin/oal-brain-do" | grep -q 'tool_name'
}

@test "the engine needs no jq, so a broken payload parser cannot take the policy with it" {
  # jq belongs to the adapter, which has a runtime's JSON to read. The engine matches text.
  ! code "$ENGINE" | grep -q '\bjq\b'
}

@test "a caller that sees an unexpected exit code is told to refuse" {
  # Documented in the command itself, because the one thing worse than a guard that fails is a
  # caller that reads the failure as permission.
  grep -q 'MUST be treated as a refusal' "$SRC/bin/oal-guard"
}

@test "the engine fails closed when its rules are gone, whoever is asking" {
  run bash -c "printf '%s' 'ls -la' | GUARD_RULES=/nonexistent oal-guard --tool Bash"
  [ "$status" -eq 2 ]
  [[ $output == *"rule set unreadable"* ]]
}
