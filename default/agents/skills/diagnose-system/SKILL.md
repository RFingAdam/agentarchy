---
name: diagnose-system
description: >
  Investigate a health finding on this machine, from an oal-doctor check. Use when a
  "Click to diagnose" desktop notification is acted on, when asked what is wrong with
  the machine, why it is slow, why a service will not start, why the disk is full, or
  why the agent layer is not working. Triggers: oal-doctor, failed unit, systemd
  failure, degraded, out of memory, OOM, disk full, no space, overheating, thermal
  throttle, orphaned packages, pacnew, no network, driver not bound, "what is wrong
  with this machine".
---

# Diagnosing a system finding

`oal-doctor` says *what* is wrong. It does not say *why*, and it is deliberately shallow:
every check has to finish in well under a second because the whole report is read on a
timer and injected into prompts. Your job is the depth it does not have.

Work from evidence. The goal is an honest account of what happened, not a plausible-sounding
story, and "I could not determine this" is a real answer.

## Start by re-reading the report yourself

`oal-doctor --json` gives every check, not just the one you were handed. Look at the others
before deciding what the finding means. Most real problems show up in more than one check,
and the shape across several is what tells you which is cause and which is symptom:

- `oom` **and** `failed-units`: the units did not fail on their own merits, they were killed.
  Investigating the unit is the wrong thread. Find what ate the memory.
- `disk` **and** `journal` errors: a full disk makes almost anything log an error. Fix the
  disk first, then re-read the journal; most of it usually goes away.
- `network` **and** `updates` unknown: there is one problem here, not two.
- `brain` down **and** `network` down: a remote backend cannot answer without a route. A
  local one should not care, and if it does, that is the interesting finding.

A check reporting `unknown` means it could not run. That is not the same as passing, and it is
worth a sentence in your answer rather than silence.

## Per finding, where to look first

**failed-units.** `systemctl status <unit>` then `journalctl -u <unit> -b --no-pager`. Read the
first failure, not the last: a unit with `Restart=` fails repeatedly and the final entry is the
symptom of the first. Transient `run-*.scope` units are not services anybody configured: they
are one-off commands, usually launched by a session, and their failure points at whatever
launched them.

**oom.** `journalctl -k -b -g 'oom-kill:'`. The kernel line names the task and the cgroup. The
cgroup matters more than the task: `oom_memcg=` ending in a `.scope` under `user@.service` means
a per-session memory limit was hit, not that the machine ran out of RAM. Check `free -h` and
`systemd-cgtop` before concluding the machine is short of memory.

**disk.** `df -h` for the mount, then find the weight: `du -xh --max-depth=1 <mount> | sort -h |
tail`. `-x` matters, or you follow it onto other filesystems and get a confusing answer. Common
and boring causes worth ruling out first: the pacman cache (`/var/cache/pacman/pkg`), the journal
(`journalctl --disk-usage`), and old snapshots.

**thermal.** `sensors` if it is installed. Sustained high temperature under no load is a cooling
problem; high under load is normal. Check `journalctl -k -b -g 'thermal|throttl'` for whether the
kernel actually throttled anything, because a warm sensor that never triggered a limit did not
affect the machine.

**journal errors.** Group them before reading them: many machines log the same handful of errors
thousands of times, and the count is meaningless until it is deduplicated. `journalctl -p err -b
-o cat | sort | uniq -c | sort -rn | head`. Repeated identical errors are usually one
misconfiguration; a scatter of distinct errors is usually something worse.

**network.** `ip route`, then `resolvectl status`. A default route with no resolution is DNS. No
default route is the link or DHCP. Do not conclude from `ping` alone: ICMP is filtered often
enough that a failed ping is a bad signal.

**updates / orphans / pacnew.** These are hygiene rather than faults. `.pacnew` files are the one
worth acting on: a config an update could not merge means the running config may be missing new
defaults. `pacdiff` walks them. Never merge one without showing the diff first.

**gpu.** If no driver is bound, `journalctl -k -b -g -i 'nvidia|nouveau|drm'` usually says why,
frequently a module that failed to build against the running kernel after an update, which also
means the machine is one reboot away from a different answer.

**guard / brain.** These are Agentarchy's own. `oal-brain-status` and `docs/brain.md` describe the
contract; `docs/agent-guard.md` describes the guard. A guard reporting "installed but not
registered" is fixed by re-running `install/agent/runtime.sh`, and it is worth saying out loud
that until it is, tool calls on this machine are not being gated.

## Rule out the boring causes first

Before blaming software: check whether the machine ran out of memory, ran out of disk, or was
recently updated. `journalctl -b -u 'pacman*'` and the mtime of `/var/log/pacman.log` place a
change against the timestamp of the first failure. A problem that starts immediately after an
update is about the update until proven otherwise.

## What to report

State what you established, what you could not, and what you would do next. Distinguish clearly
between the three. A report that reads as equally confident throughout is one nobody can act on
selectively.

If a fix requires `sudo`, say what the command is and why, and let the person run it. The tool-call
guard will ask before it runs anyway (see `docs/agent-guard.md`), and a diagnosis that quietly
changes the machine is not a diagnosis.

If the finding turns out to be a bug in Agentarchy itself rather than in this machine's state, the
reporting conventions in the sibling `diagnose-crash` skill's `reporting.md` apply here too.
