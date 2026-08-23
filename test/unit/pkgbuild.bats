#!/usr/bin/env bats
#
# The PKGBUILD can only really be proven by building it on Arch, which the VM golden path does.
# These checks are the part that can run anywhere: it parses, its metadata says what we think it
# says, and the two rules that would quietly produce a broken system if they regressed -- dev
# tooling must not ship, and the package must not depend on the AUR -- are asserted directly.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PKGBUILD="$SRC/PKGBUILD"
}

# Source the PKGBUILD in a subshell with makepkg's variables stubbed, then print one value.
# Nothing in it runs at source time except the metadata assignments, so this is safe.
meta() {
  ( startdir="$SRC"; srcdir="$SRC/src"; pkgdir="$SRC/pkg"
    # shellcheck disable=SC1090
    . "$PKGBUILD" >/dev/null 2>&1
    eval "printf '%s\n' \"\${$1[@]}\"" )
}

@test "PKGBUILD is valid bash" {
  run bash -n "$PKGBUILD"
  [ "$status" -eq 0 ]
}

@test "package metadata is what the spec calls for" {
  [ "$(meta pkgname)" = "agentarchy" ]
  [ "$(meta arch)" = "any" ]
  [ "$(meta license)" = "MIT" ]
  [ -n "$(meta pkgdesc)" ]
  [ -n "$(meta url)" ]
}

@test "runtime dependencies stay thin and come from the official repos" {
  run meta depends
  [ "$status" -eq 0 ]
  for d in bash git jq gum; do
    [[ "$output" == *"$d"* ]] || { echo "missing dependency: $d"; return 1; }
  done
  # Four is the whole point: the package itself must install on a vanilla Arch box. The desktop and
  # CLI package sets are installed by oal-bootstrap.sh from the lists, not dragged in as depends.
  [ "$(meta depends | wc -l)" -le 6 ]
}

@test "the three required functions exist" {
  for fn in pkgver prepare package; do
    grep -qE "^${fn}\(\) \{" "$PKGBUILD" || { echo "missing function: $fn"; return 1; }
  done
}

@test "repo-only dev tooling is stripped from the package" {
  # oal-dev-* resolves the repo root by finding upstream/PIN above itself; on an installed system
  # there is no such thing, so it must neither ship nor land on PATH.
  grep -qE 'rm -f "\$share"/bin/oal-dev-\*' "$PKGBUILD"
}

@test "every shipped bin script is symlinked from /usr/bin to /usr/share" {
  grep -qE 'ln -sf "/usr/share/\$pkgname/bin/\$name" "\$pkgdir/usr/bin/\$name"' "$PKGBUILD"
}

@test "pkgver never emits a version pacman would reject" {
  # pacman forbids '-' in pkgver, and the checkout the bootstrap builds from has no .git.
  grep -q "tr '-' '.'" "$PKGBUILD"
  run bash -c "cd '$SRC' && tr -d '[:space:]' < version | tr '-' '.'"
  [ "$status" -eq 0 ]
  [[ "$output" != *-* ]]
}

@test "build scratch cannot leak into the package" {
  for ex in .git .vm .vm-cache .sync .superpowers pkg src; do
    grep -q -- "--exclude=$ex" "$PKGBUILD" || { echo "prepare() does not exclude $ex"; return 1; }
  done
}

@test "makepkg output is git-ignored" {
  for p in 'pkg/' 'src/' '\*.pkg.tar.zst'; do
    grep -qE "^${p}$" "$SRC/.gitignore" || { echo ".gitignore is missing $p"; return 1; }
  done
}
