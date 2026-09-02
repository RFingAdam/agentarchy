#!/usr/bin/env bash
# Shared helpers for bin/oal-mcp-*. Source, do not execute.
#
# Not in bin/ on purpose: PKGBUILD symlinks every bin/* onto PATH except oal-dev-*, so a library
# living there would become a command called oal-mcp-lib.sh.

# Resolved once, here, from this file's own location: lib.sh lives at $OAL_PATH/default/mcp/lib.sh,
# so the tree root is three directories up. Computed at source time and not inside a function --
# BASH_SOURCE[1] is the *caller's* file, which is this same file whenever one library function calls
# another, and the path then resolves a level too deep. That version worked everywhere OAL_PATH
# happened to be exported and returned an empty catalog on a real installed system.
_oal_mcp_lib="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
_oal_mcp_root="$(cd "$_oal_mcp_lib/../.." && pwd)"

oal_mcp_path() {
  # OAL_PATH is exported by /etc/profile.d/oal.sh for login shells only, and these commands are
  # routinely run from ssh and from scripts, so it cannot be relied on.
  printf '%s' "${OAL_PATH:-$_oal_mcp_root}"
}

oal_mcp_die() { echo "${0##*/}: $*" >&2; exit 1; }

# Where imported catalogs are remembered. An imported entry is not the same as a shipped one and the
# commands say so, so that it is always clear which servers this distribution vouches for.
oal_mcp_state() { printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/oal/mcp"; }

# --- catalog ------------------------------------------------------------------------------------

# Print every catalog row, one per line, fields separated by US (0x1f).
#   id, kind, package, args, visibility, profiles, origin, description
# origin is "shipped" for default/mcp/CATALOG and the file's basename for anything imported.
#
# Not tab-separated. Tab is IFS whitespace, so bash collapses a run of them into one delimiter, and
# the args column is empty for most rows -- with tabs, `read` silently shifts every later field left
# and a row's profiles end up in its args. US is not whitespace and cannot occur in the data.
oal_mcp_catalog() {
  local path file origin
  path="$(oal_mcp_path)"
  for file in "$path/default/mcp/CATALOG" "$(oal_mcp_state)"/imported/*.catalog; do
    [[ -f $file ]] || continue
    origin=shipped
    [[ $file == "$path/default/mcp/CATALOG" ]] || origin="$(basename "$file" .catalog)"
    local id kind package args visibility profiles description
    while IFS='|' read -r id kind package args visibility profiles description; do
      id="$(xargs <<<"$id")"
      [[ -n $id && $id != \#* ]] || continue
      printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
        "$id" "$(xargs <<<"$kind")" "$(xargs <<<"$package")" "$(xargs <<<"$args")" \
        "$(xargs <<<"${visibility:-public}")" "$(xargs <<<"$profiles")" "$origin" \
        "$(sed -e 's/^ *//' -e 's/ *$//' <<<"$description")"
    done < <(grep -v '^[[:space:]]*#' "$file" | grep '|')
  done
}

oal_mcp_row() { oal_mcp_catalog | awk -F'\x1f' -v id="$1" '$1 == id'; }

# --- the runtime --------------------------------------------------------------------------------
# One function per operation, so teaching this a second runtime (codex, pi) is a case statement here
# rather than a rewrite of five commands. Registration goes through the agent's own CLI and never by
# editing ~/.claude.json: that file is the agent's, it holds credentials, and the design's rule is
# that nothing reads it into a path we control.

# The runtimes this knows how to register a server with, in preference order.
#
# Two now. Both interfaces were read from the installed binaries rather than recalled: `codex mcp
# add <name> -- <command>` takes the same shape as Claude Code's, but `codex mcp list` prints a
# column table with a header while `claude mcp list` prints `name: ...` lines, so the listing side
# needs a case arm even though the adding side did not. The hermes brain adapter's header records
# what happened the last time an interface was invented from memory instead.
#
# OAL_MCP_RUNTIME pins one, for a machine with both installed and an opinion about which.
oal_mcp_runtimes() { printf '%s\n' claude codex; }

oal_mcp_runtime() {
  local r
  if [[ -n ${OAL_MCP_RUNTIME:-} ]]; then
    command -v "$OAL_MCP_RUNTIME" >/dev/null && { printf '%s' "$OAL_MCP_RUNTIME"; return 0; }
    return 1
  fi
  while read -r r; do
    command -v "$r" >/dev/null && { printf '%s' "$r"; return 0; }
  done < <(oal_mcp_runtimes)
  return 1
}

oal_mcp_runtime_available() { oal_mcp_runtime >/dev/null; }

oal_mcp_registered() {
  local rt
  rt="$(oal_mcp_runtime)" || return 0
  case "$rt" in
    # `name: transport - status`
    claude) claude mcp list 2>/dev/null | sed -nE 's/^([A-Za-z0-9_-]+):.*/\1/p' ;;
    # A table whose first column is the name. NR>1 drops the header.
    codex)  codex mcp list 2>/dev/null | awk 'NR>1 && $1 != "" {print $1}' ;;
  esac | sort -u
}

oal_mcp_register() { # oal_mcp_register <id> <kind> <package> <args...>
  local id="$1" kind="$2" package="$3"; shift 3
  local -a cmd
  local rt
  rt="$(oal_mcp_runtime)" || oal_mcp_die "$id: no agent runtime on PATH to register with"
  case "$kind" in
    uvx) cmd=(uvx "$package") ;;
    npx) cmd=(npx -y "$package") ;;
    # A server this distribution ships, already on PATH. Only the shipped catalog may use this kind:
    # oal-mcp-import refuses it, because a kind that runs a bare command turns an imported data file
    # into a way to register anything on the machine as a server.
    oal) cmd=("$package") ;;
    *) oal_mcp_die "$id: unknown kind '$kind' (expected uvx, npx or oal)" ;;
  esac
  (($#)) && cmd+=("$@")
  # Both spell this the same way, which is the only reason there is no case here.
  "$rt" mcp add "$id" -- "${cmd[@]}"
}

oal_mcp_unregister() {
  local rt
  rt="$(oal_mcp_runtime)" || oal_mcp_die "no agent runtime on PATH"
  "$rt" mcp remove "$1"
}

# $HOME is the only expansion allowed in a catalog's args column. A data file that can expand
# arbitrary shell is a data file that can run arbitrary shell.
oal_mcp_expand_args() {
  local args="$1"
  [[ -n $args ]] || return 0
  printf '%s' "${args//\$HOME/$HOME}"
}
