#!/usr/bin/env bash
# The tool-call decision engine. Sourced, never executed.
#
# It takes a tool name and the text of a call, and answers allow / ask / deny against
# default/guard/rules and the active oal-agent-profile. It knows nothing about any particular agent,
# and this file names none: a policy file that mentions one runtime is a policy the next reader
# assumes applies only to that runtime. Which runtimes reach it, and how, is in docs/agent-guard.md.
#
# It lives here rather than under agent/ because that directory holds one vendor's documents and its
# hook, and keeping the rules beneath it implied the policy belonged to that vendor. It did not.
# Only the wiring did, which is the whole reason this split exists: with the decision logic, the
# rules and the audit log all inside a file shaped like one runtime's hook API, running any other
# agent on this machine meant nothing was gated at all.
#
# FAIL CLOSED. Every path that cannot reach a confident decision denies. A guard that allows when it
# is confused is not a guard: it is a guard-shaped thing that reports success while the one case it
# existed for goes straight through.
#
# The three tiers:
#   block    refused outright. No override token. Reserved for what has no legitimate agent use.
#   confirm  refused unless the call carries CONFIRM-<8 hex>, the convention the rest of this
#            toolchain already uses, so a person opts in per call rather than per session.
#   allow    permitted and recorded.
#
# Anything unmatched takes the default for the active oal-agent-profile: untrusted confirms, scoped
# and trusted allow. That is what makes the posture a machine setting rather than a file each
# runtime keeps its own copy of.

_guard_lib="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OAL_PATH="${OAL_PATH:-$(dirname "$(dirname "$_guard_lib")")}"

GUARD_STATE="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/oal"
GUARD_RULES="${GUARD_RULES:-$OAL_PATH/default/guard/rules}"
# One log, with the runtime named on each line. The question a person actually has is "what did
# anything on this machine try to do", and a log split per agent cannot answer it.
GUARD_AUDIT="$GUARD_STATE/audit"

# Exit codes, so a shell caller needs no parsing. Anything else means the engine itself failed, and
# a caller that sees an unexpected code must treat it as a refusal.
GUARD_ALLOW=0
GUARD_ASK=1
GUARD_DENY=2

guard_profile() {
  local profile=scoped
  [[ -r $GUARD_STATE/agent-profile ]] && read -r profile <"$GUARD_STATE/agent-profile"
  printf '%s' "$profile"
}

# guard_log <runtime> <decision> <tier> <tool> <reason> [pattern]
#
# The matched pattern goes in the log and never into a reason handed back to a runtime. Reasons get
# interpolated into JSON by at least one adapter, and the patterns are regexes full of backslashes:
# putting one in a reason produced output the runtime could not parse, which is a guard failing open
# in the most confusing way available. The log is tab-separated and has no such problem.
guard_log() {
  local runtime="$1" decision="$2" tier="$3" tool="$4" reason="$5" pattern="${6:-}" ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  mkdir -p -- "$GUARD_AUDIT" 2>/dev/null &&
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$ts" "$runtime" "$decision" "$tier" "$tool" "$reason" "$pattern" \
      >>"$GUARD_AUDIT/${ts:0:7}.log" 2>/dev/null
  return 0
}

# guard_decide <runtime> <tool> <input>
#
# Prints "<decision>\t<tier>\t<reason>" and returns GUARD_ALLOW / GUARD_ASK / GUARD_DENY.
# Logs every decision, including the allowed ones.
guard_decide() {
  local runtime="${1:-unknown}" tool="${2:-}" input="${3:-}"
  local profile tier rule_tool pattern has_token=0

  _answer() { # _answer <decision> <code> <tier> <reason> [pattern]
    guard_log "$runtime" "$1" "$3" "${tool:-unknown}" "$4" "${5:-}"
    printf '%s\t%s\t%s\n' "$1" "$3" "$4"
    return "$2"
  }

  [[ -r $GUARD_RULES ]] ||
    { _answer deny "$GUARD_DENY" fail-closed "rule set unreadable, so nothing can be classified"; return; }
  [[ -n $tool ]] ||
    { _answer deny "$GUARD_DENY" fail-closed "the call names no tool"; return; }

  profile="$(guard_profile)"
  case "$profile" in
    trusted | scoped | untrusted) ;;
    *) _answer deny "$GUARD_DENY" fail-closed "the configured agent profile is not one this guard knows"; return ;;
  esac

  # CONFIRM-<8 hex>, the token shape the rest of this toolchain already uses.
  [[ $input =~ CONFIRM-[0-9a-fA-F]{8} ]] && has_token=1

  while IFS='|' read -r tier rule_tool pattern; do
    tier="${tier//[[:space:]]/}"
    [[ -n $tier && $tier != \#* ]] || continue
    rule_tool="${rule_tool//[[:space:]]/}"
    # Trimmed with parameter expansion rather than sed: one fork per rule is twenty-two forks per
    # call, and this runs before everything the agent does.
    pattern="${pattern#"${pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"
    [[ -n $pattern ]] || continue
    [[ $rule_tool == "*" || $rule_tool == "$tool" ]] || continue
    # bash's own ERE, so no grep either.
    [[ $input =~ $pattern ]] || continue

    case "$tier" in
      block)
        _answer deny "$GUARD_DENY" block "refused by a block rule: this call cannot be taken back" "$pattern"
        return ;;
      confirm)
        if (( has_token )); then
          _answer allow "$GUARD_ALLOW" confirm-token "confirmed by token" "$pattern"; return
        fi
        if [[ $profile == trusted ]]; then
          _answer allow "$GUARD_ALLOW" confirm-trusted "allowed by the trusted profile" "$pattern"; return
        fi
        _answer ask "$GUARD_ASK" confirm "needs confirmation, or a CONFIRM-<8 hex> token in the call" "$pattern"
        return ;;
      allow)
        _answer allow "$GUARD_ALLOW" rule "allowed by rule" "$pattern"; return ;;
      *)
        _answer deny "$GUARD_DENY" fail-closed "the rule set contains a tier this guard does not know" "$tier"
        return ;;
    esac
  done < <(grep -v '^[[:space:]]*#' "$GUARD_RULES" | grep '|')

  if [[ $profile == untrusted ]]; then
    _answer ask "$GUARD_ASK" default-untrusted "the untrusted profile confirms every call no rule covers"
    return
  fi
  _answer allow "$GUARD_ALLOW" default "no rule matched"
}
