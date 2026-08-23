#!/usr/bin/env bats

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REPO="$BATS_TEST_TMPDIR/repo"; mkdir -p "$REPO"
  cp -a "$SRC/bin" "$SRC/upstream" "$SRC/NOTICE" "$REPO/"
  mkdir -p "$REPO/themes/t1/backgrounds" "$REPO/docs"
  printf 'x' > "$REPO/themes/t1/backgrounds/1-a.webp"
  printf 'y' > "$REPO/themes/t1/backgrounds/2-b.jpg"
  PATH="$REPO/bin:$PATH"
  cd "$REPO"; git init -q
  git config user.email test@test.local
  git config user.name test
}

@test "notice-check --update lists every background as UNAUDITED and then passes" {
  run oal-dev-notice-check
  [ "$status" -eq 1 ]
  oal-dev-notice-check --update
  grep -q 'themes/t1/backgrounds/1-a.webp | UNAUDITED' NOTICE
  grep -q 'themes/t1/backgrounds/2-b.jpg | UNAUDITED' NOTICE
  run oal-dev-notice-check
  [ "$status" -eq 0 ]
}

@test "notice-check --strict fails while any file is UNAUDITED" {
  oal-dev-notice-check --update
  run oal-dev-notice-check --strict
  [ "$status" -eq 1 ]
  sed -i 's#themes/t1/backgrounds/1-a.webp | UNAUDITED#themes/t1/backgrounds/1-a.webp | CC0 | https://example.org/a#' NOTICE
  sed -i 's#themes/t1/backgrounds/2-b.jpg | UNAUDITED#themes/t1/backgrounds/2-b.jpg | CC0 | https://example.org/b#' NOTICE
  run oal-dev-notice-check --strict
  [ "$status" -eq 0 ]
}

@test "branding-check fails on omarchy outside the allowlist and passes inside it, including test/fixtures" {
  mkdir -p bin config test/fixtures/x
  echo 'echo omarchy' > bin/oal-bad
  run oal-dev-branding-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/oal-bad"* ]]
  rm bin/oal-bad
  echo 'omarchy is upstream' > docs/compat.md
  echo 'omarchy' > test/fixtures/x/omarchy.txt
  run oal-dev-branding-check
  [ "$status" -eq 0 ]
}

@test "branding-check also fails on omarchy in tracked file names outside the allowlist" {
  mkdir -p bin test/fixtures/upstream-mini/bin
  touch bin/omarchy-leftover
  touch test/fixtures/upstream-mini/bin/omarchy-x
  git add bin/omarchy-leftover test/fixtures/upstream-mini/bin/omarchy-x
  run oal-dev-branding-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/omarchy-leftover"* ]]
  [[ "$output" != *"test/fixtures/upstream-mini/bin/omarchy-x"* ]]
}
