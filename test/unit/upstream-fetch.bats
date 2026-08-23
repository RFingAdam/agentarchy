#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_DEV_CACHE="$BATS_TEST_TMPDIR/cache"
  export OAL_UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
  "$REPO/test/fixtures/build-upstream-mini-tarball.sh" "$OAL_UPSTREAM_TARBALL"
  PATH="$REPO/bin:$PATH"
}

@test "fetch extracts the pinned tarball into the cache and prints the tree path" {
  run oal-dev-upstream-fetch --print
  [ "$status" -eq 0 ]
  [ -f "$output/bin/omarchy-theme-set" ]
  [[ "$output" == "$OAL_DEV_CACHE/upstream/2c247e390e357ae0fee3f8565b0c816adb705e6a" ]]
}

@test "second fetch is a cache hit and does not re-extract" {
  oal-dev-upstream-fetch --print >/dev/null
  touch "$OAL_DEV_CACHE/upstream/2c247e390e357ae0fee3f8565b0c816adb705e6a/MARKER"
  run oal-dev-upstream-fetch --print
  [ "$status" -eq 0 ]
  [ -f "$output/MARKER" ]
}

@test "fails clearly when PIN is missing" {
  run env OAL_PIN_FILE="$BATS_TEST_TMPDIR/nope" oal-dev-upstream-fetch --print
  [ "$status" -ne 0 ]
  [[ "$output" == *"upstream/PIN"* ]]
}

@test "fails clearly when upstream/REPO is malformed" {
  echo 'not a slug' > "$BATS_TEST_TMPDIR/REPO"
  run env -u OAL_UPSTREAM_TARBALL OAL_UPSTREAM_REPO_FILE="$BATS_TEST_TMPDIR/REPO" oal-dev-upstream-fetch --print
  [ "$status" -ne 0 ]
  [[ "$output" == *"upstream/REPO"* ]]
}
