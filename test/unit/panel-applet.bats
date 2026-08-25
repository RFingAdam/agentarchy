#!/usr/bin/env bats
#
# The agent applet. Everything else in the agent layer needs a terminal or a keystroke to be seen;
# this is the one that is simply on the panel, which is the difference between a distribution that
# has an agent and one that is about agents.
#
# The failure this suite exists for: the applet loaded with no error at all and occupied no width,
# so it was present in the config and invisible on screen.

setup() {
  SRC="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  APPLET="$SRC/default/plasmoids/org.agentarchy.agent"
  export PATH="$SRC/bin:$PATH"
}

@test "the package metadata is the shape Plasma reads" {
  jq -e '.KPackageStructure == "Plasma/Applet"' "$APPLET/metadata.json" >/dev/null
  jq -e '.KPlugin.Id == "org.agentarchy.agent"' "$APPLET/metadata.json" >/dev/null
  jq -e '.KPlugin.Name | length > 0' "$APPLET/metadata.json" >/dev/null
  # The id in the metadata and the directory name have to agree, or Plasma resolves neither.
  [ "$(basename "$APPLET")" = "$(jq -r '.KPlugin.Id' "$APPLET/metadata.json")" ]
}

@test "the main script is where KPackage looks for it" {
  [ -f "$APPLET/contents/ui/main.qml" ]
}

@test "the compact representation states a width it wants" {
  # A panel asks through implicitWidth as well as the Layout hints. With only the Layout attached
  # properties set, this loaded cleanly and took zero width -- no error anywhere, nothing on screen.
  grep -q 'implicitWidth:' "$APPLET/contents/ui/main.qml"
  grep -q 'Layout.minimumWidth:' "$APPLET/contents/ui/main.qml"
}

@test "it reads the same cache the prompt reads, and nothing else" {
  # One source, so the panel and the prompt cannot disagree about what the agent is doing. And the
  # applet runs inside plasmashell: a network call here would stall the whole desktop shell.
  grep -q 'oal-agent-hud --json' "$APPLET/contents/ui/main.qml"
  ! grep -qE 'oal-agent-usage|curl|https?://' "$APPLET/contents/ui/main.qml"
}

@test "both layouts put it on the panel" {
  grep -q 'org.agentarchy.agent' "$SRC/default/layouts/ubuntu.js"
  grep -q 'org.agentarchy.agent' "$SRC/default/layouts/mint.js"
}

@test "the package installs it where Plasma looks, not only under its own tree" {
  # Same shape as the desktop entry that left the dock's first icon dead: a file that exists,
  # is correct, and is not on the path that gives it meaning.
  grep -q 'usr/share/plasma/plasmoids' "$SRC/PKGBUILD"
}

@test "oal-agent-hud --json emits an object carrying the live posture" {
  local out
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$XDG_STATE_HOME" "$HOME"
  oal-agent-hud --refresh >/dev/null 2>&1
  out="$(oal-agent-hud --json)"
  jq -e '.profile | length > 0' <<<"$out" >/dev/null
  jq -e 'has("mcp") and has("brain")' <<<"$out" >/dev/null
}

@test "with no cache at all it is still valid json rather than nothing" {
  # The applet parses this on every tick. Empty output would be a parse error every 30 seconds.
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/empty" HOME="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$XDG_STATE_HOME"
  jq -e 'type == "object"' <<<"$(oal-agent-hud --json)" >/dev/null
}
