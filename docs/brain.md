# The brain contract

Everything else in the agent layer is *invoked*. You run `claude`, you run `oal-mcp-install`, you
read the prompt. A **brain** is the other thing: a process that is already running, remembers, is
reachable from somewhere other than the terminal you are sitting at, and can act on the machine.

Agentarchy ships the contract and thin adapters. It does not ship a brain, install one, or enable
one. That split is the same one `oal-mcp-import` makes, and for the same reasons: the part that is
ours cannot be taken away by somebody else's roadmap, a backend going quiet does not take the
feature with it, and anyone already running something keeps it.

## What a brain can do to this machine

`default/brain/VERBS`. The whole surface:

| Verb | | |
|---|---|---|
| `state` | | theme, layout, agent posture, host, uptime, battery |
| `theme` | `<name>` | set the desktop theme to an installed theme |
| `notify` | `<summary> [body]` | put a message on screen |
| `open` | `<desktop-id>` | open an installed application |

Four verbs, and the number is part of the design rather than a starting point on the way to thirty.
The guarantee this contract offers is that a person can hold the whole surface in their head, and an
allowlist nobody has read is not a control.

**Each verb validates its own arguments**, in `default/brain/lib.sh`. `theme` must name an installed
theme; `open` must name an installed desktop entry, not a path. A verb table that only allowlisted
command names would be a formality: `open` becomes "run anything" the first time someone hands it
`/usr/bin/bash`.

### Adding one

The question is not whether a brain would find it useful. It is what the worst plausible misuse
looks like, and whether you would still want the verb then. An agent that can retheme your desktop
is a good demo. One that can run `oal-system-factory-reset` is a support incident.

## Two checks, not one

Every action goes through `oal-brain-do`, and two things must agree:

1. the verb is in `VERBS`, and its own argument check passed
2. `agent/hooks/pretooluse-guard` allows the command it resolved to

Neither subsumes the other. The verb set is a design decision about what a brain is *for*; the guard
is a policy decision about what this machine *tolerates*. A verb in the set that resolves to
something the guard blocks is refused, which is what keeps the table from being the only control.
The only control is exactly as good as whoever edited it last.

Both tests for this are in `test/unit/brain.bats`, and they are the two worth reading first.

### A brain gets strictly less than a terminal

The guard's `confirm` tier means "a person opts in, per call". On this path there is no person.
`oal-brain-do` therefore treats `ask` as a refusal and names the command so you can run it yourself.
Treating an absent human as consent is how that tier stops meaning anything.

If the guard is missing or `jq` is absent, nothing runs. Fail closed, for the same reason the guard
does: a brain acting while the control governing it is absent is a brain with no control, and from
outside the machine those look identical.

## What an adapter must implement

An executable in `default/brain/adapters/` (or `~/.config/oal/brain/adapters/`, which wins), taking
one subcommand:

| | |
|---|---|
| `describe` | one line naming the backend, for `oal-brain-status` |
| `probe` | exit 0 if the backend is reachable. Must return quickly |
| `ask` | read the prompt on **stdin**, write the answer as text on **stdout** |
| `serve` | optional. Run in the foreground, for backends that want to be resident |

**The prompt arrives on stdin, never in argv.** Prompts contain quotes, newlines and shell
metacharacters as a matter of course, and argv is where those become somebody else's bug.

An adapter is forbidden from doing anything on the machine's behalf directly. If a backend wants
the desktop to change, it calls `oal-brain-do`, and it gets the same answer everything else does.

### The three shipped

- **`stub`**: a test fixture, and it says so. Answers deterministically with no model, no network
  and no account, so "is this wired up on this machine" has an answer that cannot be confounded by
  the backend being the problem. `test/vm/golden-path` uses it.
- **`claude-code`**: one invocation per question. Worth knowing what this composes to: the answer
  comes from an agent with its own tool access, governed by the same guard and the same
  `oal-agent-profile` as any other session. A question routed here can cause work.
- **`hermes`**: a [hermes-agent](https://github.com/NousResearch/hermes-agent) gateway. Resident,
  with its own memory, scheduler and chat gateways; the shape this contract was designed against.
  **Its request paths have not been verified against a running gateway**, so they are defaults and
  every one is overridable in `~/.config/oal/brain/hermes.env`. If yours speaks a different shape,
  set the variables rather than editing the file.

## Using it

```bash
oal-brain-backend --list        # adapters installed
oal-brain-backend stub          # choose one; this is the entire opt-in
oal-brain-status                # configured, and does it answer
oal-brain-ask "what is using my disk"
oal-brain-do notify "Build finished" "3 warnings"
oal-brain-backend --none        # back to nothing
```

Until a backend is chosen, `oal-brain-status` prints nothing and exits 0, the rule
`oal-agent-hud` follows, because a prompt that complains about an optional feature nobody enabled is
a prompt people turn off. Once one is chosen the prompt's agent line carries it, and says `(down)`
when it is configured but not answering.

`oal-brain-notify` exists so a brain running somewhere else can still reach this screen. It is a
thin name over `oal-brain-do notify` rather than a second route to the notification service: one
enforcement point, two spellings. A shortcut would be a hole with a friendly name.

## The resident service

`oal-brain.service` (user), **not enabled, and nothing in this distribution enables it**:

```bash
oal-brain-backend hermes
systemctl --user enable --now oal-brain.service
```

Backends that answer per invocation need none of this.

An always-on process with tool access, reachable from a chat application, running on a desktop, is a
different threat model from a CLI you launch and watch. That is why `agent/hooks/pretooluse-guard`
(see [agent-guard.md](agent-guard.md)) was built first and why every verb routes through it. The
order matters: shipping the exposure and adding the control afterwards is the version that never
gets revisited.

## Not in scope

Voice, chat-platform gateways, and multi-machine brains. Those are backend features. If a backend
has them they work, and this contract neither requires nor reimplements them.
