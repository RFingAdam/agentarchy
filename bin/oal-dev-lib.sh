#!/usr/bin/env bash
# Shared helpers for bin/oal-dev-* scripts. Source, do not execute.

oal_dev_root() {
  # Repo root = directory containing upstream/PIN, walking up from this file.
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/upstream/PIN" ]] && { echo "$d"; return 0; }
    d="$(dirname "$d")"
  done
  echo "oal-dev: cannot locate repo root (no upstream/PIN above ${BASH_SOURCE[0]})" >&2
  return 1
}

oal_dev_log() { echo "oal-dev: $*" >&2; }
oal_dev_die() { echo "oal-dev: error: $*" >&2; exit 1; }
