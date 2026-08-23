# VM test harness

Boots a throwaway Arch VM from the official cloud image so that changes to the install path can be
proven on a real system instead of argued about. Everything lives in the repo (git-ignored) and
nothing needs root.

```
test/vm/vm-image        # download + verify the cloud image into .vm-cache/ (idempotent)
test/vm/vm-up --fresh   # boot a pristine guest, block until ssh answers   (~50 s)
test/vm/vm-sync         # rsync this checkout to /home/oal/agentarchy in the guest
test/vm/vm-ssh 'cmd'    # run something in the guest
test/vm/vm-scp to|from  # copy one file in or out
test/vm/vm-shot out.png # screenshot (QMP framebuffer, or --guest via spectacle)
test/vm/vm-down         # stop it (--purge also throws the disk away)
```

The whole loop, from nothing to a running guest you can talk to:

```bash
test/vm/vm-image && test/vm/vm-up --fresh && test/vm/vm-ssh 'uname -r; df -h /'
```

## What you get

A `q35`/KVM guest with 6 vCPU, 8 GB RAM and a 24 G root, booted through OVMF (UEFI) from a
copy-on-write overlay on the cached cloud image -- so the cache stays pristine and `--fresh` is
just deleting a file. Cloud-init seeds one user:

* user `oal`, in `wheel`, passwordless `sudo`, no password login, key at `.vm/id_vm`
* hostname `agentarchy-vm`, sshd enabled on first boot
* host port (`.vm/port`, usually 2822) forwarded to the guest's 22

Everything the harness writes is under two git-ignored directories:

| path | what |
| --- | --- |
| `.vm-cache/` | the downloaded cloud image + its `.SHA256` (shared by every VM) |
| `.vm/` | this VM: `disk.qcow2`, `seed.iso`, `id_vm`, `vars.fd`, `port`, `qemu.pid`, `qmp.sock`, `serial.log` |

## Writing scripts against it

`test/vm/lib.sh` is the API; source it and you get `VM_DIR`, `VM_CACHE`, `VM_USER`, `VM_GUEST_REPO`
and:

| function | does |
| --- | --- |
| `vm_port` | the SSH port this VM was booted with (fails if no VM has been booted) |
| `vm_ssh <cmd...>` | run a command in the guest. Arguments are the *guest's* command line |
| `vm_scp_to <local> <remote>` / `vm_scp_from <remote> <local>` | copy one path |
| `vm_rsync_to <src> <dest>` | mirror a directory into the guest (`--delete`) |
| `vm_wait_ssh <timeout_s>` | block until ssh answers; sets `VM_WAIT_ELAPSED` |
| `vm_qmp <json>` | one QMP command, capabilities handshake included |
| `vm_running` / `vm_pid` | is the VM up, and as which process |
| `vm_serial_tail [n]` | the tail of the boot console, i.e. where boot failures explain themselves |

## Pitfalls this harness already handles

Each of these cost real debugging time. They are encoded in `lib.sh`; do not undo them.

**`/tmp` is a small tmpfs.** On the dev host it is 2 GB. A 24 G disk overlay or a stream of 3 MB
screendumps fills it, which corrupts the guest's I/O *and* breaks everything else using `/tmp`. All
VM state lives in the repo, and `vm_assert_durable` refuses any `VM_DIR`/`VM_CACHE` that is on
tmpfs or under a temp directory -- including a screenshot destination.

**The SSH port cannot be hard-coded.** The host already listens on 2222, and a previous VM may
still hold 2822. `vm-up` claims the first free port in 2822-2899 (`ss -ltn`) and writes it to
`.vm/port`; every other script reads that file rather than guessing.

**Unix socket paths are limited to 108 bytes.** `sockaddr_un.sun_path` is 108 bytes including the
NUL, so the QMP socket has to be `<repo>/.vm/qmp.sock` and not something under a deep scratch
directory. `vm_qmp` checks the length before it connects, so the failure is a sentence rather than
an unexplained `ENAMETOOLONG`.

**ssh needs `IdentitiesOnly=yes`.** Without it your ssh-agent offers every key it holds, the guest
hits `MaxAuthTries` and closes the connection before the VM key is ever tried -- which looks
exactly like "the VM is not up yet". `VM_SSH_OPTS` also pins `UserKnownHostsFile=/dev/null` (a
rebuilt VM gets a new host key every time) and disables password/keyboard-interactive auth so a
broken guest fails instead of hanging on a prompt.

**The cloud image ships no `rsync`.** `vm-sync` installs it in the guest on first use. It uses a
plain `pacman -S` against the databases the image already carries, so it cannot leave the guest
half-upgraded; `-Sy` is only the fallback for when those databases are too stale to resolve.

**Cloud-init only re-reads `user-data` when the instance id changes.** The id is a digest of the
user-data, so editing the cloud config really does take effect on the next boot instead of being
silently ignored on an existing disk.

**A console screenshot looks empty, and that is correct.** The kernel command line puts the console
on `ttyS0` (captured to `.vm/serial.log`), so the virtio-gpu framebuffer holds only the login
banner until something actually draws. `vm-shot` still captures the real framebuffer -- write to
`/dev/tty1` and it shows up. Read the boot output from `.vm/serial.log`, not from a screenshot.

**Screendumps are written by qemu, not by the harness.** If the filesystem is full, qemu reports
the error over QMP and there is no file. `vm_qmp` fails on any QMP `"error"` response and `vm-shot`
refuses to run with less than 64 MB free, so an out-of-space screenshot is loud rather than a
zero-byte PNG.

## Watching a VM live

The guest normally runs headless (`-display none -vga none` with a `virtio-gpu-pci` device, so
there is still a framebuffer to screenshot). To watch it instead, boot with `VM_VNC` set and point
a VNC client at that address:

```bash
VM_VNC=127.0.0.1:1 test/vm/vm-up --fresh   # then: vncviewer 127.0.0.1:5901
```

`.vm/serial.log` is the boot console and is usually the faster answer; `vm-up` prints its tail
automatically when a boot never reaches ssh.

## Housekeeping

* `.vm/` and `.vm-cache/` are git-ignored. `.vm/id_vm` is a throwaway key for a throwaway VM and
  must never be committed.
* `vm-up` leaves a VM that failed to boot running so it can be inspected; `vm-down` stops it.
* `vm-down --purge` (or `vm-up --fresh`) discards the disk. The cached image is untouched --
  `vm-image --force` is the only thing that re-downloads it.
* `vm-image` prints the upstream build id on every run and warns when the cache no longer matches
  what upstream publishes, so a months-old image cannot quietly shape a test result.
