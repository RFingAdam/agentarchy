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
