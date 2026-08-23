// Phase 3 starting point: the layout Adam picked on 2026-08-23.
//
// A throwaway spike, not the deliverable. It was pushed into a running session with
//   qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat this-file)"
// to answer one question -- top bar plus dock, or the stock taskbar -- with two screenshots
// instead of two adjectives. Adam chose this one as the DEFAULT; the stock taskbar stays as the
// second preset (`mint`), so both still ship.
//
// What Phase 3 has to do that this does not:
//   * ship it as a Look-and-Feel package (org.oal.ubuntu) applied by `oal-layout-set`, not as a
//     script that mutates whatever the user has arranged
//   * size the dock properly (60 px with default icons is too tight) and decide floating vs docked
//   * decide what else belongs in the top bar (window title? global menu? both need applets that
//     are not installed today) and whether the launcher stays kickoff
//   * answer window switching, since a dock of launchers replaces the task list: overview shortcut,
//     Alt+Tab defaults, or an icons-only task manager in the top bar
//   * survive a second run -- this removes every panel first, which is correct for a preset apply
//     and destructive if someone has customised theirs
// Ubuntu/macOS silhouette: one thin top panel for status, one floating dock for launchers.
panels().forEach(function (p) { p.remove(); });

var top = new Panel;
top.location = "top";
top.height = 28;
top.hiding = "none";
top.addWidget("org.kde.plasma.kickoff");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");
top.addWidget("org.kde.plasma.digitalclock");
top.addWidget("org.kde.plasma.showdesktop");

var dock = new Panel;
dock.location = "bottom";
dock.height = 60;
dock.hiding = "none";
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
  "applications:org.kde.konsole.desktop",
  "applications:org.kde.dolphin.desktop",
  "applications:org.kde.kate.desktop",
  "applications:org.kde.spectacle.desktop",
  "applications:systemsettings.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.reloadConfig();
