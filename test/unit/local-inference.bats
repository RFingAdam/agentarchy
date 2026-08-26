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

@test "probe needs a model, not just an install" {
  # Installed, serving, and holding a model are three different things. Two of them is a brain that
  # cannot answer, and reporting that as reachable puts a lie on the panel.
  grep -q 'ollama list >/dev/null' "$ADAPTER"
  grep -q '\[\[ -n "$(model)" \]\] || exit 1' "$ADAPTER"
}

@test "the streaming escapes are stripped, because the answer goes to a notification" {
  # ollama draws a spinner and rewrites the line as it streams. Those codes are invisible in a
  # terminal and garbage in a popup, which is where oal-ask puts the answer.
  grep -q "sed -e 's/.x1b" "$ADAPTER"
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
