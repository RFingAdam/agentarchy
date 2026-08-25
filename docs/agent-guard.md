# The tool-call guard

Every tool call the agent makes passes through `agent/hooks/pretooluse-guard` before it runs. This
is what makes "guarded by default" a property of the operating system rather than advice in a
README, and it is the control that has to exist before anything resident is added (issue #13).

It is not a sandbox. It gates the agent's own tool calls and nothing else: a process the agent
starts is beyond it, and so is anything reached by a path the rules do not describe. Treat it as a
seatbelt, not a cage.

## The three tiers

Rules live in `agent/hooks/rules`, one per line, `tier | tool | pattern`. First match wins, so order
matters and the dangerous rules come first.

| Tier | What happens | For |
|---|---|---|
| `block` | Refused. No override. | Things with no legitimate agent use: recursive deletes of `/`, `mkfs`, writing to a raw block device, a download piped into a shell, reading private keys or `.env` files. |
| `confirm` | Refused unless the call carries a `CONFIRM-<8 hex>` token. | Reversible but expensive or hard to undo: `sudo`, package installs, forced pushes, hard resets, writes under `/etc`. |
| `allow` | Permitted, and recorded. | Explicit exceptions. |

Anything no rule matches takes the default for the active posture, so `oal-agent-profile` is what
decides the general case:

| Posture | Unmatched calls | `confirm` tier |
|---|---|---|
| `untrusted` | confirmed | confirmed |
| `scoped` (default) | allowed | confirmed |
| `trusted` | allowed | allowed |

`block` is never lifted, by any posture or any token. If it were, there would only be one tier.

## Fail closed

Every path that cannot reach a confident decision denies, and says why:

- `jq` missing
- the rule set unreadable, or carrying a tier it does not recognise
- a payload it cannot parse
- a posture that is not one of the three

A guard that allows when it is confused is not a guard. It reports success while the one case it
existed for goes straight through, which is worse than having none, because you stop looking.

## The audit log

Every decision, including the allowed ones, appends to `~/.local/state/oal/claude-audit/YYYY-MM.log`
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
