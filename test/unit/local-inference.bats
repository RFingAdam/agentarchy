#!/usr/bin/env bats
#
# Local inference. This is the backend that makes "agent-first operating system" true with no
# network, no account and no bill -- and the clearest evidence the brain contract is not a bet on one
# vendor, since it shares nothing with Hermes or Claude Code but four subcommands.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  ADAPTER="$SRC/default/brain/adapters/local"
}

@test "it is a fourth backend answering the same contract as the others" {
  # The point of the contract: a new backend is a file, not a rewrite.
  run "$ADAPTER" describe
  [ "$status" -eq 0 ]
  [ "$(wc -l <<<"$output")" -eq 1 ]
  run "$ADAPTER" not-a-subcommand
  [ "$status" -ne 0 ]
}

# Greps here are scoped to code rather than the whole file. This adapter's header explains at length
# why keep_alive and num_predict exist, so a grep for either matches the explanation whether or not
# the setting was ever wired up -- which is a test that passes on the comment describing the bug.
code() { grep -v '^[[:space:]]*#' "$1"; }

@test "probe needs a model, not just an install" {
  # Installed, serving, and holding a model are three different things. Two of them is a brain that
  # cannot answer, and reporting that as reachable puts a lie on the panel.
  code "$ADAPTER" | grep -q 'serving || exit 1'
  code "$ADAPTER" | grep -q '\[\[ -n "$(model)" \]\] || exit 1'
}

@test "generation is capped, so a small model answers instead of rambling" {
  # Nothing capped the answer in the first version, which is most of why a one-sentence answer took
  # 33 seconds warm on a 1.5B model.
  code "$ADAPTER" | grep -q 'num_predict'
  code "$ADAPTER" | grep -q 'num_predict:\$predict'
}

@test "the model is kept loaded between questions" {
  # ollama unloads after five minutes by default, so on a desktop every question paid a full model
  # load. That was most of the 65-second cold figure.
  code "$ADAPTER" | grep -q 'keep_alive'
  code "$ADAPTER" | grep -qE 'OAL_LOCAL_KEEP_ALIVE:-[0-9]+[ms]'
}

@test "there is a system prompt, which the CLI had no way to pass" {
  code "$ADAPTER" | grep -q 'SYSTEM_PROMPT'
  code "$ADAPTER" | grep -q 'system:\$system'
}

@test "the request is built by jq, not by string interpolation" {
  # A prompt is full of quotes and newlines. Pasting one into a JSON body by hand is where those
  # become somebody else's bug, which is the same reason the contract puts prompts on stdin.
  code "$ADAPTER" | grep -q 'jq -nc'
  ! code "$ADAPTER" | grep -qE '\{"model": *"\$'
}

@test "the HTTP API replaced the CLI, and the escape-stripping went with it" {
  # `ollama run` draws a spinner and rewrites the line as it streams. Those codes were invisible in
  # a terminal and garbage in a notification. The API does not emit them, so the sed that removed
  # them is gone rather than kept as decoration.
  code "$ADAPTER" | grep -q 'api/generate'
  ! code "$ADAPTER" | grep -q "sed -e 's/.x1b"
  # `ollama run` survives for exactly one job: the interactive REPL, which has no HTTP equivalent.
  # One occurrence, and it is an exec rather than a way of asking a question.
  [ "$(code "$ADAPTER" | grep -c 'ollama run')" -eq 1 ]
  code "$ADAPTER" | grep -q 'exec ollama run'
}

@test "it answers the interactive subcommand, and says so in its usage" {
  run "$ADAPTER" interactive --check
  # Either supported (0) or honestly unsupported (1); what must not happen is a usage error.
  [ "$status" -le 1 ]
  run "$ADAPTER" not-a-subcommand
  [[ $output == *interactive* ]]
}

@test "no model ships, and the command to get one is named" {
  # Models are gigabytes. Choosing one for somebody is a worse default than telling them how.
  ! grep -qE '^ollama pull' "$SRC/install/agent/local-inference.sh"
  grep -q 'ollama pull qwen2.5:1.5b' "$SRC/install/agent/local-inference.sh"
}

@test "the CPU build ships and CUDA is a hardware decision" {
  # A virtio GPU is for graphics and cannot do inference. Installing a CUDA build in a VM would imply
  # an acceleration that silently is not there.
  local pkgs="$SRC/install/agentarchy-desktop.packages"
  grep -qx 'ollama' "$pkgs"
  ! grep -qx 'ollama-cuda' "$pkgs"
  grep -q 'ollama-cuda' "$SRC/install/agent/local-inference.sh"
  grep -q 'nvidia' "$SRC/install/agent/local-inference.sh"
}

@test "ollama is a system service, not one per login" {
  # A model is a machine-wide resource; two logins loading two copies is how a laptop runs out of
  # memory. The brain's own unit does not supervise it either -- that would be two things restarting
  # one process.
  grep -q 'systemctl enable --now ollama.service' "$SRC/install/agent/local-inference.sh"
  grep -A3 '^  serve)' "$ADAPTER" | grep -q 'exit 1'
}

@test "the install runs it" {
  grep -q 'install/agent/local-inference.sh' "$SRC/oal-bootstrap.sh"
}
