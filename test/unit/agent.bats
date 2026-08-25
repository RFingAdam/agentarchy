#!/usr/bin/env bats
#
# The agent layer's user-visible surface: the permission posture, and the line the prompt draws.
#
# The HUD gets more attention than its size suggests because it runs on every prompt. A prompt
# segment is the one place in a system where a hundred milliseconds is unacceptable and where nobody
# will file a bug -- they will just quietly stop using the shell.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  STATE="$XDG_STATE_HOME/oal"
  mkdir -p "$STATE"

  hud() { run "$SRC/bin/oal-agent-hud" "$@"; }
  profile() { run "$SRC/bin/oal-agent-profile" "$@"; }
  fresh_state() { printf '{"ts":%s,"model":"%s","mcp":%s,"pct":"%s"}\n' "$(date +%s)" "$1" "$2" "$3" >"$STATE/agent-hud.json"; }
}

# --- the permission posture -----------------------------------------------------------------------

@test "the default posture is scoped" {
  profile
  [ "$status" -eq 0 ]
  [ "$output" = "scoped" ]
}

@test "every posture round-trips and lands in settings" {
  for p in trusted scoped untrusted; do
    profile "$p"
    [ "$status" -eq 0 ]
    profile
    [ "$output" = "$p" ] || { echo "wanted $p, got $output"; return 1; }
    jq -e '.permissions' "$CLAUDE_CONFIG_DIR/settings.json" >/dev/null || { echo "$p: no permissions in settings"; return 1; }
  done
}

@test "an unknown posture is refused rather than guessed at" {
  profile yolo
  [ "$status" -ne 0 ]
  [[ $output == *"yolo"* ]]
  profile
  [ "$output" = "scoped" ]
}

@test "applying a posture preserves the rest of the user's settings" {
  # settings.json is the user's file and holds more than permissions. Clobbering it to change one
  # key would be the kind of helpfulness people uninstall a distribution over.
  mkdir -p "$CLAUDE_CONFIG_DIR"
  printf '{"statusLine":{"type":"command","command":"mine"},"permissions":{"allow":["Read(**)"]}}\n' >"$CLAUDE_CONFIG_DIR/settings.json"
  profile untrusted
  [ "$status" -eq 0 ]
  [ "$(jq -r '.statusLine.command' "$CLAUDE_CONFIG_DIR/settings.json")" = "mine" ]
}

@test "untrusted allows nothing by default" {
  profile untrusted
  [ "$(jq -r '.permissions.allow | length' "$CLAUDE_CONFIG_DIR/settings.json")" -eq 0 ]
}

@test "every posture refuses to read secrets" {
  for p in trusted scoped untrusted; do
    deny="$(jq -r '.permissions.deny[]' "$SRC/agent/permissions/$p.json")"
    grep -q '\.env' <<<"$deny" || { echo "$p does not deny .env"; return 1; }
    grep -q 'age' <<<"$deny" || { echo "$p does not deny age keys"; return 1; }
  done
}

# --- the HUD ----------------------------------------------------------------------------------------

@test "with no state file the HUD prints nothing and succeeds" {
  hud
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a stale state file prints nothing rather than yesterday's numbers" {
  printf '{"ts":1,"model":"claude-opus-5","mcp":9,"pct":"38"}\n' >"$STATE/agent-hud.json"
  hud
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a malformed state file prints nothing rather than garbage" {
  printf 'not json at all\n' >"$STATE/agent-hud.json"
  hud
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a fresh state file becomes one line of agent state" {
  fresh_state claude-opus-5 9 38.2
  printf 'scoped\n' >"$STATE/agent-profile"
  hud
  [ "$status" -eq 0 ]
  [[ $output == *"opus-5"* ]]
  [[ $output == *"scoped"* ]]
  [[ $output == *"9 mcp"* ]]
  [[ $output == *"38%"* ]]
  [ "$(grep -c . <<<"$output")" -eq 1 ]
}

@test "zero MCP servers is left out rather than shown as a zero" {
  fresh_state claude-opus-5 0 12
  hud
  [[ $output != *"mcp"* ]]
}

@test "the HUD runs no external commands on the prompt path" {
  # The guard behind the latency budget: a PATH holding bash and nothing else. Any fork of sed, jq,
  # stat or date fails, and the HUD still has to produce its line. PATH cannot simply be emptied --
  # then `#!/usr/bin/env bash` cannot find bash, the script never starts, and the test passes for
  # entirely the wrong reason.
  local onlybash="$BATS_TEST_TMPDIR/onlybash"
  mkdir -p "$onlybash"
  ln -sf "$(command -v bash)" "$onlybash/bash"
  ln -sf "$(command -v env)" "$onlybash/env"
  fresh_state claude-opus-5 3 50
  run env PATH="$onlybash" "$SRC/bin/oal-agent-hud"
  [ "$status" -eq 0 ]
  [[ $output == *"opus-5"* ]]
  [[ $output == *"3 mcp"* ]]
}

@test "the HUD costs less than 20ms a prompt" {
  fresh_state claude-opus-5 9 38
  local start end per
  start=$(date +%s%N)
  for _ in $(seq 1 20); do "$SRC/bin/oal-agent-hud" >/dev/null; done
  end=$(date +%s%N)
  per=$(( (end - start) / 20 / 1000000 ))
  echo "measured ${per}ms per call"
  [ "$per" -lt 20 ]
}

# --- the prompt -------------------------------------------------------------------------------------

@test "the prompt template renders for every theme with nothing left unsubstituted" {
  for dir in "$SRC"/themes/*/; do
    out="$(env OAL_PATH="$SRC" "$SRC/bin/oal-theme-render" starship.toml --file "$dir/colors.toml")" ||
      { echo "$(basename "$dir") failed"; return 1; }
    [[ $out != *"{{"* ]] || { echo "$(basename "$dir") left a placeholder"; return 1; }
  done
}

@test "the prompt uses no powerline glyphs" {
  # The look is the requirement: powerline separators are what make a prompt read as a decade old.
  #
  # The locale is forced because bin/oal-dev-check exports LC_ALL=C, and under C a \x{...} range in
  # grep -P is not a character range at all -- the grep errors out and the assertion passes on the
  # error message instead of on the file. This passed standalone and failed in the gate for exactly
  # that reason.
  run env LC_ALL=C.UTF-8 grep -c -P '[\x{e0b0}-\x{e0d4}]' "$SRC/default/themed/starship.toml.tpl"
  [ "$output" = "0" ] || { echo "powerline glyphs found, or grep failed: $output"; return 1; }
}

@test "the prompt calls the HUD, not the usage collector" {
  # oal-agent-usage-claude is Python and may touch the network. If it ever appears in the prompt
  # template, every keystroke pays for it.
  grep -q 'command = "oal-agent-hud"' "$SRC/default/themed/starship.toml.tpl"
  ! grep -q 'oal-agent-usage' "$SRC/default/themed/starship.toml.tpl"
}

@test "no permission rule uses a form the runtime rejects" {
  # The runtime warns on every single invocation for a malformed rule, and the warning lands in the
  # answer: "Glob(**) is not matched by file permission checks -- only Read(path) rules are. Use
  # Read(**) instead (Read rules cover all file-reading tools)." It shipped that way, so every agent
  # call carried two lines of our own noise before its output.
  #
  # Read(**) already covers the file-reading tools, so these are redundant as well as wrong.
  local f
  for f in "$SRC"/agent/permissions/*.json; do
    ! grep -qE '"(Glob|Grep)\(' "$f" || { echo "$f still names a tool that file permissions do not match"; return 1; }
  done
}

@test "every shipped permission set is valid json with the keys the runtime reads" {
  local f
  for f in "$SRC"/agent/permissions/*.json; do
    jq -e '.permissions.allow | type == "array"' "$f" >/dev/null || { echo "$f: no permissions.allow array"; return 1; }
    jq -e '.permissions.deny | type == "array"' "$f" >/dev/null || { echo "$f: no permissions.deny array"; return 1; }
  done
}
