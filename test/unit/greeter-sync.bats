#!/usr/bin/env bats
#
# oal-greeter-sync renders the login screen's palette on the way up, for the install paths that
# never run oal-bootstrap.sh. Two properties carry the design:
#
#   it renders when nobody has, and
#   it keeps its hands off a palette somebody rendered on purpose.
#
# The second is what stops a reboot from silently undoing `oal-refresh-sddm <theme>`.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export OAL_PATH="$SRC"
  export PATH="$SRC/bin:$PATH"

  # oal-greeter-sync writes to /usr/share/sddm, which a test must not. Run it against a copy whose
  # paths point into the temp directory instead.
  ROOT="$BATS_TEST_TMPDIR/root"
  INSTALLED="$ROOT/usr/share/sddm/themes/oal"
  SYNC="$BATS_TEST_TMPDIR/oal-greeter-sync"
  sed "s#^installed=/usr/share/sddm/themes/oal\$#installed=$INSTALLED#" \
    "$SRC/bin/oal-greeter-sync" >"$SYNC"
  chmod +x "$SYNC"

  CONF="$INSTALLED/theme.conf"
}

@test "the default theme is one slug, and it names a theme that exists" {
  run oal-theme-default
  [ "$status" -eq 0 ]
  [ "$(wc -l <<<"$output")" -eq 1 ]
  [ -f "$SRC/themes/$output/colors.toml" ]
}

@test "a greeter nobody has rendered gets the default palette" {
  run "$SYNC"
  [ "$status" -eq 0 ]
  grep -q '^background=' "$CONF"

  # The value, not just the key: naming a colour is not applying one, which is the lesson the whole
  # theme suite exists because of.
  local slug want
  slug="$(oal-theme-default)"
  want="$(oal-theme-color --file "$SRC/themes/$slug/colors.toml" background)"
  grep -qx "background=$want" "$CONF"
}

@test "the theme directory is copied when the install did not copy it" {
  [ ! -d "$INSTALLED" ]
  run "$SYNC"
  [ -f "$INSTALLED/Main.qml" ]
}

@test "a named theme wins over the default" {
  run "$SYNC" gruvbox
  [ "$status" -eq 0 ]
  local want
  want="$(oal-theme-color --file "$SRC/themes/gruvbox/colors.toml" background)"
  grep -qx "background=$want" "$CONF"
}

@test "a palette rendered on purpose survives the next boot" {
  # What oal-refresh-sddm leaves behind. A second run must not reach for the default and undo it.
  "$SYNC" gruvbox
  local before
  before="$(cat "$CONF")"
  run "$SYNC"
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "$before" ]
}

@test "running twice over changes nothing the first run did not do" {
  "$SYNC"
  local first
  first="$(cat "$CONF")"
  run "$SYNC"
  [ "$(cat "$CONF")" = "$first" ]
}

@test "a theme that does not exist leaves the greeter renderable rather than failing the boot" {
  run "$SYNC" no-such-theme
  # Exit 0 on purpose: this is ordered ahead of the display manager, and Main.qml's literal
  # fallbacks are a working login screen. Going red here would be the worse outcome.
  [ "$status" -eq 0 ]
  [[ $output == *"no-such-theme"* ]]
  # The shipped file is left as it was, with no keys, so Main.qml uses its fallbacks.
  ! grep -q '^background=' "$CONF"
}

@test "no half-written palette is left behind when the render fails" {
  run "$SYNC" no-such-theme
  [ ! -e "$CONF.new" ]
}

@test "the unit is ordered before the display manager and cannot fail it" {
  local unit="$SRC/install/desktop/oal-greeter-sync.service"
  grep -qx 'Before=display-manager.service' "$unit"
  grep -qx 'Type=oneshot' "$unit"
  # Nothing in the unit may make the display manager depend on this one.
  ! grep -qE '^(Requires|BindsTo|Requisite)=' "$unit"
}
