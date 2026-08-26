# When the machine notices something

Upstream ships one of these. `oal-crash-watch` follows the journal for core dumps, and on one it
raises a notification saying "Process crashed: X -- click to diagnose with AI". Clicking runs
`oal-agent-crash`, which gathers what systemd-coredump recorded, points at a **skill** describing how
to investigate, and hands both to the configured agent.

That shape is right. The scope was one row long.

## What was actually wrong with it here

The launcher at the end of that chain, upstream's `omarchy-agent`, was excluded from vendoring as
terminal-bound. The commands that call it were not. So on Agentarchy:

- `bin/oal-agent` did not exist
- `oal-agent-crash` ended at `exec oal-agent`, exit 127
- `default/bash/aliases` bound `a` to it, in every shell on the machine
- `oal-crash-watch` gated every crash on `[[ -n $(oal-default-agent) ]]`, a command that also did not
  exist, so the substitution was empty and the guard fired on every crash. The watcher announced
  nothing it was ever started for.
- `install/user/first-run/enable-user-units.sh` enables the watcher, and nothing in
  `oal-bootstrap.sh` runs that directory at all. It is the ISO's path. On a bootstrap install the
  service had never once started.

Four layers, and `upstream/DANGLING.txt` had recorded the first three since the day the tree was
vendored. Nothing read the file. `tasks/lessons.md` calls this family *present, correct, and on the
wrong path*; this is the case where we had also written down that it was broken.

## The generalisation

A crash is one thing that can go wrong. The mechanism is worth having for the rest:

```
an event  ->  gathered context  ->  a skill stating the method  ->  the configured brain
                                                                          |
                                                    every resulting action gated by the guard
```

`bin/oal-watch` is that, and it deliberately does **not** introduce a second table of events.
`oal-doctor` already enumerates what can be wrong with this machine, in a structured form, with a
severity for each finding. That is the event table. A parallel list would be two things to keep in
step, and the second one always goes stale.

So:

| | |
|---|---|
| `oal-doctor --json` | what can be wrong, and what currently is |
| `oal-watch` | runs it on a timer, announces findings that are **new** |
| `oal-agent-diagnose <id>` | the click target: one finding, plus the skill, handed to the brain |
| `default/agents/skills/diagnose-system/` | the method, in one editable place |

`oal-crash-watch` stays as it is. A core dump is a real-time event with structured journal fields of
its own, and polling for it would be worse.

## Only transitions

A disk that was 96% full an hour ago and still is has not become news. `oal-watch` keeps the set of
currently-failing check ids in `~/.local/state/oal/watch-seen` and announces only what entered it.

This is not a nicety. A watcher that repeats itself every ten minutes is one people turn off, and a
watcher that has been turned off is worse than one that was never installed, because everyone
remembers installing it.

`unknown` findings are never announced. A check that could not run is a gap in the report rather than
an event, and waking somebody for it teaches them that the notification means nothing.

## It says nothing until you have chosen an agent

The toast's only offer is a diagnosis, so it has nothing to offer until a backend exists.
`oal-watch` checks `oal-brain-backend` and stays silent if there is none, which is the same rule
`oal-crash-watch` follows.

`--no-notify` reports findings to stdout and puts nothing on screen, and `OAL_WATCH_NO_NOTIFY=1`
does the same from the environment. `test/unit/watch.bats` sets both, because it runs the real
command: without them the suite raised real desktop notifications on the developer's machine, several
per run, since every test gets a fresh state directory and so sees every finding as new. Worse than
it sounds, because `oal-notification-send` defaults to the app name `oal-action`, which is the one
name Do Not Disturb lets through.

## Turning it off

```
oal-toggle-health-watch off
```

A state file that the unit's own `ConditionPathExists` reads, mirroring `oal-toggle-crash-capture`,
rather than disabling the unit. Disabling it would be undone by the next install re-enabling shipped
units, silently, which is the kind of thing that makes people distrust the whole system.

## Adding an event

Add a check to `oal-doctor`. That is the entire procedure, and it is the point of not having a
second table. A new check appears in the report, in the grounding that `oal-brain-ask` attaches, in
`oal-watch`'s notifications and in the `os_status` MCP tool, without any of them being edited.

Two rules for the check itself, both enforced by `test/unit/doctor.bats`:

- **It must not be able to block.** Every external command runs under a timeout. The report is read
  on a timer, injected into prompts, and called from a notification path.
- **If it could not run, it reports `unknown`.** Never `ok`. A false pass is indistinguishable from a
  real one, and one of them makes the whole report worthless.

Then mention the new check id in the `diagnose-system` skill. The test suite checks that too, from
the report itself rather than from a list somebody has to remember to update.
