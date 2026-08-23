#!/usr/bin/env bats

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REPO="$BATS_TEST_TMPDIR/repo"
  # Work on a throwaway copy so --apply cannot touch the real tree. Only the dev tooling is
  # copied: the repo's own vendored bin/oal-* scripts would otherwise sit in the fixture repo
  # looking like output of the mini fixture's sync, and quietly satisfy assertions.
  mkdir -p "$REPO/bin"
  cp -a "$SRC"/bin/oal-dev-* "$REPO/bin/"
  cp -a "$SRC/upstream" "$SRC/test" "$REPO/"
  rm -f "$REPO/upstream/VENDORED-FILES.txt" "$REPO/upstream/EXCLUDED-BIN.txt" \
        "$REPO/upstream/NEEDS-PORT.txt" "$REPO/upstream/DANGLING.txt"
  export OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache"
  export OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
  "$REPO/test/fixtures/build-upstream-mini-tarball.sh" "$OAL_UPSTREAM_TARBALL"
  PATH="$REPO/bin:$PATH"
  cd "$REPO"
}

@test "apply vendors agnostic files with renamed names and contents" {
  run oal-dev-sync-upstream --apply
  [ "$status" -eq 0 ]
  [ -f bin/oal-theme-set ]
  run cat bin/oal-theme-set
  [[ "$output" == *'$HOME/.config/oal/themes/$1'* ]]
  [[ "$output" == *'$HOME/.local/state/oal/current'* ]]
  [[ "$output" == *'$OAL_PATH/themes/$1'* ]]
  [[ "$output" == *'oal-restart-terminal'* ]]
  [[ "$output" == *'# Agentarchy theme setter'* ]]
  [[ "$output" != *omarchy* ]]
  # Upstream URLs are rewritten before the bare-word rules, which would rewrite the host itself.
  run cat default/bash/aliases
  [[ "$output" == *'https://github.com/RFingAdam/agentarchy/tree/main/docs'* ]]
  [[ "$output" == *'echo "see https://github.com/RFingAdam/agentarchy"'* ]]
  [[ "$output" != *'https://github.com/RFingAdam/agentarchy/install'* ]]
  # Subdomain hosts keep the subdomain but move to the reserved .invalid TLD, so the rename can
  # never forge a resolvable look-alike host. No .org host may survive the rename at all.
  [[ "$output" == *'https://pkgs.agentarchy.invalid/stable'* ]]
  [[ "$output" != *.org* ]]
  # Repo slugs point at ours, not at a fabricated slug under the upstream owner.
  [[ "$output" == *'gh repo fork RFingAdam/agentarchy --clone'* ]]
  [[ "$output" != *'basecamp/'* ]]
  [[ "$output" != *omarchy* ]]
}

@test "apply excludes compositor-bound bin scripts and records them" {
  oal-dev-sync-upstream --apply
  [ ! -e bin/oal-hyprland-focus ]
  grep -q '^bin/omarchy-hyprland-focus$' upstream/EXCLUDED-BIN.txt
}

@test "apply keeps soft-dependent scripts but lists them in NEEDS-PORT" {
  oal-dev-sync-upstream --apply
  [ -f bin/oal-system-reboot ]
  grep -q '^bin/oal-system-reboot$' upstream/NEEDS-PORT.txt
}

@test "apply honours path excludes and renames directories" {
  oal-dev-sync-upstream --apply
  [ ! -e config/hypr ]
  [ ! -e themes/tokyo-night/shell.lock.toml ]
  [ ! -e default/themed/shell.toml.tpl ]
  [ -f default/themed/ghostty.conf.tpl ]
  [ -f default/oal/oal-menu.jsonc ]
  [ ! -e default/omarchy ]
  [ -f install/oal-base.packages ]
  run cat install/config/all.sh
  [[ "$output" == *'$OAL_INSTALL/config/theme-system.sh'* ]]
}

@test "binary assets are copied byte-for-byte (sed skipped)" {
  oal-dev-sync-upstream --apply
  cmp themes/tokyo-night/backgrounds/1-quattro.webp \
      "$OAL_DEV_CACHE/upstream/2c247e390e357ae0fee3f8565b0c816adb705e6a/themes/tokyo-night/backgrounds/1-quattro.webp"
}

@test "check passes right after apply and fails after a hand edit" {
  oal-dev-sync-upstream --apply
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
  echo "# hand edit" >> bin/oal-theme-set
  run oal-dev-sync-upstream --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/oal-theme-set"* ]]
}

@test "native files next to vendored ones survive apply" {
  mkdir -p bin; echo 'echo native' > bin/oal-layout-set; chmod +x bin/oal-layout-set
  oal-dev-sync-upstream --apply
  [ -f bin/oal-layout-set ]
  ! grep -q '^bin/oal-layout-set$' upstream/VENDORED-FILES.txt
  grep -q '^bin/oal-theme-set$' upstream/VENDORED-FILES.txt
}

@test "a file dropped from the manifest is removed on re-apply, and check flags it until then" {
  oal-dev-sync-upstream --apply
  [ -f bin/oal-system-reboot ]
  echo 'exclude bin/omarchy-system-reboot' >> upstream/VENDOR-MANIFEST
  run oal-dev-sync-upstream --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale vendored file: bin/oal-system-reboot"* ]]
  oal-dev-sync-upstream --apply
  [ ! -e bin/oal-system-reboot ]
  ! grep -q '^bin/oal-system-reboot$' upstream/VENDORED-FILES.txt
}

@test "FORCE-INCLUDE-BIN overrides the exclusion regex and lands in NEEDS-PORT" {
  echo omarchy-hyprland-focus >> upstream/FORCE-INCLUDE-BIN
  oal-dev-sync-upstream --apply
  [ -f bin/oal-hyprland-focus ]
  grep -q '^bin/oal-hyprland-focus$' upstream/NEEDS-PORT.txt
  ! grep -q 'omarchy-hyprland-focus' upstream/EXCLUDED-BIN.txt
}

@test "a malformed EXCLUDE-BIN.regex fails loudly instead of vendoring everything" {
  printf 'bad((\n' > upstream/EXCLUDE-BIN.regex
  run oal-dev-sync-upstream --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"EXCLUDE-BIN.regex"* ]]
  [ ! -e bin/oal-theme-set ]
}

@test "a symlink the manifest would vendor is refused, not silently dropped" {
  work="$BATS_TEST_TMPDIR/withlink"
  mkdir -p "$work"
  tar -xzf "$OAL_UPSTREAM_TARBALL" -C "$work"
  top="$(find "$work" -mindepth 1 -maxdepth 1 -type d)"
  ln -s colors.toml "$top/themes/tokyo-night/link.toml"
  tar -C "$work" -czf "$BATS_TEST_TMPDIR/withlink.tar.gz" "$(basename "$top")"
  run env OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/withlink.tar.gz" \
          OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache-link" oal-dev-sync-upstream --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"link.toml"* ]]
  [ ! -e themes/tokyo-night/colors.toml ]
}

@test "check flags a mode change on a vendored file" {
  oal-dev-sync-upstream --apply
  chmod -x bin/oal-theme-set
  run oal-dev-sync-upstream --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"drift: bin/oal-theme-set (mode)"* ]]
}

@test "--stage refuses directories that hold repo content" {
  run oal-dev-sync-upstream --apply --stage "$REPO/"
  [ "$status" -ne 0 ]
  run oal-dev-sync-upstream --apply --stage "$REPO/bin"
  [ "$status" -ne 0 ]
  [ -f bin/oal-dev-sync-upstream ]
  [ -f bin/oal-dev-lib.sh ]
  [ -f upstream/VENDOR-MANIFEST ]
}

@test "the bare omarchy dispatcher is vendored as bin/oal and flagged for porting" {
  oal-dev-sync-upstream --apply
  [ -f bin/oal ]
  [ -x bin/oal ]
  grep -q '^bin/oal$' upstream/VENDORED-FILES.txt
  grep -q '^bin/oal$' upstream/NEEDS-PORT.txt
  ! grep -q 'omarchy' bin/oal
}

@test "DANGLING.txt records vendored files that still call an excluded script" {
  oal-dev-sync-upstream --apply
  grep -qxF 'default/oal/oal-menu.jsonc -> oal-hyprland-focus' upstream/DANGLING.txt
  # A script that is vendored is not a dangling reference. The same menu file names oal-theme-set,
  # so this only holds because the report filters on the excluded-bin list; assert the reference
  # really is there, otherwise the line below passes for the wrong reason.
  grep -q 'oal-theme-set' default/oal/oal-menu.jsonc
  [ -f bin/oal-theme-set ]
  ! grep -q -- '-> oal-theme-set$' upstream/DANGLING.txt
  ! grep -q '^bin/oal-hyprland-focus$' upstream/VENDORED-FILES.txt
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
}

@test "check flags drift in DANGLING.txt like the other reports" {
  oal-dev-sync-upstream --apply
  echo 'bogus/path -> oal-launch-webapp' >> upstream/DANGLING.txt
  run oal-dev-sync-upstream --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"upstream/DANGLING.txt"* ]]
}

@test "apply refuses to overwrite a native file that shares a vendored path" {
  oal-dev-sync-upstream --apply
  # Simulate a native file that happens to sit where the sync wants to write: drop the path from
  # the ownership list, so the next --apply sees a repo file it does not own.
  grep -vxF 'bin/oal-theme-set' upstream/VENDORED-FILES.txt > vf.tmp
  mv vf.tmp upstream/VENDORED-FILES.txt
  before="$(cat bin/oal-theme-set)"
  run oal-dev-sync-upstream --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to overwrite native files"* ]]
  [[ "$output" == *"bin/oal-theme-set"* ]]
  [ "$(cat bin/oal-theme-set)" = "$before" ]
}

@test "a patch that only applies with fuzz is refused" {
  cat > upstream/patches/0001-fuzz.patch <<'PATCH'
--- a/install/oal-base.packages
+++ b/install/oal-base.packages
@@ -1,5 +1,5 @@
 hyprland
 quickshell
-sddm
+sddm-git
 ghostty
 context-that-drifted
PATCH
  run oal-dev-sync-upstream --apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"0001-fuzz.patch"* ]]
  [ ! -e install/oal-base.packages ]
}
