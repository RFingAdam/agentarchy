#!/usr/bin/env bash
# Packs test/fixtures/upstream-mini into a GitHub-style tarball (top dir "basecamp-omarchy-<sha>") at $1.
set -euo pipefail
out="$1"; sha="${2:-2c247e390e357ae0fee3f8565b0c816adb705e6a}"
src="$(cd "$(dirname "$0")/upstream-mini" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/basecamp-omarchy-${sha:0:7}"
cp -a "$src"/. "$tmp/basecamp-omarchy-${sha:0:7}/"
tar -C "$tmp" -czf "$out" "basecamp-omarchy-${sha:0:7}"
