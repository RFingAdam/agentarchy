// The second preset: one taskbar along the bottom, the arrangement Windows 95 established and Mint
// still ships. Kept because it is what a lot of people want on day one, and because the default
// being opinionated is only defensible if the alternative is one command away.
//
// Deliberately close to stock Plasma. There is no value in a slightly different taskbar.

panels().forEach(function (p) { p.remove(); });

var bar = new Panel();
bar.location = "bottom";
bar.height = 44;
bar.hiding = "none";
bar.addWidget("org.kde.plasma.kickoff");
bar.addWidget("org.kde.plasma.pager");

// The full task manager here, with titles: this layout has the width for them, and it is the
// difference between a taskbar and a dock.
var tasks = bar.addWidget("org.kde.plasma.taskmanager");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.reloadConfig();

bar.addWidget("org.kde.plasma.systemtray");
bar.addWidget("org.kde.plasma.digitalclock");
bar.addWidget("org.kde.plasma.showdesktop");
