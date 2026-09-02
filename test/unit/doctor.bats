#!/usr/bin/env bats
#
# oal-doctor: the machine describing itself.
#
# The rule this file exists to hold is the one the tool-call guard already follows: a check that
# could not run must report `unknown`, never `ok`. A false pass is indistinguishable from a real one,
# and the whole report is worthless the moment one of them is a lie.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  DOCTOR="$SRC/bin/oal-doctor"
}

code() { grep -v '^[[:space:]]*#' "$1"; }

@test "the JSON is valid and carries the documented shape" {
  run "$DOCTOR" --json
  # 0, 1 and 2 are all findings. Only a crash is a failure.
  [ "$status" -le 2 ]
  echo "$output" | jq -e . >/dev/null
  echo "$output" | jq -e 'has("ok") and has("severity") and has("checks")' >/dev/null
  echo "$output" | jq -e '.checks | length > 0' >/dev/null
}

@test "every check has an id, a severity and a summary" {
  run "$DOCTOR" --json
  echo "$output" | jq -e 'all(.checks[]; has("id") and has("severity") and has("summary"))' >/dev/null
}

@test "every severity is one of the four, and no others are invented" {
  run "$DOCTOR" --json
  echo "$output" | jq -e 'all(.checks[]; .severity | IN("ok","warn","problem","unknown"))' >/dev/null
}

@test "check ids are unique, because oal-watch and oal-agent-diagnose address them by id" {
  run "$DOCTOR" --json
  echo "$output" | jq -e '(.checks | length) == ([.checks[].id] | unique | length)' >/dev/null
}

@test "the exit code is the worst severity found" {
  run "$DOCTOR" --json
  local worst
  worst="$(echo "$output" | jq -r '.severity')"
  case "$worst" in
    ok)      [ "$status" -eq 0 ] ;;
    warn)    [ "$status" -eq 1 ] ;;
    problem) [ "$status" -eq 2 ] ;;
    *)       false ;;
  esac
}

@test "ok is true only when nothing was found" {
  run "$DOCTOR" --json
  local ok worst
  ok="$(echo "$output" | jq -r '.ok')"
  worst="$(echo "$output" | jq -r '.severity')"
  if [ "$worst" = ok ]; then [ "$ok" = true ]; else [ "$ok" = false ]; fi
}

@test "a check that could not run says unknown rather than ok" {
  # The rule, exercised deterministically rather than by hoping the host lacks something.
  #
  # It used to skip when pacman was present and otherwise assert the three package checks were
  # unknown. That stopped working the day oal-doctor learned apt: on Ubuntu those checks now return
  # real answers, which is the improvement, and the test was asserting the absence of it.
  #
  # So: a PATH with the essentials and no package manager at all. Then they genuinely cannot run,
  # on any host, and must say so.
  local bare="$BATS_TEST_TMPDIR/bare"
  mkdir -p "$bare"
  local c p
  for c in bash env cat grep sed awk find df date printf readlink dirname basename sort head tail \
           wc tr cut stat uname systemctl journalctl timeout jq id sleep mkdir ls; do
    p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$bare/$c"
  done
  run env PATH="$bare" "$DOCTOR" --json
  [ "$status" -le 2 ]
  echo "$output" | jq -e . >/dev/null
  local id sev
  for id in updates orphans pacnew; do
    sev="$(echo "$output" | jq -r --arg id "$id" '.checks[] | select(.id == $id) | .severity')"
    [ "$sev" = unknown ] || { echo "$id said '$sev' with no package manager on PATH"; false; }
  done
  # And it says why, rather than leaving a bare verdict.
  [[ $(echo "$output" | jq -r '.checks[] | select(.id=="updates") | .summary') == *"package manager"* ]]
}

@test "a search that found nothing is not the same as a search that could not run" {
  # `journalctl -g` exits 1 when nothing matches, which for OOM kills is the common and happy case.
  # Treating that exit as failure reported a healthy machine as unreadable: the report's own rule
  # inverted, claiming ignorance where the honest answer was available and good.
  if ! journalctl -k -b -n 1 -q >/dev/null 2>&1; then
    skip "the kernel journal is not readable here, which is the case that should say unknown"
  fi
  run "$DOCTOR" --json
  local sev
  sev="$(echo "$output" | jq -r '.checks[] | select(.id == "oom") | .severity')"
  [ "$sev" != unknown ] || { echo "oom said unknown on a machine whose kernel journal reads fine"; false; }
}

@test "nothing it runs can block forever" {
  # The report is read on a timer, injected into prompts and called from a notification path. A
  # single unbounded command makes all three hang.
  local externals
  externals="$(code "$DOCTOR" | grep -cE '\$\(run [0-9]+ ')"
  [ "$externals" -ge 8 ]
  # Every `run` helper call passes a timeout as its first argument.
  ! code "$DOCTOR" | grep -qE '\brun [^0-9"$]'
}

@test "it reaches for the sync database on disk, never the network" {
  # checkupdates downloads a fresh database. A health report that waits on a mirror is one that
  # hangs on a train, and "as of your last sync" is the honest answer available instantly.
  code "$DOCTOR" | grep -q 'pacman -Qu'
  ! code "$DOCTOR" | grep -q 'checkupdates'
}

@test "it does not wake a sleeping GPU to describe it" {
  # bin/oal-hw-nvidia established this: lspci reads PCI config space and resumes runtime-suspended
  # cards, so asking a laptop what graphics it has would cost battery to answer.
  ! code "$DOCTOR" | grep -q 'lspci'
  code "$DOCTOR" | grep -q 'OAL_PCI_DEVICES_PATH'
}

@test "a read-only filesystem is not reported as a full disk" {
  # An ISO is 100% full by definition. A plugged-in install stick reported as a problem is the kind
  # of false alarm that teaches people to skim past the real one.
  code "$DOCTOR" | grep -q 'iso9660'
  code "$DOCTOR" | grep -q '/proc/mounts'
}

@test "--quiet says nothing and still answers with its exit code" {
  run "$DOCTOR" --quiet
  [ "$status" -le 2 ]
  [ -z "$output" ]
}

@test "an unknown option is refused rather than ignored" {
  run "$DOCTOR" --not-an-option
  [ "$status" -eq 64 ]
}
