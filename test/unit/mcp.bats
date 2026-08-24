#!/usr/bin/env bats
#
# MCP servers managed like packages. The catalog is data, the commands are thin, and the thing worth
# pinning is that they never touch a real agent config: every case here puts a stub `claude` on PATH
# that records its arguments. Writing this suite against the real runtime registered a server into a
# developer's own ~/.claude.json, which is exactly the accident the stub prevents.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"

  stub="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub"
  export MCP_REG="$BATS_TEST_TMPDIR/registered"
  : >"$MCP_REG"
  cat >"$stub/claude" <<'STUB'
#!/usr/bin/env bash
# Records what a real `claude mcp` would have been asked to do.
case "$2" in
  add)    printf '%s\n' "$3" >>"$MCP_REG"; printf 'add %s\n' "$*" >>"$MCP_REG.calls" ;;
  remove) grep -vx -- "$3" "$MCP_REG" >"$MCP_REG.tmp" || true; mv "$MCP_REG.tmp" "$MCP_REG" ;;
  list)   while read -r n; do [[ -n $n ]] && printf '%s: stub\n' "$n"; done <"$MCP_REG" ;;
esac
exit 0
STUB
  chmod +x "$stub/claude"
  export PATH="$stub:$PATH"

  mcp() { run "$SRC/bin/oal-mcp-$1" "${@:2}"; }
}

# --- the catalog is data, so it gets checked like data -------------------------------------------

@test "every catalog row is complete and well formed" {
  while IFS='|' read -r id kind package args profiles description; do
    id="$(xargs <<<"$id")"
    [[ -n $id && $id != \#* ]] || continue
    [[ $(xargs <<<"$kind") =~ ^(uvx|npx)$ ]] || { echo "$id: kind '$kind'"; return 1; }
    [[ -n $(xargs <<<"$package") ]] || { echo "$id: no package"; return 1; }
    [[ -n $(xargs <<<"$profiles") ]] || { echo "$id: no profile"; return 1; }
    [[ -n $(sed -e 's/^ *//' -e 's/ *$//' <<<"$description") ]] || { echo "$id: no description"; return 1; }
  done < <(grep -v '^[[:space:]]*#' "$SRC/default/mcp/CATALOG" | grep '|')
}

@test "an empty args column does not shift the later fields" {
  # Tab is IFS whitespace, so bash collapses a run of tabs into one delimiter and a row with no args
  # silently reads its profiles into the args slot. That bug shipped and was caught by `git` not
  # appearing in the minimal profile; the catalog is US-separated because of it.
  mcp list --profile minimal
  [ "$status" -eq 0 ]
  for want in filesystem git fetch time; do
    grep -q "^$want " <<<"$output" || { echo "missing $want:"; echo "$output"; return 1; }
  done
}

@test "profiles resolve to servers that exist" {
  for p in minimal dev; do
    mcp list --profile "$p"
    [ "$status" -eq 0 ]
    [ "$(grep -c . <<<"$output")" -gt 1 ] || { echo "profile $p is empty"; return 1; }
  done
}

# --- install and remove ---------------------------------------------------------------------------

@test "installing registers the server with the runtime" {
  mcp install git
  [ "$status" -eq 0 ]
  [[ $output == *"git: registered"* ]]
  grep -qx git "$MCP_REG"
  grep -q -- 'add mcp add git -- uvx mcp-server-git' "$MCP_REG.calls"
}

@test "a server needing an argument gets it, with \$HOME expanded" {
  mcp install filesystem
  [ "$status" -eq 0 ]
  grep -q -- "add mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem $HOME" "$MCP_REG.calls"
}

@test "installing twice is not an error" {
  mcp install git
  mcp install git
  [ "$status" -eq 0 ]
  [[ $output == *"already registered"* ]]
  [ "$(grep -cx git "$MCP_REG")" -eq 1 ]
}

@test "a profile installs every server in it" {
  mcp install --profile minimal
  [ "$status" -eq 0 ]
  for want in filesystem git fetch time; do grep -qx "$want" "$MCP_REG" || { echo "missing $want"; return 1; }; done
}

@test "an unknown server is named, and does not stop the rest" {
  mcp install git no-such-server fetch
  [ "$status" -ne 0 ]
  [[ $output == *"unknown server: no-such-server"* ]]
  grep -qx git "$MCP_REG"
  grep -qx fetch "$MCP_REG"
}

@test "removing unregisters, and is not a one-way door" {
  mcp install git
  mcp remove git
  [ "$status" -eq 0 ]
  [[ $output == *"git: removed"* ]]
  ! grep -qx git "$MCP_REG"
  mcp install git
  [ "$status" -eq 0 ]
}

@test "status counts what is registered" {
  mcp status --count
  [ "$output" = "0" ]
  mcp install --profile minimal
  mcp status --count
  [ "$output" = "4" ]
}

@test "a server registered outside any catalog is reported as external" {
  printf 'hand-added\n' >>"$MCP_REG"
  mcp status
  [ "$status" -eq 0 ]
  [[ $output == *"hand-added"*"external"* ]]
}

# --- the extension point ---------------------------------------------------------------------------

@test "an imported catalog is usable and stays marked as imported" {
  cat >"$BATS_TEST_TMPDIR/rf-lab.catalog" <<'CAT'
spectrum-sim | uvx | example-spectrum-sim |  | lab | Sweep a simulated analyser
CAT
  mcp import "$BATS_TEST_TMPDIR/rf-lab.catalog"
  [ "$status" -eq 0 ]
  mcp list --profile lab
  [[ $output == *"spectrum-sim"*"rf-lab"* ]]
  # The distinction is the point: it must never read as something this repository vouches for.
  [[ $output != *"spectrum-sim"*"shipped"* ]]
  mcp install spectrum-sim
  [ "$status" -eq 0 ]
  grep -qx spectrum-sim "$MCP_REG"
}

@test "a malformed imported catalog is refused with the row named" {
  cat >"$BATS_TEST_TMPDIR/bad.catalog" <<'CAT'
broken | wasm | some-package |  | lab | Not a kind we can run
CAT
  mcp import "$BATS_TEST_TMPDIR/bad.catalog"
  [ "$status" -ne 0 ]
  [[ $output == *"broken"* && $output == *"wasm"* ]]
}

@test "forgetting a catalog leaves registered servers alone" {
  cat >"$BATS_TEST_TMPDIR/rf-lab.catalog" <<'CAT'
spectrum-sim | uvx | example-spectrum-sim |  | lab | Sweep a simulated analyser
CAT
  mcp import "$BATS_TEST_TMPDIR/rf-lab.catalog"
  mcp install spectrum-sim
  mcp import --forget rf-lab
  [ "$status" -eq 0 ]
  grep -qx spectrum-sim "$MCP_REG"
  mcp status
  [[ $output == *"spectrum-sim"*"external"* ]]
}
