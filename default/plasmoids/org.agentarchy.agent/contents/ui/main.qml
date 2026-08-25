/*
 * The agent, on the panel, all the time.
 *
 * Everything else in the agent layer needs a terminal or a keystroke to be visible. This is the one
 * that is simply there, next to the clock, the way a battery indicator is there -- which is the
 * difference between a distribution that has an agent and one that is about agents.
 *
 * It reads oal-agent-hud --json, the same cache the shell prompt reads. One source, so the panel and
 * the prompt cannot disagree about what the agent is doing. It never talks to a model, a network or
 * an agent CLI itself: the refresh is a file read, and the timer that fills that file is somebody
 * else's job (install/agent/runtime.sh).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string posture: "scoped"
    property string model: ""
    property int mcp: 0
    property string spend: ""
    property string brain: ""
    property bool brainUp: false

    readonly property string hudCommand: "oal-agent-hud --json"

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        onNewData: function (source, data) {
            disconnectSource(source)
            if (source !== root.hudCommand) {
                return
            }
            var text = (data["stdout"] || "").trim()
            if (text.length === 0) {
                return
            }
            try {
                var j = JSON.parse(text)
                root.posture = j.profile || "scoped"
                // The prompt strips this prefix too. "claude-opus-5" is the id; "opus-5" is the
                // thing a person recognises at a glance on a panel.
                root.model = (j.model || "").replace(/^claude-/, "")
                root.mcp = j.mcp || 0
                root.spend = j.pct || ""
                root.brain = j.brain || ""
                root.brainUp = j.brain_up === 1
            } catch (e) {
                // A half-written cache is a transient, not a reason to blank the panel.
            }
        }

        function run(command) {
            connectSource(command)
        }
    }

    function refresh() {
        exec.run(root.hudCommand)
    }

    Component.onCompleted: refresh()

    // The cache behind this is refreshed on its own timer; this only decides how stale the panel is
    // allowed to look. Half a minute is well inside that, and costs one file read.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    preferredRepresentation: compactRepresentation

    toolTipMainText: i18n("Agent")
    toolTipSubText: root.model.length > 0
        ? i18n("%1, posture %2", root.model, root.posture)
        : i18n("Posture %1", root.posture)

    // implicitWidth as well as the Layout hints. A panel asks an applet how big it wants to be
    // through both, and with only the Layout attached properties set this loaded without a single
    // error and occupied no width at all -- present in the config, invisible on the panel.
    compactRepresentation: MouseArea {
        id: compact
        implicitWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: compactRow.implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "agentarchy"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents.Label {
                text: root.posture
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            // Only when there is something to say. A panel that always shows "0 mcp  %" teaches
            // people to stop reading it.
            PlasmaComponents.Label {
                visible: root.spend.length > 0
                text: root.spend.split(".")[0] + "%"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                PlasmaExtras.Heading {
                    level: 4
                    text: i18n("Agent")
                    Layout.fillWidth: true
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            GridLayout {
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                PlasmaComponents.Label { text: i18n("Posture"); opacity: 0.7 }
                PlasmaComponents.Label { text: root.posture; Layout.fillWidth: true }

                PlasmaComponents.Label { text: i18n("Model"); opacity: 0.7; visible: root.model.length > 0 }
                PlasmaComponents.Label { text: root.model; visible: root.model.length > 0; Layout.fillWidth: true }

                PlasmaComponents.Label { text: i18n("MCP servers"); opacity: 0.7 }
                PlasmaComponents.Label { text: root.mcp; Layout.fillWidth: true }

                PlasmaComponents.Label { text: i18n("Today"); opacity: 0.7; visible: root.spend.length > 0 }
                PlasmaComponents.Label { text: root.spend.split(".")[0] + "%"; visible: root.spend.length > 0; Layout.fillWidth: true }

                PlasmaComponents.Label { text: i18n("Brain"); opacity: 0.7 }
                PlasmaComponents.Label {
                    // Configured and unreachable is a different state from not configured, and the
                    // panel is exactly where that distinction is worth a word.
                    text: root.brain.length === 0
                        ? i18n("none configured")
                        : (root.brainUp ? root.brain : i18n("%1 (not answering)", root.brain))
                    Layout.fillWidth: true
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    text: i18n("Ask…")
                    icon.name: "agentarchy"
                    Layout.fillWidth: true
                    onClicked: {
                        exec.run("oal-ask")
                        root.expanded = false
                    }
                }

                PlasmaComponents.Button {
                    text: i18n("Agent menu")
                    icon.name: "preferences-system"
                    Layout.fillWidth: true
                    onClicked: {
                        exec.run("oal-menu agent")
                        root.expanded = false
                    }
                }
            }
        }
    }
}
