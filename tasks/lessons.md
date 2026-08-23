# Lessons

Format: `## YYYY-MM-DD — <short title>` then **Mistake**, **Why**, **Rule**.

## 2026-08-22 — Name the project seriously, keep jokes in the CLI
**Mistake:** proposed the joke ("Opinions Are Like") as the repo/project name.
**Why:** a public repo needs a name that stands alone; humour belongs in command prefixes/taglines.
**Rule:** propose serious names (check GitHub collisions), keep the joke in `oal-*`.

## 2026-08-23 — Content greps miss filenames
**Mistake:** the first vendoring pass audited only file contents for the upstream name; 31 paths (incl. a Chromium native-messaging manifest) kept it.
**Why:** rename rules and audits were written for text, not paths.
**Rule:** every "no X anywhere" gate checks both content and `git ls-files`; sed-based renames need a path rule and a path audit.
