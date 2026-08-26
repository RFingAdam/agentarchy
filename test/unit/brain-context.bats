#!/usr/bin/env bats
#
# Grounding. "Are there any OS issues?" used to reach the model as exactly those five words, and the
# model answered from what it knew about operating systems in general because that was all it had.
# These tests hold the fix: a question about this machine arrives with this machine's state attached.
#
# The stub backend is used throughout. It echoes the prompt it was given, so what the model would
# have received is directly observable without a model, an account or a network.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$XDG_STATE_HOME/oal/brain"
  echo stub >"$XDG_STATE_HOME/oal/brain/backend"
  # shellcheck source=default/brain/lib.sh
  source "$SRC/default/brain/lib.sh"
}

@test "a question about this machine is recognised" {
  for q in \
    "are there any OS issues?" \
    "why is my machine slow" \
    "is the disk full" \
    "did anything crash" \
    "what failed at boot" \
    "are there updates pending" \
    "何 is wrong with this computer"
  do
    brain_question_is_local "$q" || { echo "missed: $q"; false; }
  done
}

@test "a general question is not" {
  # Attaching facts to a general question wastes context, and on a small model actively crowds out
  # the answer. Being conservative here matters as much as catching the local ones.
  for q in \
    "who wrote Hamlet" \
    "translate good morning into Welsh" \
    "what is the capital of Peru" \
    "write me a haiku about rain"
  do
    ! brain_question_is_local "$q" || { echo "false positive: $q"; false; }
  done
}

@test "the match is case-insensitive" {
  brain_question_is_local "Any DISK problems?"
}

@test "it matches whole words, not fragments" {
  # 'os' inside 'across' or 'those' would ground half of every general question asked.
  ! brain_question_is_local "tell me about those across the bay"
}

@test "the context carries machine state and health, and is not JSON" {
  run brain_context
  [ "$status" -eq 0 ]
  [[ $output == *"host:"* ]]
  [[ $output == *"health"* ]]
  # Plain lines for the same reason oal-brain-state uses them: a model parses both equally, and only
  # one is readable by the person working out why it answered what it did.
  ! echo "$output" | jq -e . >/dev/null 2>&1
}

@test "passing checks are summarised too, so a question about them can be answered" {
  # Dropping them saved context and cost the answer: asked "is my disk full?" on a machine with a
  # healthy disk, the model correctly said it had not been told, which is worse than useless because
  # the machine knew.
  run brain_context
  [ "$(grep -c '^ok ' <<<"$output" || true)" -gt 0 ]
}

@test "but only findings carry their evidence, and it is trimmed" {
  # The summaries are cheap. Five untruncated journal lines are most of a small model's context.
  run brain_context
  local longest
  longest="$(awk '{ print length }' <<<"$output" | sort -rn | head -1)"
  [ "$longest" -le 130 ]
  # Detail is indented; a passing check must never bring any.
  ! grep -A1 '^ok ' <<<"$output" | grep -qE '^ +[^ ]'
}

@test "the whole context stays small enough for a small model to answer around it" {
  run brain_context
  [ "$(wc -w <<<"$output")" -lt 400 ]
}

@test "the question comes last, after the facts and the instruction" {
  run brain_ground "host: testbox" "is the disk full"
  [ "$status" -eq 0 ]
  local facts_at instruction_at question_at
  facts_at="$(grep -n 'host: testbox' <<<"$output" | cut -d: -f1)"
  instruction_at="$(grep -n 'Answer the question' <<<"$output" | cut -d: -f1)"
  question_at="$(grep -n '^Question:' <<<"$output" | cut -d: -f1)"
  [ "$facts_at" -lt "$instruction_at" ]
  [ "$instruction_at" -lt "$question_at" ]
}

@test "a machine question reaches the backend with the facts attached" {
  run oal-brain-ask "is the disk full?"
  [ "$status" -eq 0 ]
  [[ $output == *"facts about the machine"* ]]
  [[ $output == *"is the disk full?"* ]]
}

@test "a general question reaches the backend untouched" {
  run oal-brain-ask "who wrote Hamlet?"
  [ "$status" -eq 0 ]
  [ "$output" = "stub: who wrote Hamlet?" ]
}

@test "--no-context overrides the routing" {
  run oal-brain-ask --no-context "is the disk full?"
  [ "$status" -eq 0 ]
  [ "$output" = "stub: is the disk full?" ]
}

@test "--context grounds a question that would not have been" {
  run oal-brain-ask --context "who wrote Hamlet?"
  [ "$status" -eq 0 ]
  [[ $output == *"facts about the machine"* ]]
}

@test "everything after -- is the question, even when it starts with a dash" {
  # oal-agent depends on this: a prompt it forwards may begin with anything at all.
  run oal-brain-ask --no-context -- "--not-an-option really"
  [ "$status" -eq 0 ]
  [[ $output == *"--not-an-option really"* ]]
}

@test "an unknown option is refused rather than sent to the model as a question" {
  run oal-brain-ask --not-an-option
  [ "$status" -ne 0 ]
  [[ $output == *"unknown option"* ]]
}

@test "an empty question is refused" {
  run oal-brain-ask --no-context "   "
  [ "$status" -ne 0 ]
}

@test "a prompt still arrives on stdin, never in argv" {
  # The contract's own rule. A question is full of quotes and newlines and argv is where those turn
  # into somebody else's bug.
  grep -q 'printf .%s\\n. "$prompt" | "$adapter" ask' "$SRC/bin/oal-brain-ask"
}
