#!/usr/bin/env bash
# Install the agent layer on any systemd Linux, without the desktop.
#
#   curl -fsSLO https://raw.githubusercontent.com/RFingAdam/agentarchy/main/install/agent-layer.sh
#   less agent-layer.sh
#   bash agent-layer.sh
#
# oal-bootstrap.sh turns a vanilla Arch box into Agentarchy: packages, Plasma, themes, greeter, the
# lot. This installs only the part that is not about Arch or KDE -- the health report, the tool-call
# guard, the brain contract, the MCP server, the watcher -- onto Debian, Ubuntu, Fedora, openSUSE or
# Arch alike.
#
# It exists because the honest measurement said it should: 32 of 344 commands touch pacman and 5
# touch KDE. The agent layer was already portable and nothing shipped it that way, so the only route
# to trying the idea was reinstalling your operating system, which is a lot to ask of somebody who
# has not yet seen it work.
#
# Nothing here needs the desktop. oal-watch and oal-ask want a session to put a notification on, and
# say so rather than failing, in the same way every other optional surface here does.
set -euo pipefail

PREFIX="${OAL_PREFIX:-/usr/local}"
SHARE="$PREFIX/share/agentarchy"
BINDIR="$PREFIX/bin"
REPO_URL="https://github.com/RFingAdam/agentarchy"

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mnote:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

(( EUID != 0 )) || die "run this as your normal user, not root: the user steps need your home directory"
command -v sudo >/dev/null || die "sudo is required and was not found"

# --- what the agent layer is ----------------------------------------------------------------------
#
# Named explicitly rather than "everything that does not mention pacman". A list a person can read is
# a list a person can argue with, and test/unit/agent-layer.bats checks that every command in it can
# resolve the oal-* commands it calls from within this same set.
LAYER_BIN=(
  oal-doctor oal-guard oal-guard-confirm
  oal-agent oal-agent-diagnose oal-agent-profile oal-agent-hud
  oal-ask oal-watch oal-toggle-health-watch oal-run-in-terminal
  oal-notification-send oal-notification-wait
  oal-brain-ask oal-brain-backend oal-brain-do oal-brain-model oal-brain-notify
  oal-brain-run oal-brain-resume oal-brain-serve oal-brain-show oal-brain-state
  oal-brain-status oal-brain-sweep oal-brain-tasks
  oal-agent-usage-claude
  oal-mcp-doctor oal-mcp-import oal-mcp-install oal-mcp-list oal-mcp-remove
  oal-mcp-serve oal-mcp-status
  oal-cmd-present oal-cmd-missing oal-done oal-state oal-version
)
LAYER_TREE=(agent default/guard default/brain default/mcp default/agents)

# Called from inside the layer, deliberately left out, and harmless when absent. Each caller already
# tolerates the gap because it had to: these are optional surfaces on Agentarchy too.
#
#   oal-hermes-status, oal-hermes-waiting   the fleet panel. oal-agent-hud runs them under `timeout
#                                           ... || true` and simply shows fewer fields.
#   oal-theme-current                       there is no Agentarchy theme on a machine that only has
#                                           the layer, so oal-brain-state reports `theme: unknown`,
#                                           which is the truth.
#
# test/unit/agent-layer.bats holds this list to exactly these three: anything else calling out of
# the layer is a command that will not work once installed, and the whole point of naming the set is
# that it can be checked.
# shellcheck disable=SC2034  # read by test/unit/agent-layer.bats, not by this script
LAYER_OPTIONAL=(oal-hermes-status oal-hermes-waiting oal-theme-current)

# --- where the source is --------------------------------------------------------------------------
resolve_checkout() {
  local self="${BASH_SOURCE[0]:-}" dir
  if [[ -n $self && -f $self ]]; then
    dir="$(cd -- "$(dirname -- "$self")/.." && pwd)"
    [[ -f $dir/PKGBUILD ]] && { printf '%s' "$dir"; return 0; }
  fi
  local co="${OAL_CHECKOUT:-$HOME/.local/share/oal/checkout}"
  if [[ -d $co/.git ]]; then
    git -C "$co" fetch --quiet origin "${OAL_REF:-main}" 2>/dev/null || true
    git -C "$co" checkout --quiet --detach "origin/${OAL_REF:-main}" 2>/dev/null ||
      git -C "$co" checkout --quiet "${OAL_REF:-main}"
  else
    mkdir -p -- "$(dirname -- "$co")"
    git clone --quiet --depth 1 --branch "${OAL_REF:-main}" "$REPO_URL" "$co"
  fi
  printf '%s' "$co"
}

# --- dependencies, whatever the distro ------------------------------------------------------------
install_deps() {
  local missing=()
  for c in jq curl git; do command -v "$c" >/dev/null || missing+=("$c"); done
  (( ${#missing[@]} )) || { log "dependencies already present"; return 0; }
  log "installing ${missing[*]}"
  if   command -v apt-get >/dev/null; then sudo apt-get update -qq && sudo apt-get install -y "${missing[@]}"
  elif command -v dnf     >/dev/null; then sudo dnf install -y "${missing[@]}"
  elif command -v pacman  >/dev/null; then sudo pacman -S --needed --noconfirm "${missing[@]}"
  elif command -v zypper  >/dev/null; then sudo zypper --non-interactive install "${missing[@]}"
  else die "no package manager I know; install these yourself and re-run: ${missing[*]}"
  fi
}

uninstall() {
  log "removing the agent layer"
  local c
  for c in "${LAYER_BIN[@]}"; do
    [[ -L $BINDIR/$c ]] && sudo rm -f -- "$BINDIR/$c"
  done
  sudo rm -rf -- "$SHARE"
  systemctl --user disable --now oal-watch.timer 2>/dev/null || true
  rm -f -- "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/oal-watch."{service,timer}
  systemctl --user daemon-reload 2>/dev/null || true
  # State is deliberately left alone: the audit log is a record, and removing software is not a
  # reason to destroy the evidence of what it decided.
  echo "removed. ~/.local/state/oal is left in place, audit log included."
}

[[ ${1:-} == --uninstall ]] && { uninstall; exit 0; }

src="$(resolve_checkout)"
[[ -d $src/bin ]] || die "no source tree at $src"
install_deps

log "installing to $SHARE"
sudo install -d "$SHARE/bin" "$BINDIR"
for c in "${LAYER_BIN[@]}"; do
  [[ -f $src/bin/$c ]] || { warn "$c is not in this tree; skipping"; continue; }
  sudo install -m755 "$src/bin/$c" "$SHARE/bin/$c"
  sudo ln -sfn "$SHARE/bin/$c" "$BINDIR/$c"
done
for d in "${LAYER_TREE[@]}"; do
  [[ -d $src/$d ]] || continue
  sudo install -d "$SHARE/$(dirname "$d")"
  sudo cp -a "$src/$d" "$SHARE/$(dirname "$d")/"
done
sudo install -m644 "$src/version" "$SHARE/version" 2>/dev/null || true

# --- the parts that are the point -------------------------------------------------------------------
log "posture and guard"
oal-agent-profile scoped >/dev/null 2>&1 || true

# Register the guard with whichever runtimes are here. Claude Code is the only one with a
# pre-tool-call hook; see docs/agent-guard.md for what that means for the others.
if command -v claude >/dev/null && command -v jq >/dev/null; then
  settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  guard="$SHARE/agent/hooks/pretooluse-guard"
  mkdir -p -- "$(dirname "$settings")"
  [[ -s $settings ]] || echo '{}' >"$settings"
  tmp="$(mktemp)"
  if jq --arg g "$guard" '.hooks.PreToolUse = [{matcher: "*", hooks: [{type: "command", command: $g}]}]' \
       "$settings" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$settings"; echo "  tool calls are guarded for Claude Code"
  else
    rm -f "$tmp"; warn "could not register the guard in $settings"
  fi
else
  warn "no Claude Code runtime found: nothing is gated until something calls oal-guard"
fi

log "health watch"
units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p -- "$units"
sed "s|/usr/bin/oal-watch|$BINDIR/oal-watch|" "$src/default/systemd/user/oal-watch.service" >"$units/oal-watch.service"
cp -f "$src/default/systemd/user/oal-watch.timer" "$units/oal-watch.timer"
if systemctl --user daemon-reload 2>/dev/null && systemctl --user enable --now oal-watch.timer 2>/dev/null; then
  echo "  oal-watch.timer enabled"
else
  warn "no user session bus yet; enable later with 'systemctl --user enable --now oal-watch.timer'"
fi

log "done"
cat <<DONE
  oal-doctor                     what is wrong with this machine
  oal-guard --tool Bash          ask whether a call would be allowed
  oal-brain-backend --list       choose what answers questions
  oal-mcp-install agentarchy     expose this machine to your agent over MCP

  Uninstall: bash $0 --uninstall
DONE
