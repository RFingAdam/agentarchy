# Overlays

Agentarchy ships a mechanism and a small vendor-neutral catalog. An **overlay** is where the rest of
your setup lives: MCP servers that are private, licence-gated or bound to hardware sitting on your
bench, and anything else that belongs to a person rather than to a distribution.

The split matters. Nothing in an overlay needs a change to this repository, and no server name from
one ever appears in it. A public catalog file listing private tooling publishes the shape of that
tooling (what exists, what it is for, and that you have it) even when the code stays private.

```bash
oal-overlay-apply ~/work/my-overlay
oal-overlay-apply git@github.com:you/oal-overlay.git
oal-overlay-apply git@github.com:you/oal-overlay.git --refresh
```

## What an overlay is

A directory, usually a private git repository. `oal-overlay-apply` reads `*.catalog` at the top
level or under `mcp/`, and hands each to `oal-mcp-import`.

`docs/examples/overlay-example/` has a worked catalog. Every server in it is fictional, deliberately:
an example built from a real private catalog with the URLs removed still gives away most of what you
were keeping private.

## It is applied, not executed

`oal-overlay-apply` reads files it knows and acts on them. **It does not run anything the overlay
contains**, and it will not handle secrets.

That is a deliberate limit, not an unfinished feature. Cloning a repository and running a script out
of it is exactly the shape `default/guard/rules` refuses when an agent tries it, and shipping a guard
against downloaded code while offering a command that does precisely that would be incoherent. If
your overlay carries an `apply.sh`, the command tells you it is there and leaves it alone. You read
it, then you run it.

## The catalog format

Identical to `default/mcp/CATALOG`, so there is one format to learn:

```
id | kind | package | args | visibility | profiles | description
```

| Field | |
|---|---|
| `id` | what `oal-mcp-install` and `oal-mcp-remove` take |
| `kind` | `uvx` or `npx` |
| `package` | the exact registry name |
| `args` | arguments the server needs, or empty. `$HOME` is the only expansion permitted |
| `visibility` | `public`, `private`, `hardware`, `commercial` |
| `profiles` | comma-separated; what `--profile` matches |
| `description` | one line |

**`visibility` is what makes a mixed catalog usable.** A profile install skips anything not `public`
and says why: a private registry you cannot reach, an instrument that is not on the bench, a licence
you do not hold. Those are facts about the machine, not install errors worth throwing at someone who
asked for a whole profile. Naming such a server explicitly still installs it, because at that point
you know something the catalog does not.

## Where imported servers show up

Everywhere, and always marked. `oal-mcp-list` and `oal-mcp-status` show the catalog each server came
from, so it is never ambiguous which ones this distribution vouches for and which arrived from
somewhere else.

```
oal-mcp-import --list          # which catalogs are imported
oal-mcp-import --forget lab    # stop offering one; registered servers are untouched
oal-mcp-remove sig-gen         # unregister a server
```

`--forget` deliberately does not unregister anything. Removing a catalog and silently tearing down
working servers is the kind of helpfulness that loses people an afternoon.
