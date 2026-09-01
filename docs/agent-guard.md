# The tool-call guard

## Where it lives, and why that changed

| | |
|---|---|
| `default/guard/lib.sh` | the decision engine. Sourced, names no runtime, needs no `jq` |
| `default/guard/rules` | the policy. `tier \| tool \| pattern` |
| `agent/hooks/pretooluse-guard` | Claude Code's PreToolUse hook: parse its payload, ask the engine, answer in its shape |
| `bin/oal-guard` | a plain command for everything else, and for people |
| `bin/oal-brain-do` | sources the engine directly, no fork |

This used to be one file, shaped like Claude Code's hook API, with the rules beside it and the audit
log named after it. That made the distribution's strongest claim its least portable piece: run
Codex, or a local Hermes, and **nothing on the machine was gated at all**, while the README said a
permission posture was enforced at the tool-call boundary.

The policy was never vendor-specific. Only the wiring was. `test/unit/guard-neutral.bats` holds the
split open: it fails if the engine so much as names a runtime, and it asserts that the hook and
`oal-guard` reach the same verdict for the same call.

The engine is **sourced rather than forked**. An adapter that shelled out would pay a process on
every tool call, against a 50 ms budget that everything the agent does is charged.

## Asking it yourself

```bash
echo "sudo pacman -Syu" | oal-guard --tool Bash
# ask	confirm	needs confirmation, or a token from oal-guard-confirm in the call
```

Exit code carries the decision: `0` allow, `1` ask, `2` deny. **Anything else means the guard itself
failed and must be treated as a refusal** -- the one thing worse than a guard that breaks is a
caller that reads the breakage as permission.

## Adding a runtime

Write an adapter that parses its hook payload, calls `guard_decide <runtime> <tool> <input>`, and
answers in that runtime's shape. Pass a runtime name; it lands in the audit log, which is one file
for the whole machine rather than one per agent, because the question people actually have is *what
did anything on this machine try to do*.

If a runtime has no hook mechanism at all, it cannot be gated this way and should be said so out
loud rather than implied to be covered.


Every tool call the agent makes passes through `agent/hooks/pretooluse-guard` before it runs. This
is what makes "guarded by default" a property of the operating system rather than advice in a
README, and it is the control that has to exist before anything resident is added (issue #13).

It is not a sandbox. It gates the agent's own tool calls and nothing else: a process the agent
starts is beyond it, and so is anything reached by a path the rules do not describe. Treat it as a
seatbelt, not a cage.

## The three tiers

Rules live in `default/guard/rules`, one per line, `tier | tool | pattern`. First match wins, so order
matters and the dangerous rules come first.

| Tier | What happens | For |
|---|---|---|
| `block` | Refused. No override. | Things with no legitimate agent use: recursive deletes of `/`, `mkfs`, writing to a raw block device, a download piped into a shell, reading private keys or `.env` files. |
| `confirm` | Refused unless the call carries a token minted by a person (see below). | Reversible but expensive or hard to undo: `sudo`, package installs, forced pushes, hard resets, writes under `/etc`, editing a runtime's settings file. |
| `allow` | Permitted, and recorded. | Explicit exceptions. |

Anything no rule matches takes the default for the active posture, so `oal-agent-profile` is what
decides the general case:

| Posture | Unmatched calls | `confirm` tier |
|---|---|---|
| `untrusted` | confirmed | confirmed |
| `scoped` (default) | allowed | confirmed |
| `trusted` | allowed | allowed |

`block` is never lifted, by any posture or any token. If it were, there would only be one tier.

## The confirmation token

A `confirm` rule holds a call back until a person says yes to that call. The token is how they say
it on a path with no prompt:

```bash
oal-guard-confirm            # at your terminal
# CONFIRM-3f9a21c7
sudo pacman -S ripgrep # CONFIRM-3f9a21c7
```

It is a capability, not a password:

- **Minted by a person.** `oal-guard-confirm` refuses to run without a terminal, and tool calls to
  it are themselves a `block` rule -- so an agent asking for one is refused before it runs.
- **Spent once.** The guard deletes it as it accepts it. A call a `block` rule refuses does not
  spend it, because a token burned on a call that was never going to run is one you have to mint
  again to learn nothing changed.
- **Expiring.** Five minutes by default, `--ttl` to change it, one hour maximum.

It used to be any string matching `CONFIRM-<8 hex>`, checked by regex against the same text the
agent had just written -- so the party being gated could mint its own, and the shape was published
here, in the README and in the test suite. That is a spelling convention, not a control.

The rules that keep it that way are the first four in `default/guard/rules`: the posture command,
this command, the guard's own state directory, and settings files under a dotted directory in
`$HOME`. Every other rule in the file is optional if any of those can be reached, because raising
the posture to `trusted` turns each `confirm` into an `allow`.

## Fail closed

Every path that cannot reach a confident decision denies, and says why:

- `jq` missing
- the rule set unreadable, or carrying a tier it does not recognise
- a payload it cannot parse
- a posture that is not one of the three

A guard that allows when it is confused is not a guard. It reports success while the one case it
existed for goes straight through, which is worse than having none, because you stop looking.

## The audit log

Every decision, including the allowed ones, appends to `~/.local/state/oal/audit/YYYY-MM.log`
as tab-separated `timestamp, decision, tier, tool, reason, pattern`.

The matched pattern goes in the log and never in the decision returned to the agent. Reasons are
interpolated into a JSON string and the patterns are regexes full of backslashes; putting one in a
reason produced output the runtime could not parse, which is the most confusing way available for a
guard to fail open.

## Adding a rule

Prefer `confirm` over `block`. A block with no override is a wall that someone eventually routes
around by turning the hook off entirely, and then nothing is guarded at all. Reserve `block` for
what has no legitimate agent use.

Test what you add. `test/unit/agent-guard.bats` covers each tier, every fail-closed path, the audit
log, and a 50 ms budget: the guard runs before every tool call, so its cost is paid by everything
the agent does. The first version cost 334 ms, because it forked `jq` twice and then `grep`, `sed`
and `xargs` once per rule.

Patterns in that suite are assembled from pieces rather than written out. A test file containing a
literal recursive delete of `/` trips every other guard on the machine, including the one belonging
to whoever is writing it.
