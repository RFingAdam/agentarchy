oal_log_to_stdout() {
  [[ ${OAL_LOG_TO_STDOUT:-} == "1" || -z ${OAL_INSTALL_LOG_FILE:-} ]]
}

oal_log_line() {
  if oal_log_to_stdout; then
    echo "$1"
  else
    echo "$1" >>"$OAL_INSTALL_LOG_FILE"
  fi
}

start_install_log() {
  if ! oal_log_to_stdout; then
    mkdir -p "$(dirname "$OAL_INSTALL_LOG_FILE")"
    touch "$OAL_INSTALL_LOG_FILE"
    chmod 666 "$OAL_INSTALL_LOG_FILE" 2>/dev/null || true
  fi

  export OAL_START_TIME="${OAL_START_TIME:-$(date '+%Y-%m-%d %H:%M:%S')}"
  export OAL_START_EPOCH="${OAL_START_EPOCH:-$(date +%s)}"

  oal_log_line "=== Agentarchy Setup Started: $OAL_START_TIME ==="
}

stop_install_log() {
  local end_time end_epoch duration mins secs
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)

  oal_log_line "=== Agentarchy Setup Completed: $end_time ==="

  if [[ -n ${OAL_START_EPOCH:-} ]]; then
    duration=$((end_epoch - OAL_START_EPOCH))
    mins=$((duration / 60))
    secs=$((duration % 60))
    oal_log_line "Agentarchy setup: ${mins}m ${secs}s"
  fi
}

run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0

  oal_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  local runner=(bash -eE)
  if [[ ${OAL_INSTALL_DEBUG:-} == "1" ]]; then
    runner=(bash -x -eE)
  fi

  if oal_log_to_stdout; then
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1
  else
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$OAL_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    oal_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    oal_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi

  return $exit_code
}
