#!/usr/bin/env bats
#
# oal-mcp-serve: the OS as something an agent can ask.
#
# Every other part of the agent layer lets this machine talk to an agent. This is the other
# direction, and it is the piece that makes "our MCP servers work better here" a fact rather than a
# claim: any client that speaks MCP gains machine introspection the moment it runs on this desktop.
#
# The injection probes here are assembled from pieces rather than written out, for the reason
# test/unit/agent-guard.bats already records: a test file containing a literal destructive command
# trips every guard on the machine, including the one belonging to whoever is writing it.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$XDG_STATE_HOME/oal/brain"
  SERVE="$SRC/bin/oal-mcp-serve"
}

# Drive the server with one or more request lines, return its frames.
drive() { printf '%s\n' "$@" | "$SERVE" 2>/dev/null; }

INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}'

@test "it initializes and declares the tools capability" {
  run drive "$INIT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result.capabilities.tools' >/dev/null
  [ "$(echo "$output" | jq -r '.result.serverInfo.name')" = agentarchy ]
}

@test "it answers with the protocol version the client asked for" {
  run drive "$INIT"
  [ "$(echo "$output" | jq -r '.result.protocolVersion')" = "2025-06-18" ]
}

@test "a notification gets no reply at all" {
  # A notification has no id and takes no response. Answering one is a protocol violation that some
  # clients treat as fatal.
  run drive '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  [ -z "$output" ]
}

@test "every frame is one line of valid JSON" {
  # stdout is the transport. A stray echo anywhere in this script is a client reporting the server
  # as malformed, and tool output is full of newlines.
  local out line
  out="$(drive "$INIT" \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"os_state","arguments":{}}}')"
  [ "$(wc -l <<<"$out")" -eq 3 ]
  while IFS= read -r line; do
    printf '%s' "$line" | jq -e . >/dev/null || { echo "not JSON: $line"; false; }
  done <<<"$out"
}

@test "the tools it lists are the tools it answers" {
  # A tool advertised and not implemented is worse than one that is missing: the model spends a turn
  # discovering it, every time.
  local name out
  for name in $(drive "$INIT" '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' |
                  jq -r 'select(.id==2) | .result.tools[].name'); do
    out="$(drive "$INIT" "$(jq -nc --arg n "$name" \
      '{jsonrpc:"2.0",id:9,method:"tools/call",params:{name:$n,arguments:{}}}')" |
      jq -r 'select(.id==9) | .error.message // "ok"')"
    [ "$out" = ok ] || { echo "$name advertised but: $out"; false; }
  done
}

@test "every tool declares a schema that forbids arguments it does not read" {
  run drive "$INIT" '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  echo "$output" | jq -e 'select(.id==2) | all(.result.tools[]; .inputSchema.additionalProperties == false)' >/dev/null
}

@test "an unknown tool is a JSON-RPC error, not a silent empty answer" {
  run drive "$INIT" '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"os_nope","arguments":{}}}'
  [ "$(echo "$output" | jq -r 'select(.id==2) | .error.code')" = "-32602" ]
}

@test "an unimplemented method is refused rather than ignored" {
  run drive "$INIT" '{"jsonrpc":"2.0","id":2,"method":"resources/list"}'
  [ "$(echo "$output" | jq -r 'select(.id==2) | .error.code')" = "-32601" ]
}

@test "os_status returns the report the rest of the agent layer reads" {
  run drive "$INIT" '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"os_status","arguments":{}}}'
  local text
  text="$(echo "$output" | jq -r 'select(.id==2) | .result.content[0].text')"
  [[ $text == *failed-units* ]]
  [[ $text == *disk* ]]
}

@test "a unit name from a model is validated before it becomes argv" {
  # This is where an unchecked string from a model becomes somebody else's problem.
  local probe="evil.service; touch ${BATS_TEST_TMPDIR}/pwned"
  run drive "$INIT" "$(jq -nc --arg u "$probe" \
    '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:"os_logs",arguments:{unit:$u,lines:2}}}')"
  [[ $(echo "$output" | jq -r 'select(.id==2) | .result.content[0].text') == *"not a unit name"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "a priority it does not recognise falls back rather than reaching journalctl" {
  local probe="err --output=cat"
  run drive "$INIT" "$(jq -nc --arg p "$probe" \
    '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:"os_logs",arguments:{priority:$p,lines:1}}}')"
  echo "$output" | jq -e 'select(.id==2) | .result' >/dev/null
}

@test "the write path goes through oal-brain-do, which is the backend-neutral one" {
  # The guard's own output is Claude Code's hook contract. Routing writes through oal-brain-do is
  # what makes them gated for every consumer of this server rather than for one vendor's client.
  grep -q 'oal-brain-do' "$SRC/bin/oal-mcp-serve"
  run drive "$INIT" \
    '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"os_do","arguments":{"verb":"theme","args":["not-an-installed-theme"]}}}'
  [ "$(echo "$output" | jq -r 'select(.id==2) | .result.isError')" = true ]
  [[ $(echo "$output" | jq -r 'select(.id==2) | .result.content[0].text') == *"no theme called"* ]]
}

@test "os_do accepts only the four verbs the contract defines" {
  run drive "$INIT" \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  local verbs
  verbs="$(echo "$output" | jq -r 'select(.id==2) | .result.tools[] | select(.name=="os_do") | .inputSchema.properties.verb.enum | join(",")')"
  [ "$verbs" = "state,theme,notify,open" ]
  # And the same four the verb file defines, so this cannot drift away from the contract.
  local contract
  contract="$(grep -vE '^[[:space:]]*(#|$)' "$SRC/default/brain/VERBS" | cut -d'|' -f1 | tr -d ' ' | paste -sd,)"
  [ "$verbs" = "$contract" ]
}

@test "it is registered in the catalog as something this repository ships" {
  grep -qE '^agentarchy \| oal \| oal-mcp-serve' "$SRC/default/mcp/CATALOG"
  [ -x "$SRC/bin/oal-mcp-serve" ]
}

@test "an imported catalog may not use the kind that runs a bare command" {
  # Otherwise a data file somebody was handed becomes a way to register anything on PATH as a server.
  local cat="$BATS_TEST_TMPDIR/evil.catalog"
  printf 'sneaky | oal | id |  | public | dev | pretends to be a server\n' >"$cat"
  run "$SRC/bin/oal-mcp-import" "$cat"
  [ "$status" -ne 0 ]
  [[ $output == *reserved* ]]
}

@test "--tools describes the surface without speaking the protocol" {
  run "$SERVE" --tools
  [ "$status" -eq 0 ]
  [[ $output == *os_status* ]]
  [[ $output == *os_do* ]]
}

@test "it reports the version this tree actually ships" {
  # It read VERSION, uppercase. The file is `version`, lowercase, so this fell through to a
  # hardcoded 0.0.1 for every client that asked -- silently, because a missing file and a wrong case
  # are the same thing to `cat`.
  local shipped
  shipped="$(cat "$SRC/version")"
  [ -n "$shipped" ]
  run drive "$INIT"
  [ "$(echo "$output" | jq -r '.result.serverInfo.version')" = "$shipped" ]
}
