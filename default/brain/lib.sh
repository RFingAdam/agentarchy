#!/usr/bin/env bash
# Shared by the oal-brain-* commands. Sourced, never executed -- and it lives here rather than in
# bin/ because everything in bin/ is symlinked onto PATH, and a library on PATH is a command people
# will eventually run.

# From BASH_SOURCE[0] at source time, not BASH_SOURCE[1] at call time. Inside a function called by
# another function in this file, BASH_SOURCE[1] is this file, and the answer comes out wrong in a
# way that only shows up on the paths nobody tested.
_brain_lib="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OAL_PATH="${OAL_PATH:-$(dirname "$(dirname "$_brain_lib")")}"

BRAIN_STATE="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/oal/brain"
BRAIN_VERBS="$OAL_PATH/default/brain/VERBS"
# Read by oal-brain-do, which is the only caller that acts rather than reports.
# shellcheck disable=SC2034
BRAIN_GUARD="$OAL_PATH/agent/hooks/pretooluse-guard"

brain_fail() { echo "${BRAIN_CMD:-oal-brain}: $*" >&2; exit 1; }

# --- the backend ----------------------------------------------------------------------------------

# Prints the configured backend, or nothing. Nothing is a valid answer: no backend is configured by
# default, and every command here has to stay quiet and exit 0 in that state rather than nagging.
brain_backend() {
  local f="$BRAIN_STATE/backend"
  [[ -r $f ]] || return 0
  local name
  read -r name <"$f" 2>/dev/null || true
  printf '%s' "$name"
}

# Adapters are looked up in the user's directory first, so someone can point a backend at their own
# gateway without editing the packaged tree.
brain_adapter() {
  local name="${1:-}" d
  [[ -n $name ]] || return 1
  [[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 1
  for d in "${HOME:-}/.config/oal/brain/adapters" "$OAL_PATH/default/brain/adapters"; do
    [[ -x $d/$name ]] && { printf '%s' "$d/$name"; return 0; }
  done
  return 1
}

brain_adapters() {
  local d f
  for d in "$OAL_PATH/default/brain/adapters" "${HOME:-}/.config/oal/brain/adapters"; do
    [[ -d $d ]] || continue
    for f in "$d"/*; do [[ -x $f ]] && basename -- "$f"; done
  done | sort -u
}

# --- the verb set ---------------------------------------------------------------------------------

brain_verbs() {
  [[ -r $BRAIN_VERBS ]] || brain_fail "verb set unreadable at $BRAIN_VERBS"
  local line verb
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    IFS='|' read -r verb _ <<<"$line"
    printf '%s\n' "${verb// /}"
  done <"$BRAIN_VERBS"
}

brain_verb_known() {
  local want="${1:-}" v
  [[ -n $want ]] || return 1
  while read -r v; do [[ $v == "$want" ]] && return 0; done < <(brain_verbs)
  return 1
}

# --- the verbs ------------------------------------------------------------------------------------
#
# Each one validates its own arguments and prints the concrete argv, NUL-separated, or fails. The
# validation is the point. A verb table that only allowlisted command names would be a formality:
# `open` becomes `run anything` the first time someone hands it a path instead of an id.
#
# NUL-separated because a notification body legitimately contains newlines, and one-argument-per-line
# quietly turns that into two arguments.

brain_resolve_state() {
  (( $# == 0 )) || brain_fail "state takes no arguments"
  printf '%s\0' oal-brain-state
}

brain_resolve_theme() {
  (( $# == 1 )) || brain_fail "theme takes one theme name"
  [[ $1 =~ ^[a-z0-9][a-z0-9-]*$ ]] || brain_fail "not a theme name: $1"
  [[ -d "$OAL_PATH/themes/$1" || -d "${HOME:-}/.config/oal/themes/$1" ]] ||
    brain_fail "no theme called '$1' is installed"
  printf '%s\0' oal-theme-set "$1"
}

brain_resolve_notify() {
  (( $# >= 1 && $# <= 2 )) || brain_fail "notify takes a summary and an optional body"
  [[ -n $1 ]] || brain_fail "notify needs a summary"
  printf '%s\0' oal-notification-send "$@"
}

brain_resolve_open() {
  (( $# == 1 )) || brain_fail "open takes one desktop entry id"
  local id="${1%.desktop}" d entry=""
  [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || brain_fail "not a desktop entry id: $1"
  for d in "${HOME:-}/.local/share/applications" /usr/local/share/applications /usr/share/applications; do
    [[ -f "$d/$id.desktop" ]] && { entry="$d/$id.desktop"; break; }
  done
  [[ -n $entry ]] || brain_fail "no installed application with desktop entry id '$id'"
  # gio rather than gtk-launch: glib2 is always present on this desktop and gtk-launch is not.
  printf '%s\0' gio launch "$entry"
}

# --- long-running tasks ------------------------------------------------------------------------
#
# A question you wait for is oal-brain-ask. A job you walk away from is a task, and the difference
# that matters is what happens when the machine restarts underneath it.
#
# Nothing here resumes by itself. A task whose process is gone is marked `held` and said out loud,
# never restarted -- an agent that silently picks up where it thinks it left off can repeat side
# effects it already committed, and this system's whole posture is that irreversible things get
# confirmed. `oal-brain-resume` is a person deciding.

BRAIN_TASKS="$BRAIN_STATE/tasks"

# Sortable, readable, and unique without a counter to keep. Seconds plus the pid is enough: two
# tasks starting in the same second are two different shells.
brain_task_id() {
  local now
  printf -v now '%(%Y%m%d-%H%M%S)T' -1
  printf '%s-%s' "$now" "$$"
}

brain_task_dir() { printf '%s/%s' "$BRAIN_TASKS" "${1:?task id}"; }

# meta is one key=value per line: greppable, appendable, and readable when something has gone wrong
# and the tooling is what you are debugging.
# The LAST value wins. meta is append-only on purpose -- a worker that finishes appends its result
# rather than rewriting a file it might be killed halfway through -- so the newest line is the truth.
# Returning the first match instead made a finished task report as held: `state=running` from the
# moment it was created outvoted the `state=done` written when it succeeded.
brain_task_get() {
  local dir="$1" key="$2" line found="" hit=1
  [[ -r $dir/meta ]] || return 1
  while IFS= read -r line; do
    [[ $line == "$key="* ]] && { found="${line#*=}"; hit=0; }
  done <"$dir/meta"
  (( hit == 0 )) && printf '%s' "$found"
  return "$hit"
}

brain_task_set() {
  local dir="$1" key="$2" value="$3" tmp
  tmp="$dir/meta.new"
  { grep -v "^$key=" "$dir/meta" 2>/dev/null; printf '%s=%s\n' "$key" "$value"; } >"$tmp" &&
    mv -f "$tmp" "$dir/meta"
}

# The state a task is actually in, rather than the one it last wrote down. A task recorded as running
# whose process is gone did not finish -- the machine went away underneath it -- and that is `held`.
brain_task_state() {
  local dir="$1" state pid
  state="$(brain_task_get "$dir" state)" || return 1
  [[ $state == running ]] || { printf '%s' "$state"; return 0; }
  # A different boot means this pid cannot be the task's, whatever the pid table says now.
  local boot now_boot
  boot="$(brain_task_get "$dir" boot 2>/dev/null)"
  now_boot="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
  if [[ -n $boot && -n $now_boot && $boot != "$now_boot" ]]; then
    printf 'held'
    return 0
  fi

  pid="$(brain_task_get "$dir" pid)"
  if [[ -z $pid ]]; then
    # Recorded as running with no pid yet: the worker has not written it. Calling that `held` would
    # report every task as interrupted for the first instant of its life.
    printf 'starting'
  elif kill -0 "$pid" 2>/dev/null; then
    printf 'running'
  else
    printf 'held'
  fi
}

brain_task_ids() {
  [[ -d $BRAIN_TASKS ]] || return 0
  local d
  for d in "$BRAIN_TASKS"/*/; do
    [[ -f $d/meta ]] && basename -- "${d%/}"
  done | sort
}

# --- grounding ----------------------------------------------------------------------------------
#
# A question about this machine has to arrive at the model with the machine's actual state attached.
# Without it, "are there any OS issues?" is answered from whatever the model remembers about
# operating systems in general, which is how a 1.5B model came to explain that the term usually
# refers to Linux or Windows. A larger model fails the same way with better manners: it says it
# cannot see your system, which is true and equally useless.
#
# The routing is a keyword match rather than a model call. It is cheap, it is testable, and -- the
# part that matters -- a classifier that is itself a model can hallucinate, and then the grounding
# step becomes one more thing that can be wrong.

# Words that mean "this computer" rather than "computers". Deliberately conservative: attaching
# facts to a general question wastes context and, on a small model, actively crowds out the answer.
# Not readonly: bats sources this library more than once in a single shell, and a readonly
# reassignment is a hard error that would fail the suite rather than the code under test.
BRAIN_LOCAL_WORDS='os|system|machine|computer|laptop|desktop|disk|drive|storage|space|memory|ram|swap|cpu|gpu|graphics|nvidia|driver|network|wifi|internet|connection|offline|boot|systemd|service|unit|daemon|journal|log|logs|error|errors|crash|crashed|update|updates|package|packages|pacman|orphan|theme|battery|temperature|thermal|hot|overheat|fan|slow|broken|wrong|issue|issues|problem|problems|fail|failed|failing|health|wrong with|going on|status'

# True when the question is about the machine this is running on.
brain_question_is_local() {
  local q="${1,,}"
  [[ $q =~ (^|[^a-z])(${BRAIN_LOCAL_WORDS})([^a-z]|$) ]]
}

# What the machine can say about itself right now, as plain lines. Not JSON, for the same reason
# oal-brain-state is not JSON: both parse identically to a model, and only one of them is readable
# by the person working out why it answered what it did.
#
# Only the checks that are not `ok`. A small model has a few thousand tokens of context and thirteen
# lines of "everything is fine" is how the one line that mattered gets pushed out of it.
brain_context() {
  local state doctor
  state="$(timeout 10 oal-brain-state 2>/dev/null)" || state=""
  [[ -n $state ]] && printf '%s\n' "$state"

  doctor="$(timeout 30 oal-doctor 2>/dev/null)"
  # Exit 1 and 2 are findings, not failures. Only an empty result means the report did not run.
  if [[ -z $doctor ]]; then
    printf 'health: could not be determined\n'
    return 0
  fi
  # Every check's summary, but detail only for the ones that are not ok.
  #
  # The first version dropped passing checks entirely, to save context. Asked "is my disk full?" on
  # a machine with a healthy disk, the model correctly answered that it had not been told -- which
  # is worse than useless, because the machine knew. Thirteen one-line summaries cost about a
  # hundred words; it is the untruncated journal evidence that is expensive, and oal-doctor already
  # prints detail only for findings.
  local facts
  facts="$(printf '%s\n' "$doctor" |
    awk '
      /^[a-z]/ { check = 0; print; next }
      { if (++check > 2) next
        line = $0
        if (length(line) > 100) line = substr(line, 1, 100) "..."
        print line }
    ' || true)"
  if [[ -z ${facts//[[:space:]]/} ]]; then
    printf 'health: could not be determined\n'
  else
    printf 'health checks (severity, check, finding):\n%s\n' "$facts"
  fi
}

# The facts, then the instruction, then the question. The instruction sits between them so that a
# model which truncates from the front loses facts rather than its orders, and the question is last
# because that is the position every instruct model attends to hardest.
brain_ground() {
  local facts="$1" question="$2"
  cat <<GROUNDED
These are facts about the machine you are running on, gathered a moment ago:

$facts

Answer the question using these facts. They are the only information you have about this machine --
if they do not contain the answer, say so plainly rather than guessing. Be brief.

Question: $question
GROUNDED
}
