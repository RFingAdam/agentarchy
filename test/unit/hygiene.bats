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

# --- the README's numbers ---------------------------------------------------------------------
#
# Every count in the README had drifted, because nothing recomputed them: 668 files against 653,
# 302 commands against 342, 83 needing a port against 81, 14 stages against 15. These are the first
# things a sceptical reader checks, and being wrong about them costs more than the numbers are worth.

# readme_number <literal phrase the number precedes>
#
# grep -o rather than sed with a capture: `.*([0-9]+) themes` is greedy, so the leading .* eats all
# but the last digit and 21 comes back as 1. That silently compared the wrong thing rather than
# failing loudly, which is the worst behaviour available to a test.
readme_number() {
  grep -oE "[0-9]+ $1" "$SRC/README.md" | head -1 | grep -oE '^[0-9]+'
}

@test "the README's file and port counts match the vendoring reports" {
  [ "$(readme_number 'files and')" = "$(wc -l < "$SRC/upstream/VENDORED-FILES.txt")" ]
  [ "$(readme_number 'commands still need porting')" = "$(wc -l < "$SRC/upstream/NEEDS-PORT.txt")" ]
}

@test "the README's command count matches what the package actually installs" {
  # oal-dev-* are removed by PKGBUILD, so they are not commands anybody gets.
  local shipped
  shipped="$(find "$SRC/bin" -name 'oal-*' -not -name 'oal-dev-*' | wc -l)"
  [ "$(grep -oE '[0-9]+ `oal-\*` commands' "$SRC/README.md" | grep -oE '^[0-9]+')" = "$shipped" ]
}

@test "the README's theme counts match the themes directory" {
  [ "$(readme_number 'themes ship')" = "$(find "$SRC/themes" -mindepth 1 -maxdepth 1 -type d | wc -l)" ]
  # "2 of them light" wraps across two lines in the README, and grep is line-based, so the phrase to
  # match on is the half that stays put.
  [ "$(readme_number 'of them')" = "$(grep -l 'mode = "light"' "$SRC"/themes/*/colors.toml | wc -l)" ]
  [ "$(grep -oE 'theme engine \([0-9]+\)' "$SRC/README.md" | grep -oE '[0-9]+')" = \
    "$(find "$SRC/bin" -name 'oal-theme-*' | wc -l)" ]
}

@test "the README's stage count matches the golden path" {
  local stages
  stages="$(grep -v '^[[:space:]]*#' "$SRC/test/vm/golden-path" |
    grep -cE '^[[:space:]]*(if ! )?stage [a-z]+ ')"
  [ "$(readme_number 'stages,')" = "$stages" ]
}

@test "the README tells someone how to install this" {
  # It did not, for the entire time the repository was public. The working one-liner existed only as
  # a comment inside oal-bootstrap.sh, where nobody looking to install it would ever read it.
  grep -q 'oal-bootstrap.sh' "$SRC/README.md"
  grep -q 'raw.githubusercontent.com/RFingAdam/agentarchy' "$SRC/README.md"
}

@test "no instruction in the README pipes a download into a shell" {
  # default/guard/rules blocks exactly that pattern when an agent tries it, and recommending it to a
  # person in the same repository would make one of the two theatre.
  #
  # Instructions only: the prose that explains why we do not do it says `curl | bash`, and a test
  # that cannot tell an example from an endorsement would force the explanation to be deleted.
  ! grep -qE '^[[:space:]]*\$?[[:space:]]*curl[^|]*\|[[:space:]]*(sudo )?(ba|z)?sh' "$SRC/README.md"
}
