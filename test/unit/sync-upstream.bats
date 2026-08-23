#!/usr/bin/env bats

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # Work on a throwaway copy of the repo so --apply cannot touch the real tree.
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cp -a "$SRC/bin" "$SRC/upstream" "$SRC/test" "$REPO/"
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
  # Upstream URLs are rewritten before the bare-word rules (which would yield oal.org).
  run cat default/bash/aliases
  [[ "$output" == *'https://github.com/RFingAdam/agentarchy/tree/main/docs'* ]]
  [[ "$output" == *'echo "see https://github.com/RFingAdam/agentarchy"'* ]]
  [[ "$output" != *'https://github.com/RFingAdam/agentarchy/install'* ]]
  [[ "$output" != *omarchy* ]]
}

@test "apply excludes compositor-bound bin scripts and records them" {
  oal-dev-sync-upstream --apply
  [ ! -e bin/oal-hyprland-focus ]
  grep -q '^bin/omarchy-hyprland-focus' upstream/EXCLUDED-BIN.txt
}

@test "apply keeps soft-dependent scripts but lists them in NEEDS-PORT" {
  oal-dev-sync-upstream --apply
  [ -f bin/oal-system-reboot ]
  grep -q '^bin/oal-system-reboot' upstream/NEEDS-PORT.txt
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
