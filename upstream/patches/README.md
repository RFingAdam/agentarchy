# upstream/patches

Numbered `NNNN-<name>.patch` files applied (in order, `patch -p1`) on top of the renamed upstream tree by
`bin/oal-dev-sync-upstream`. Never hand-edit vendored files without capturing the change here:

    # edit the vendored file, then
    bin/oal-dev-upstream-patch <kebab-name> <file>...

CI runs `oal-dev-sync-upstream --check`; uncaptured edits fail the build. When bumping `upstream/PIN`, re-run
`--apply`; a patch that no longer applies must be regenerated (delete it, re-do the edit, re-capture).
