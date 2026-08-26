#!/bin/bash
# Local inference at the OS level.
#
# Runs as the user out of oal-bootstrap.sh, after the agent runtime. The package list already put the
# CPU build on; this decides whether the machine can do better, and turns the service on either way.
set -uo pipefail

log() { printf 'oal: %s\n' "$*"; }

command -v ollama >/dev/null || { log "ollama is not installed; skipping local inference setup"; exit 0; }

# A real NVIDIA GPU means the CUDA build is worth the swap. A virtio GPU is for graphics: it cannot
# do inference, and pretending otherwise would install a CUDA build that silently falls back to CPU
# while implying it did not.
if [[ -e /dev/nvidia0 ]] || lspci 2>/dev/null | grep -qiE 'vga|3d' && lspci 2>/dev/null | grep -qi nvidia; then
  log "NVIDIA GPU detected; installing the CUDA build of ollama"
  sudo pacman -S --needed --noconfirm --disable-download-timeout ollama-cuda >/dev/null 2>&1 ||
    log "warning: ollama-cuda did not install; the CPU build stays in place"
else
  log "no NVIDIA GPU; local inference will use the CPU"
fi

# System service, not a user one: a model is a machine-wide resource and loading two copies for two
# logins is how a laptop runs out of memory.
if sudo systemctl enable --now ollama.service >/dev/null 2>&1; then
  log "local inference enabled (ollama)"
else
  log "ollama installed; enable it with 'sudo systemctl enable --now ollama.service'"
fi

# Deliberately no model. They are gigabytes, and picking one for somebody is a worse default than
# telling them how.
if ! ollama list 2>/dev/null | awk 'NR>1' | grep -q .; then
  log "no local model yet. 'ollama pull qwen2.5:1.5b' is small enough to answer on a CPU."
fi
