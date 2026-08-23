# Agentarchy

**Omarchy's taste. Your mouse. Your agents.**

Agentarchy is an Arch Linux distribution derived from [Omarchy](https://omarchy.org): the same
palette-driven themes, system menu, update/migration tooling and offline ISO — on a **KDE Plasma 6**
desktop you can drive with a mouse (Ubuntu-style or Mint-style layout, your pick), with a
**Claude Code / agentic engineering runtime** ready at first login.

> Status: pre-alpha. Nothing here is installable yet. Follow `tasks/todo.md` for progress.

## Why the commands are called `oal-*`

Opinions are like… — everyone's got one. Omarchy is proudly opinionated; so are we, just
differently. Every Agentarchy command starts with `oal-` (`oal-theme-set`, `oal-menu`,
`oal-update`). Config lives in `~/.config/oal`, state in `~/.local/state/oal`.

## Relationship to Omarchy

Agentarchy vendors the desktop-agnostic parts of Omarchy (quattro branch, pinned in
`upstream/PIN`) and replaces the Hyprland/Quickshell shell with KDE Plasma. It is an
independent project, not affiliated with or endorsed by Basecamp or DHH. See `NOTICE`.

## Layout

| Path | What |
|---|---|
| `bin/` | `oal-*` commands (vendored + native) |
| `install/` | system/user install steps run by `oal-apply-system` / `oal-provision-user` |
| `default/`, `config/` | system-wide and per-user defaults |
| `themes/` | colour themes (`colors.toml` + assets) |
| `upstream/` | upstream pin, vendor manifest, rename map, patches |
| `test/` | bats unit tests and the VM golden path |
| `docs/superpowers/` | design spec and per-phase implementation plans |

## Developing

```
bin/oal-dev-check          # shellcheck + bats + hygiene gates (what CI runs)
bin/oal-dev-sync-upstream  # re-vendor from upstream/PIN, show diff
```

## Licence

MIT. Derived work attribution in `NOTICE`.
