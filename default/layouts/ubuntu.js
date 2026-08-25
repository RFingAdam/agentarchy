// The default layout: a thin status bar at the top, a floating dock at the bottom.
//
// Applied by bin/oal-layout-set through Plasma's scripting API. Preferred over the stock taskbar,
// which reads as Windows because Windows is where the taskbar paradigm came from.
//
// The dock uses icontasks -- the icons-only task manager -- rather than a launcher widget, because
// it shows running windows alongside the pinned entries. A dock of pure launchers would have taken
// window switching away and left nothing to replace it, which was the open question when this was
// a spike.
//
// Every panel is removed first. That is correct for applying a preset and destructive to a layout
// someone has arranged by hand, which is why oal-layout-set says so before it runs.

panels().forEach(function (p) { p.remove(); });

var top = new Panel();
top.location = "top";
top.height = 30;
top.hiding = "none";
top.addWidget("org.kde.plasma.kickoff");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");
top.addWidget("org.kde.plasma.digitalclock");
top.addWidget("org.kde.plasma.showdesktop");

var dock = new Panel();
dock.location = "bottom";
// 60 was too tight for default icons in the spike: the icons touched the panel edge.
dock.height = 56;
dock.hiding = "none";
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
  "applications:oal-menu.desktop",
  "applications:org.kde.konsole.desktop",
  "applications:org.kde.dolphin.desktop",
  "applications:org.kde.kate.desktop",
  "applications:org.kde.spectacle.desktop",
  "applications:systemsettings.desktop"
]);
// Running windows from every desktop, so the dock is a switcher and not only a launcher.
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.writeConfig("showOnlyCurrentActivity", false);
tasks.reloadConfig();
