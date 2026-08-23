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
  # Same reasoning for the patches: the real repo's patches target real vendored files, none of
  # which exist in this mini fixture, so carrying them in would fail every apply on a patch the
  # test never asked for. The patch tests below create the ones they need.
  rm -f "$REPO/upstream/patches"/*.patch
  export OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache"
  export OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
  "$REPO/test/fixtures/build-upstream-mini-tarball.sh" "$OAL_UPSTREAM_TARBALL"
  PATH="$REPO/bin:$PATH"
  cd "$REPO"
  oal-dev-sync-upstream --apply
}

@test "a hand edit captured as a patch makes --check pass and survives re-apply" {
  echo '# agentarchy: local tweak' >> default/bash/aliases
  run oal-dev-upstream-patch tweak-aliases default/bash/aliases
  [ "$status" -eq 0 ]
  [ -f upstream/patches/0001-tweak-aliases.patch ]
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
  oal-dev-sync-upstream --apply
  grep -q '^# agentarchy: local tweak' default/bash/aliases
}

@test "second patch gets the next number and both survive re-apply" {
  echo '# agentarchy: local tweak' >> default/bash/aliases
  oal-dev-upstream-patch one default/bash/aliases
  sed -i 's/"label": "Lock"/"label": "Lock screen"/' default/oal/oal-menu.jsonc
  run oal-dev-upstream-patch two default/oal/oal-menu.jsonc
  [ "$status" -eq 0 ]
  [ -f upstream/patches/0001-one.patch ]
  [ -f upstream/patches/0002-two.patch ]
  run oal-dev-sync-upstream --check
  [ "$status" -eq 0 ]
  oal-dev-sync-upstream --apply
  grep -q '^# agentarchy: local tweak' default/bash/aliases
  grep -q '"label": "Lock screen"' default/oal/oal-menu.jsonc
}

@test "refuses to capture a patch for a file that is not vendored" {
  mkdir -p bin; echo 'echo native' > bin/oal-native; chmod +x bin/oal-native
  run oal-dev-upstream-patch native bin/oal-native
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a vendored file"* ]]
  [ ! -e upstream/patches/0001-native.patch ]
}
