# The shortcuts this desktop actually binds, and a click target it actually has.
# Upstream's cheatsheet and its oal-menu-keybindings viewer are both Quickshell
# surfaces that were never vendored, so the old card advertised a key that does
# nothing and opened a command that does not exist.
#
# Real newlines, not a literal \n: the card renders the body as it arrives, and
# elides past three lines.
oal-notification-send -u critical -g  "Two keys worth knowing" \
  $'Super + Space opens the Agentarchy menu.\nSuper + A asks this machine a question.' \
  --exec oal-menu
