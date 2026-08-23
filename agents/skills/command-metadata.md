# Command Metadata

Read this before adding or changing commands in `bin/`.

Commands in `bin/` can declare CLI metadata in comments near the top of the
file. `bin/oal` scans the first 80 lines, and tests expect command metadata
to remain valid.

Supported metadata keys:

- `# oal:group=...` - override the command group inferred from the filename
- `# oal:name=...` - override the command name inferred from the filename
- `# oal:summary=...` - short help text
- `# oal:args=...` - usage arguments
- `# oal:examples=...` - examples separated with ` | `
- `# oal:alias=...` / `# oal:aliases=...` - alternate routes
- `# oal:hidden=true` - hide from default command listings
- `# oal:requires-sudo=true` - mark commands that require sudo

Only use `oal:examples` where there are args that need explaining.

Prefer explicit metadata for user-facing commands. Keep routes consistent with
the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# oal:summary=Take a screenshot
# oal:args=[smart|region|windows|fullscreen] [slurp|copy]
# oal:examples=oal screenshot | oal capture screenshot region
```
