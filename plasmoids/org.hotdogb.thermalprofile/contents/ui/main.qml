import QtQuick
import QtCore
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var info: ({ current: "?", target: "off", temp: "?", cap: 0, max: 0, service: "", profiles: [] })
    property bool busy: false

    function iconFor(target) {
        if (target === "off") return "speedometer"
        const t = parseInt(target)
        if (t <= 72) return "temperature-cold"
        if (t <= 82) return "temperature-normal"
        return "temperature-warm"
    }

    function refresh() { runner.run("thermal-profile json") }
    function setProfile(name) { busy = true; runner.run("thermal-profile " + name) }

    Plasmoid.icon: iconFor(info.target)
    toolTipMainText: "Thermal: " + info.current
    toolTipSubText: (info.target === "off" ? "No cap" : "Target " + info.target + "°C")
                    + "\nCPU " + info.temp + "°C · cap " + info.cap + " / " + info.max + " MHz"
                    + "\nMiddle-click to cycle"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        function run(cmd) { connectSource(cmd) }
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source === "thermal-profile json") {
                try { root.info = JSON.parse(data["stdout"]) } catch (e) {}
            } else {
                root.busy = false
                root.refresh()
            }
        }
    }

    Timer {
        interval: root.expanded ? 1000 : 3000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        id: compact
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.setProfile("cycle")
            else root.expanded = !root.expanded
        }

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: root.iconFor(root.info.target)
                active: compact.containsMouse
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter
            }
            PlasmaComponents.Label {
                text: root.info.temp + "°"
                visible: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                color: parseInt(root.info.temp) >= 90 ? Kirigami.Theme.negativeTextColor
                     : parseInt(root.info.temp) >= 80 ? Kirigami.Theme.neutralTextColor
                     : Kirigami.Theme.textColor
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading { level: 3; text: "Thermal Profile"; Layout.fillWidth: true }
                PlasmaComponents.BusyIndicator {
                    visible: root.busy
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: root.info.temp + "°C"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                    font.weight: Font.DemiBold
                }
                ColumnLayout {
                    spacing: 0
                    PlasmaComponents.Label { text: "Cap " + root.info.cap + " / " + root.info.max + " MHz"; opacity: 0.8 }
                    PlasmaComponents.ProgressBar {
                        Layout.fillWidth: true
                        from: 0; to: root.info.max || 1; value: root.info.cap
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Repeater {
                model: root.info.profiles
                delegate: PlasmaComponents.RadioButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name + "  —  " + (modelData.target === "off" ? "no cap" : modelData.target + "°C")
                    icon.name: root.iconFor(modelData.target)
                    checked: root.info.current === modelData.name
                    enabled: !root.busy
                    onClicked: root.setProfile(modelData.name)
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Button {
                    text: "Cycle"; icon.name: "view-refresh"
                    enabled: !root.busy
                    onClicked: root.setProfile("cycle")
                }
                Item { Layout.fillWidth: true }
                PlasmaComponents.ToolButton {
                    icon.name: "document-edit"
                    PlasmaComponents.ToolTip { text: "Edit profiles file" }
                    onClicked: Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/thermal-profile/profiles")
                }
            }
        }
    }
}
