#!/usr/bin/env bats

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REPO="$BATS_TEST_TMPDIR/repo"; mkdir -p "$REPO"
  cp -a "$SRC/bin" "$SRC/upstream" "$SRC/test" "$REPO/"
  export OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache"
  export OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
  "$REPO/test/fixtures/build-upstream-mini-tarball.sh" "$OAL_UPSTREAM_TARBALL"
  PATH="$REPO/bin:$PATH"
  cd "$REPO"
  oal-dev-sync-upstream --apply
}

@test "a hand edit captured as a patch makes --check pass and survives re-apply" {
  sed -i 's/^hyprland$/# removed: hyprland/' install/oal-base.packages
  run oal-dev-upstream-patch drop-hyprland install/oal-base.packages
  [ "$status" -eq 0 ]
  [ -f upstream/patches/0001-drop-hyprland.patch ]
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
  oal-dev-sync-upstream --apply
  grep -q '^# removed: hyprland' install/oal-base.packages
}

@test "second patch gets the next number and both survive re-apply" {
  sed -i 's/^hyprland$/# removed: hyprland/' install/oal-base.packages
  oal-dev-upstream-patch one install/oal-base.packages
  sed -i 's/"label": "Lock"/"label": "Lock screen"/' default/oal/oal-menu.jsonc
  run oal-dev-upstream-patch two default/oal/oal-menu.jsonc
  [ "$status" -eq 0 ]
  [ -f upstream/patches/0001-one.patch ]
  [ -f upstream/patches/0002-two.patch ]
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
  oal-dev-sync-upstream --apply
  grep -q '^# removed: hyprland' install/oal-base.packages
  grep -q '"label": "Lock screen"' default/oal/oal-menu.jsonc
}

@test "refuses to capture a patch for a file that is not vendored" {
  mkdir -p bin; echo 'echo native' > bin/oal-native; chmod +x bin/oal-native
  run oal-dev-upstream-patch native bin/oal-native
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a vendored file"* ]]
  [ ! -e upstream/patches/0001-native.patch ]
}
