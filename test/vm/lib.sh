#!/usr/bin/env bash
# Shared helpers for the test/vm/* harness. Source, do not execute.
#
# Every pitfall this harness has already paid for is encoded below; test/vm/README.md explains
# each one in prose:
#   * the dev host's /tmp is a small tmpfs -- VM disks, screendumps and logs live under the repo
#     (.vm/, .vm-cache/, both git-ignored). vm_assert_durable() refuses anything on tmpfs/ramfs.
#   * the host already listens on 2222 (and possibly on part of 28xx), so the SSH forward port is
#     chosen at run time from the free ports in $VM_PORT_MIN..$VM_PORT_MAX and persisted to .vm/port.
#   * a unix socket path must fit in sockaddr_un.sun_path (108 bytes incl. NUL), so the QMP socket
#     lives at <repo>/.vm/qmp.sock and never in a deep scratch directory.
#   * ssh needs -o IdentitiesOnly=yes, or the host's ssh-agent offers every key it holds and the
#     guest closes the connection on MaxAuthTries before the VM key is ever tried.

[[ -n "${VM_LIB_SOURCED:-}" ]] && return 0
VM_LIB_SOURCED=1

vm_log()  { printf 'vm: %s\n' "$*" >&2; }
vm_warn() { printf 'vm: warning: %s\n' "$*" >&2; }
vm_die()  { printf 'vm: error: %s\n' "$*" >&2; exit 1; }

# Repo root = the directory containing upstream/PIN, walking up from this file. Keeps the harness
# working from any cwd and refuses to guess if it is copied out of the repo.
vm_repo_root() {
  local d
  d="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/upstream/PIN" ]] && { printf '%s\n' "$d"; return 0; }
    d="$(dirname -- "$d")"
  done
  vm_die "cannot locate the repo root (no upstream/PIN above ${BASH_SOURCE[0]})"
}

vm_need() {
  local c missing=()
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  [[ ${#missing[@]} -eq 0 ]] || vm_die "missing required command(s): ${missing[*]}"
}

# Refuse to put VM state on a temp filesystem. The host /tmp here is a 2 GB tmpfs: a 24 G overlay
# or a stream of screendumps fills it, which corrupts the guest's I/O *and* wedges anything else
# using /tmp. Both a path check (for dirs that do not exist yet) and an fstype check.
vm_assert_durable() {
  local label="$1" path="$2" probe fstype
  case "$path" in
    /tmp | /tmp/* | /var/tmp | /var/tmp/* | /dev/shm | /dev/shm/*)
      vm_die "$label=$path is under a temp directory; VM state must live in the repo (.vm/)" ;;
  esac
  # Called before the directory is created, so ask the nearest existing ancestor what it is on.
  probe="$path"
  while [[ ! -e "$probe" && "$probe" != "/" && "$probe" != "." ]]; do probe="$(dirname -- "$probe")"; done
  fstype="$(stat -f -c %T -- "$probe" 2>/dev/null || true)"
  case "$fstype" in
    tmpfs | ramfs)
      vm_die "$label=$path is on $fstype ($probe); VM state must live on a real filesystem (.vm/)" ;;
  esac
  return 0
}

VM_REPO="${VM_REPO:-$(vm_repo_root)}"
export VM_REPO
export VM_DIR="${VM_DIR:-$VM_REPO/.vm}"
export VM_CACHE="${VM_CACHE:-$VM_REPO/.vm-cache}"
vm_assert_durable VM_DIR "$VM_DIR"
vm_assert_durable VM_CACHE "$VM_CACHE"
mkdir -p -- "$VM_DIR" "$VM_CACHE"

# Guest identity and on-disk layout.
export VM_USER="${VM_USER:-oal}"
export VM_HOST="${VM_HOST:-127.0.0.1}"
export VM_HOSTNAME="${VM_HOSTNAME:-agentarchy-vm}"
export VM_GUEST_REPO="${VM_GUEST_REPO:-/home/$VM_USER/agentarchy}"
export VM_KEY="$VM_DIR/id_vm"
export VM_DISK="$VM_DIR/disk.qcow2"
export VM_SEED="$VM_DIR/seed.iso"
export VM_VARS="$VM_DIR/vars.fd"
export VM_PIDFILE="$VM_DIR/qemu.pid"
export VM_QMP_SOCK="$VM_DIR/qmp.sock"
export VM_SERIAL="$VM_DIR/serial.log"
export VM_QEMU_LOG="$VM_DIR/qemu.log"
export VM_PORT_FILE="$VM_DIR/port"

# Cloud image (official Arch, cloud-init preinstalled, btrfs + GRUB, ~2 G virtual disk).
export VM_IMAGE_NAME="${VM_IMAGE_NAME:-Arch-Linux-x86_64-cloudimg.qcow2}"
export VM_IMAGE_URL_BASE="${VM_IMAGE_URL_BASE:-https://geo.mirror.pkgbuild.com/images/latest}"
export VM_IMAGE="$VM_CACHE/$VM_IMAGE_NAME"

# Machine shape. Boot-to-SSH is ~50 s at these numbers; smaller is slower, not broken.
export VM_SMP="${VM_SMP:-6}"
export VM_MEM="${VM_MEM:-8192}"
export VM_DISK_SIZE="${VM_DISK_SIZE:-24G}"
export VM_PORT_MIN="${VM_PORT_MIN:-2822}"
export VM_PORT_MAX="${VM_PORT_MAX:-2899}"

# --- port -------------------------------------------------------------------------------------

# Read the port the current VM was booted with. Deliberately fails instead of guessing: talking to
# whatever happens to sit on 2822 is worse than an error message.
vm_port() {
  local p
  [[ -s "$VM_PORT_FILE" ]] || vm_die "no $VM_PORT_FILE -- boot the VM first (test/vm/vm-up)"
  p="$(head -n1 -- "$VM_PORT_FILE" 2>/dev/null | tr -dc '0-9')"
  [[ -n "$p" ]] || vm_die "$VM_PORT_FILE does not contain a port number"
  printf '%s\n' "$p"
}

# Claim the first port in the range that nothing is listening on, and persist it.
vm_port_alloc() {
  local p listening
  vm_need ss
  listening="$(ss -ltnH 2>/dev/null | awk '{print $4}')"
  for ((p = VM_PORT_MIN; p <= VM_PORT_MAX; p++)); do
    grep -qE "[:.]${p}\$" <<<"$listening" && continue
    printf '%s\n' "$p" >"$VM_PORT_FILE"
    printf '%s\n' "$p"
    return 0
  done
  vm_die "no free TCP port in ${VM_PORT_MIN}-${VM_PORT_MAX}"
}

# --- ssh --------------------------------------------------------------------------------------

# IdentitiesOnly is load bearing (see the header). The known-hosts settings keep a rebuilt VM from
# tripping the host-key check, and the auth settings keep a broken guest from blocking on a prompt
# instead of failing.
VM_SSH_OPTS=(
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o PasswordAuthentication=no
  -o KbdInteractiveAuthentication=no
  -o LogLevel=ERROR
  -o ConnectTimeout=5
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=4
)

# Arguments are the *remote command*: ssh options have to precede the host name, so they live in
# VM_SSH_OPTS above rather than being accepted here (where they would silently become part of the
# command line the guest runs).
vm_ssh() {
  local port; port="$(vm_port)"
  [[ -f "$VM_KEY" ]] || vm_die "no guest key at $VM_KEY -- boot the VM first (test/vm/vm-up)"
  ssh "${VM_SSH_OPTS[@]}" -i "$VM_KEY" -p "$port" "$VM_USER@$VM_HOST" "$@"
}

vm_scp_to() {
  local port; port="$(vm_port)"
  [[ $# -eq 2 ]] || vm_die "vm_scp_to <local> <remote>"
  scp "${VM_SSH_OPTS[@]}" -i "$VM_KEY" -P "$port" -r "$1" "$VM_USER@$VM_HOST:$2"
}

vm_scp_from() {
  local port; port="$(vm_port)"
  [[ $# -eq 2 ]] || vm_die "vm_scp_from <remote> <local>"
  scp "${VM_SSH_OPTS[@]}" -i "$VM_KEY" -P "$port" -r "$VM_USER@$VM_HOST:$1" "$2"
}

# Paths that must never be pushed into the guest: git history, the harness's own multi-GB scratch,
# session bookkeeping, and any local build output.
VM_SYNC_EXCLUDES=(.git .vm .vm-cache .superpowers pkg src '*.pkg.tar.zst')

# rsync the repo checkout into the guest. --delete so a removed file on the host disappears in the
# guest too, which is the whole point when you are iterating on install scripts.
vm_rsync_to() {
  local port src="$1" dest="$2" ssh_cmd e args=()
  port="$(vm_port)"
  [[ -f "$VM_KEY" ]] || vm_die "no guest key at $VM_KEY -- boot the VM first (test/vm/vm-up)"
  vm_need rsync
  for e in "${VM_SYNC_EXCLUDES[@]}"; do args+=(--exclude "$e"); done
  # rsync splits --rsh on whitespace and does not honour quoting, so a key path containing a space
  # would be torn in half. Say so instead of failing three layers down inside rsync.
  [[ "$VM_KEY" != *[[:space:]]* ]] || vm_die "the repo path contains whitespace; rsync cannot pass '$VM_KEY' to --rsh"
  printf -v ssh_cmd '%s ' ssh "${VM_SSH_OPTS[@]}" -i "$VM_KEY" -p "$port"
  rsync -a --delete "${args[@]}" -e "$ssh_cmd" "$src" "$VM_USER@$VM_HOST:$dest"
}

# Block until the guest answers ssh. Returns 1 (never hangs forever) and sets VM_WAIT_ELAPSED so
# the caller can report the boot time. Fails fast if qemu died rather than burning the timeout.
vm_wait_ssh() {
  local timeout="${1:-300}" start
  start=$SECONDS
  VM_WAIT_ELAPSED=0
  while :; do
    VM_WAIT_ELAPSED=$((SECONDS - start))
    if [[ -s "$VM_PIDFILE" ]] && ! vm_running; then
      vm_warn "qemu exited while waiting for ssh (after ${VM_WAIT_ELAPSED}s)"
      return 1
    fi
    if vm_ssh true >/dev/null 2>&1; then
      VM_WAIT_ELAPSED=$((SECONDS - start))
      return 0
    fi
    [[ $VM_WAIT_ELAPSED -lt $timeout ]] || { vm_warn "ssh did not answer within ${timeout}s"; return 1; }
    sleep 3
  done
}

# --- qemu process -----------------------------------------------------------------------------

vm_pid() {
  [[ -s "$VM_PIDFILE" ]] || return 1
  # qemu removes its own pid file on exit, so the file can vanish between the test above and the
  # read below; that is a dead VM, not an error worth printing.
  local p; p="$(head -n1 -- "$VM_PIDFILE" 2>/dev/null | tr -dc '0-9')"
  [[ -n "$p" ]] || return 1
  printf '%s\n' "$p"
}

# True only if the pid file points at a live qemu -- a recycled pid must not be mistaken for the VM
# (and must never be killed by vm-down).
vm_running() {
  local pid
  pid="$(vm_pid)" || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  grep -qa qemu-system "/proc/$pid/cmdline" 2>/dev/null
}

# --- qmp --------------------------------------------------------------------------------------

# Send one QMP command, after the mandatory capabilities handshake. Prints every response line and
# fails if the monitor reported an error (e.g. screendump onto a full filesystem).
vm_qmp() {
  local cmd="$1" out
  vm_need socat
  [[ ${#VM_QMP_SOCK} -lt 108 ]] || vm_die "QMP socket path is ${#VM_QMP_SOCK} bytes, the kernel limit is 107"
  [[ -S "$VM_QMP_SOCK" ]] || vm_die "no QMP socket at $VM_QMP_SOCK -- is the VM up?"
  out="$( { printf '%s\n' '{"execute":"qmp_capabilities"}'
            sleep 0.5
            printf '%s\n' "$cmd"
            sleep 3
          } | socat -t 5 -T 60 - "UNIX-CONNECT:$VM_QMP_SOCK" 2>&1 )" \
    || vm_die "qmp: socat failed: $out"
  printf '%s\n' "$out"
  if grep -q '"error"' <<<"$out"; then
    vm_die "qmp command failed: $(grep '"error"' <<<"$out" | tail -n1)"
  fi
}

# --- firmware ---------------------------------------------------------------------------------

# OVMF split into CODE (read-only, shared) + VARS (per-VM copy). Path differs per distro, so probe
# the known pairs instead of hard-coding one host's layout.
vm_ovmf_code() {
  local c
  for c in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
    /usr/share/qemu/ovmf-x86_64-code.bin
  do [[ -f "$c" ]] && { printf '%s\n' "$c"; return 0; }; done
  vm_die "no OVMF firmware found (install ovmf / edk2-ovmf)"
}

vm_ovmf_vars() {
  local v
  for v in \
    /usr/share/OVMF/OVMF_VARS_4M.fd \
    /usr/share/edk2/x64/OVMF_VARS.4m.fd \
    /usr/share/edk2/ovmf/OVMF_VARS.fd \
    /usr/share/edk2-ovmf/x64/OVMF_VARS.fd \
    /usr/share/qemu/ovmf-x86_64-vars.bin
  do [[ -f "$v" ]] && { printf '%s\n' "$v"; return 0; }; done
  vm_die "no OVMF variable template found (install ovmf / edk2-ovmf)"
}

# --- misc -------------------------------------------------------------------------------------

# Free megabytes on the filesystem holding $1. Used to refuse operations that would fill the disk.
vm_free_mb() {
  df -Pm -- "$1" | awk 'NR==2 {print $4}'
}

# Last lines of the boot console, which is where a boot failure actually explains itself.
vm_serial_tail() {
  local n="${1:-40}"
  [[ -f "$VM_SERIAL" ]] || { vm_warn "no serial log at $VM_SERIAL"; return 0; }
  printf -- '--- %s (last %s lines) ---\n' "$VM_SERIAL" "$n" >&2
  tail -n "$n" -- "$VM_SERIAL" >&2
  printf -- '--- end of serial log ---\n' >&2
}
