#!/usr/bin/env bats
#
# Task 4's surface: the parts of a themed desktop a Plasma colour scheme does not reach -- the icon
# set, the lock screen wallpaper, and the SDDM greeter. None of them can be exercised for real
# without a session (or, for the greeter, a boot), so what is pinned here is the decision each one
# encodes: which value gets written, for which theme, to which file.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TPL="$SRC/default/themed/sddm.theme.conf.tpl"
  QML="$SRC/default/sddm/oal/Main.qml"

  # A kwriteconfig6 that records its arguments instead of writing config, so the apply path can be
  # run on a machine with no Plasma at all. Same stub theme-kde.bats uses.
  stub="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub"
  cat >"$stub/kwriteconfig6" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$KWRITE_LOG"
STUB
  chmod +x "$stub/kwriteconfig6"
  KWRITE_LOG="$BATS_TEST_TMPDIR/kwrite.log"
  export KWRITE_LOG

  apply() {
    run env PATH="$stub:/usr/bin:/bin" HOME="$BATS_TEST_TMPDIR/home" KWRITE_LOG="$KWRITE_LOG" \
      OAL_PATH="$SRC" "$SRC/bin/oal-theme-set-kde" "$1"
  }
  render() { env OAL_PATH="$SRC" "$SRC/bin/oal-theme-render" "$@"; }

  # A sudo that records its arguments and runs nothing, so the greeter install path can be exercised
  # without writing to /usr/share. It swallows stdin for the tee case; without that the render
  # pipeline upstream of it takes a broken pipe.
  cat >"$stub/sudo" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SUDO_LOG"
[[ ${1:-} == tee ]] && cat >/dev/null
exit 0
STUB
  chmod +x "$stub/sudo"
  SUDO_LOG="$BATS_TEST_TMPDIR/sudo.log"
  export SUDO_LOG
  refresh() {
    run env -u OAL_PATH PATH="$stub:$SRC/bin:/usr/bin:/bin" HOME="$BATS_TEST_TMPDIR/home" \
      SUDO_LOG="$SUDO_LOG" "$SRC/bin/oal-refresh-sddm" "$@"
  }
}

# --- icons -----------------------------------------------------------------------------------
# Breeze ships two icon sets and the themes' own icons.theme files name Yaru variants that are
# AUR-only on Arch, so mode is what decides. Getting this wrong is the one miss that still reads as
# the wrong desktop after every colour is right.

@test "a dark theme gets the dark icon set" {
  apply tokyo-night
  [ "$status" -eq 0 ]
  grep -qx -- '--file kdeglobals --group Icons --key Theme breeze-dark' "$KWRITE_LOG"
}

@test "a light theme gets the light icon set" {
  apply catppuccin-latte
  [ "$status" -eq 0 ]
  grep -qx -- '--file kdeglobals --group Icons --key Theme breeze' "$KWRITE_LOG"
}

@test "every theme resolves to one of the two icon sets" {
  for dir in "$SRC"/themes/*/; do
    mode="$(env OAL_PATH="$SRC" "$SRC/bin/oal-theme-color" --file "$dir/colors.toml" mode)"
    [[ $mode == light || $mode == dark ]] || { echo "$(basename "$dir"): mode='$mode'"; return 1; }
  done
}

# --- lock screen -----------------------------------------------------------------------------

@test "the lock screen wallpaper is written to kscreenlockerrc" {
  apply tokyo-night
  [ "$status" -eq 0 ]
  line="$(grep -- '--file kscreenlockerrc' "$KWRITE_LOG")"
  [[ $line == *"--group Greeter --group Wallpaper --group org.kde.image --group General --key Image "* ]]
  # The value has to be a file that exists, not just a plausible path: a lock screen pointed at a
  # missing image renders black, which looks exactly like a theme that did not apply.
  [ -f "${line##* }" ]
  [[ $output == *"lock screen wallpaper set to"* ]]
}

@test "every theme ships a background the lock screen can point at" {
  for dir in "$SRC"/themes/*/; do
    found="$(find -L "$dir/backgrounds" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | head -1)"
    [[ -n $found ]] || { echo "$(basename "$dir") ships no background"; return 1; }
  done
}

# --- greeter ---------------------------------------------------------------------------------

@test "the greeter palette renders for every theme" {
  for dir in "$SRC"/themes/*/; do
    out="$(render sddm.theme.conf --file "$dir/colors.toml")" ||
      { echo "$(basename "$dir") failed to render"; return 1; }
    [[ $out != *"{{"* ]] || { echo "$(basename "$dir") left a placeholder"; return 1; }
    [[ $out == *"[General]"* ]]
  done
}

@test "the greeter palette carries the mode, not just colours" {
  [[ "$(render sddm.theme.conf --file "$SRC/themes/tokyo-night/colors.toml")" == *"mode=dark"* ]]
  [[ "$(render sddm.theme.conf --file "$SRC/themes/catppuccin-latte/colors.toml")" == *"mode=light"* ]]
}

@test "every colour the greeter reads is one the template writes" {
  # SDDM hands theme.conf's [General] keys to the QML as config.<key>. A name that does not match
  # is not an error there -- it silently evaluates empty -- so the two files have to be compared
  # somewhere, and this is the only place that can.
  keys="$(grep -oE '^[a-z_]+=' "$TPL" | tr -d '=' | sort -u)"
  for used in $(grep -oE 'config\.[a-z_]+' "$QML" | cut -d. -f2 | sort -u); do
    grep -qx "$used" <<<"$keys" || { echo "Main.qml reads config.$used, which $TPL never writes"; return 1; }
  done
}

@test "every colour the greeter reads has a literal fallback" {
  # The greeter is the one screen that must render with no configuration at all: the alternative is
  # a machine nobody can log into. Every config.<key> must be followed by a || default.
  while IFS= read -r line; do
    [[ $line == *"config."*"||"* ]] || { echo "no fallback: $line"; return 1; }
  done < <(grep -n 'config\.' "$QML" | grep -v '^\s*//' | grep -v '// ')
}

@test "the greeter ships no image assets at all" {
  # It used to ship six: five upstream sprites in one hard-coded colour with no recorded licence,
  # and a white wordmark PNG. Every one is drawn from the palette now, so anything with an image
  # extension in this directory is either a regression or a PIN bump quietly reinstating one.
  run find "$SRC/default/sddm/oal" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.svg' -o -iname '*.webp' \)
  [ -z "$output" ] || { echo "image assets in the greeter: $output"; return 1; }
}

# --- the hook ---------------------------------------------------------------------------------

@test "a theme change reaches KDE" {
  # Without this line oal-theme-set retints the terminals and the editors and leaves the desktop,
  # the icons and the lock screen on the previous theme. It is the whole point of patch 0012.
  grep -q 'oal-theme-set-kde \$THEME_NAME' "$SRC/bin/oal-theme-set"
}

@test "the theme hooks name no command this tree does not have" {
  while IFS= read -r cmd; do
    [ -f "$SRC/bin/$cmd" ] || { echo "post_theme_commands names $cmd, which does not exist"; return 1; }
  done < <(sed -n '/^post_theme_commands=(/,/^)/p' "$SRC/bin/oal-theme-set" |
    grep -oE '^\s+"?oal-[a-z-]+' | tr -d ' "')
}

@test "the greeter is named as the one surface a theme switch cannot reach" {
  apply tokyo-night
  [ "$status" -eq 0 ]
  [[ $output == *"oal-refresh-sddm"* ]]
}


# --- the install path -------------------------------------------------------------------------

@test "the greeter install works with no OAL_PATH in the environment" {
  # oal-bootstrap.sh runs this before /etc/profile.d/oal.sh has been sourced into any shell, so
  # OAL_PATH is not exported yet. Upstream's bare "$OAL_PATH" would make the copy read /default/...
  # and, under the bootstrap's set -e, end the install there.
  refresh tokyo-night
  [ "$status" -eq 0 ]
  copy="$(grep -- '^cp -r ' "$SUDO_LOG")"
  [[ $copy == *"$SRC/default/sddm/oal /usr/share/sddm/themes/oal"* ]]
}

@test "the greeter install renders the named theme's palette" {
  refresh catppuccin-latte
  [ "$status" -eq 0 ]
  grep -q -- '^tee /usr/share/sddm/themes/oal/theme.conf$' "$SUDO_LOG"
  [[ $output == *"greeter palette: catppuccin-latte"* ]]
}

@test "the greeter install refuses a theme it cannot find" {
  refresh no-such-theme
  [ "$status" -ne 0 ]
  [[ $output == *"no colors.toml"* ]]
}

@test "the greeter install with no theme leaves the shipped palette alone" {
  refresh
  [ "$status" -eq 0 ]
  ! grep -q -- '^tee ' "$SUDO_LOG"
}
