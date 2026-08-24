#!/usr/bin/env bats
#
# oal-dev-gitleaks-worktree is the pre-commit half of the secret gate: it looks at files on disk,
# because a secret is permanent once it is in history. Its contract is that it scans the set of
# files that can reach a commit and nothing else -- not the filesystem. That distinction is not
# cosmetic: gitignored scratch in this repo means multi-gigabyte VM disks, and scanning those reads
# them into memory.
#
# The cases below plant a token matched by a rule this file writes, not by gitleaks' default rules.
# Which strings a given gitleaks build recognises is its business and drifts between versions (the
# AWS example key these cases first used is flagged locally and ignored by 8.21.2 in CI); which
# files it is handed is ours, and that is what is under test.

setup() {
  command -v gitleaks >/dev/null || skip "gitleaks is not installed"
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # A standalone repo, so a case can leave a "secret" lying around without touching the real tree.
  # It needs upstream/PIN -- that is how oal_dev_root finds a root -- and a copy of the two scripts.
  SCRATCH="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$SCRATCH/bin" "$SCRATCH/upstream"
  cp "$REPO/bin/oal-dev-lib.sh" "$REPO/bin/oal-dev-gitleaks-worktree" "$SCRATCH/bin/"
  echo 0000000000000000000000000000000000000000 >"$SCRATCH/upstream/PIN"
  cat >"$SCRATCH/.gitleaks.toml" <<'TOML'
[[rules]]
id = "oal-planted-token"
description = "the token test/unit/gitleaks-worktree.bats plants; nothing real has this shape"
regex = '''OAL_PLANTED_TOKEN_[A-Z0-9]{10}'''
TOML

  git -C "$SCRATCH" init -q
  git -C "$SCRATCH" config user.email oal@example.invalid
  git -C "$SCRATCH" config user.name oal
  git -C "$SCRATCH" add -A
  git -C "$SCRATCH" commit -qm base

  leak() { printf 'token = %s%s\n' OAL_PLANTED_TOKEN_ 9XQ2VBN4KD >"$1"; }
  gate() { (cd "$SCRATCH" && bin/oal-dev-gitleaks-worktree "$@"); }
}

@test "a secret in an untracked file fails the gate" {
  leak "$SCRATCH/creds.env"
  run gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"leaks found"* ]]
}

@test "a secret in a tracked file fails the gate" {
  leak "$SCRATCH/creds.env"
  git -C "$SCRATCH" add creds.env
  run gate
  [ "$status" -ne 0 ]
}

@test "a gitignored file is not the worktree gate's business" {
  # The regression this script exists for. Nothing under a gitignored path can reach a commit, so
  # scanning it buys nothing -- and it is where the qcow2 disks live.
  echo 'scratch/' >"$SCRATCH/.gitignore"
  mkdir -p "$SCRATCH/scratch"
  leak "$SCRATCH/scratch/creds.env"
  run gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"no leaks found"* ]]
}

@test "a clean tree passes" {
  echo 'nothing to see' >"$SCRATCH/notes.txt"
  run gate
  [ "$status" -eq 0 ]
}

@test "a tracked file deleted in the working tree does not abort the gate" {
  echo hello >"$SCRATCH/doomed.txt"
  git -C "$SCRATCH" add doomed.txt
  git -C "$SCRATCH" commit -qm add-doomed
  rm "$SCRATCH/doomed.txt"
  run gate
  [ "$status" -eq 0 ]
}

@test "extra arguments reach gitleaks" {
  run gate --exit-code 7
  [ "$status" -eq 0 ]
  leak "$SCRATCH/creds.env"
  run gate --exit-code 7
  [ "$status" -eq 7 ]
}
