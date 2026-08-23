# upstream/patches

Numbered `NNNN-<name>.patch` files applied (in order, `patch -p1`) on top of the renamed upstream tree by
`bin/oal-dev-sync-upstream`. Never hand-edit vendored files without capturing the change here:

    # edit the vendored file, then
    bin/oal-dev-upstream-patch <kebab-name> <file>...

CI runs `oal-dev-sync-upstream --check`; uncaptured edits fail the build. When bumping `upstream/PIN`, re-run
`--apply`; a patch that no longer applies must be regenerated (delete it, re-do the edit, re-capture).

Patches are applied with `patch -p1 -F0`: **fuzz is disabled**. A patch that would only land by
ignoring context lines is a patch whose context has drifted under it, so the sync dies instead of
applying it in a place nobody chose. Regenerate it (delete the file, redo the edit on the vendored
file, re-run `bin/oal-dev-upstream-patch`) rather than loosening the tolerance.
