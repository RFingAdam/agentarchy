#!/usr/bin/env bash
# Install the coding-agent runtime and the timer that keeps the prompt's agent line fed.
#
# Runs as the user out of oal-provision-user, not as root: the runtime installs into the home
# directory and self-updates, which is why it is not a package in install/agentarchy-*.packages.
# Pinning a self-updating tool in a distribution package list means shipping a version that is stale
# on the day it is built.
#
# Deliberately non-fatal. An agent-first system that ships without the agent is a contradiction, but
# an install must not fail because someone else's install script is having a bad afternoon. On
# failure this says so and the rest of the install continues; `oal-agent-setup` re-runs it later.
set -uo pipefail

log() { printf 'oal: %s\n' "$*"; }

if [[ ${OAL_SKIP_AGENT:-0} == 1 ]]; then
  log "OAL_SKIP_AGENT=1, skipping the agent runtime"
  exit 0
fi

if command -v claude >/dev/null; then
  log "agent runtime already present ($(command -v claude))"
else
  log "installing the agent runtime"
  if ! curl -fsSL --retry 3 --max-time 300 https://claude.ai/install.sh | bash; then
    log "warning: the agent runtime did not install. Everything else is fine; re-run with"
    log "         'bash \$OAL_PATH/install/agent/runtime.sh' when the network is happier."
    # Deliberately not an exit. Everything below this point is ours -- the permission posture, the
    # tool-call guard, the timer feeding the prompt -- and none of it depends on a third party's
    # install script having a good afternoon. Bailing here left a machine with the guard shipped and
    # never registered, which is the one failure mode a guard must not have.
  fi
fi

# The permission posture. Default scoped, and only if the user has not already chosen.
if command -v oal-agent-profile >/dev/null; then
  state="${XDG_STATE_HOME:-$HOME/.local/state}/oal/agent-profile"
  [[ -f $state ]] || oal-agent-profile scoped >/dev/null || true
fi

# The guard that classifies every tool call. Registered in settings.json rather than assumed: the
# agent only runs a hook it has been told about, and a guard nobody wired up is worse than none
# because it looks installed.
settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
guard="${OAL_PATH:-/usr/share/agentarchy}/agent/hooks/pretooluse-guard"
if [[ -x $guard ]] && command -v jq >/dev/null; then
  mkdir -p -- "$(dirname "$settings")"
  [[ -f $settings ]] || printf '{}\n' >"$settings"
  hook_tmp="$(mktemp)"
  if jq --arg g "$guard" \
      '.hooks.PreToolUse = [{matcher: "*", hooks: [{type: "command", command: $g}]}]' \
      "$settings" >"$hook_tmp" 2>/dev/null; then
    mv -- "$hook_tmp" "$settings"
    log "tool-call guard registered ($guard)"
  else
    rm -f -- "$hook_tmp"
    log "warning: could not register the tool-call guard in $settings"
  fi
else
  log "warning: tool-call guard not registered (needs jq and $guard)"
fi

# The prompt's agent line reads a cached file and never the network. Something has to fill it, and a
# user timer is the right something: it survives logout, it does not run when the machine is asleep,
# and if it fails the prompt just prints nothing.
units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p -- "$units"

cat >"$units/oal-agent-hud.service" <<'UNIT'
[Unit]
Description=Refresh the cached agent state the shell prompt reads

[Service]
Type=oneshot
ExecStart=/usr/bin/oal-agent-hud --refresh
UNIT

cat >"$units/oal-agent-hud.timer" <<'UNIT'
[Unit]
Description=Refresh the cached agent state every few minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
UNIT

# Report interrupted tasks at login. Enabled, unlike oal-brain.service: this one reads a journal and
# says what it found. It starts nothing and resumes nothing, so there is no decision to hand over.
systemctl --user enable oal-brain-sweep.service 2>/dev/null ||
  log "note: enable it later with 'systemctl --user enable oal-brain-sweep.service'"

if systemctl --user daemon-reload 2>/dev/null && systemctl --user enable --now oal-agent-hud.timer 2>/dev/null; then
  log "agent state timer enabled"
else
  # Normal during a chroot install: there is no user bus to talk to yet.
  log "agent state timer written; enable it after first login with 'systemctl --user enable --now oal-agent-hud.timer'"
fi
