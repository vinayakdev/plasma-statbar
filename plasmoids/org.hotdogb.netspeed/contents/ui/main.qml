import QtQuick
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

    readonly property string cmd: "cat /proc/net/dev; ip -o route show default"
    readonly property int historyLen: 60

    property string iface: Plasmoid.configuration.iface
    property bool bits: Plasmoid.configuration.bits

    property var ifaces: []          // physical-ish interfaces seen in /proc/net/dev
    property string defaultIface: ""
    property string activeIface: iface === "auto" ? defaultIface : iface
    property var last: null          // { t, rx, tx }
    property real down: 0            // bytes/s
    property real up: 0
    property real totalRx: 0
    property real totalTx: 0
    property real peakDown: 0
    property real peakUp: 0
    property var histDown: []
    property var histUp: []

    function isVirtual(name) {
        return name === "lo" || /^(veth|docker|br-|virbr|vnet|tap|tun|wg|tailscale|zt)/.test(name)
    }

    function fmtRate(bps) {
        let v = bits ? bps * 8 : bps
        const units = bits ? ["b/s", "Kb/s", "Mb/s", "Gb/s"] : ["B/s", "KB/s", "MB/s", "GB/s"]
        let i = 0
        while (v >= 1000 && i < units.length - 1) { v /= 1024; i++ }
        return (i === 0 ? Math.round(v) : v.toFixed(v < 10 ? 1 : 0)) + " " + units[i]
    }

    function fmtBytes(b) {
        const units = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
        return (i === 0 ? b : b.toFixed(1)) + " " + units[i]
    }

    function rateColor(bps) {
        if (bps >= 5 * 1024 * 1024) return Kirigami.Theme.negativeTextColor
        if (bps >= 512 * 1024) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.textColor
    }

    function resetCounters() {
        last = null; histDown = []; histUp = []; peakDown = 0; peakUp = 0; down = 0; up = 0
    }

    function parse(out) {
        const stats = {}
        const names = []
        let def = ""
        for (const line of out.split("\n")) {
            const m = line.match(/^\s*([^\s:]+):\s*(.*)$/)
            if (m) {
                const f = m[2].trim().split(/\s+/)
                stats[m[1]] = { rx: Number(f[0]), tx: Number(f[8]) }
                if (!isVirtual(m[1])) names.push(m[1])
                continue
            }
            const r = line.match(/^default .*\bdev (\S+)/)
            if (r && !def) def = r[1]
        }
        ifaces = names
        defaultIface = def

        let rx = 0, tx = 0
        if (iface === "all") {
            for (const n of names) { rx += stats[n].rx; tx += stats[n].tx }
        } else if (stats[activeIface]) {
            rx = stats[activeIface].rx; tx = stats[activeIface].tx
        }
        totalRx = rx; totalTx = tx

        const now = Date.now()
        if (last && now > last.t && rx >= last.rx && tx >= last.tx) {
            const dt = (now - last.t) / 1000
            down = (rx - last.rx) / dt
            up = (tx - last.tx) / dt
            peakDown = Math.max(peakDown, down)
            peakUp = Math.max(peakUp, up)
            histDown = histDown.concat([down]).slice(-historyLen)
            histUp = histUp.concat([up]).slice(-historyLen)
        }
        last = { t: now, rx: rx, tx: tx }
    }

    onIfaceChanged: resetCounters()

    Plasmoid.icon: down + up < 1024 ? "network-idle" : "network-transmit-receive"
    toolTipMainText: "Network: " + (iface === "all" ? "all interfaces" : (activeIface || "none"))
    toolTipSubText: "↓ " + fmtRate(down) + "   ↑ " + fmtRate(up)
                    + "\nSince boot: ↓ " + fmtBytes(totalRx) + " · ↑ " + fmtBytes(totalTx)
                    + "\nMiddle-click to toggle bits/bytes"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            root.parse(data["stdout"] || "")
        }
    }

    Timer {
        interval: 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: runner.connectSource(root.cmd)
    }

    compactRepresentation: MouseArea {
        id: compact
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Plasmoid.configuration.bits = !root.bits
            else root.expanded = !root.expanded
        }

        // Fixed-width value column so the panel doesn't jitter as numbers change
        TextMetrics { id: widest; font: Kirigami.Theme.smallFont; text: "888.8 KB/s" }

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: Plasmoid.icon
                active: compact.containsMouse
                visible: Plasmoid.formFactor !== PlasmaCore.Types.Horizontal
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter
            }
            GridLayout {
                visible: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                columns: 2
                rowSpacing: 0
                columnSpacing: Kirigami.Units.smallSpacing
                Layout.fillHeight: true

                Repeater {
                    model: [
                        { arrow: "↓", rate: root.down },
                        { arrow: "↑", rate: root.up }
                    ]
                    delegate: PlasmaComponents.Label {
                        required property var modelData
                        required property int index
                        Layout.row: index; Layout.column: 0
                        Layout.preferredHeight: compact.height / 2
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.arrow
                        font: Kirigami.Theme.smallFont
                        color: root.rateColor(modelData.rate)
                    }
                }
                Repeater {
                    model: [root.down, root.up]
                    delegate: PlasmaComponents.Label {
                        required property var modelData
                        required property int index
                        Layout.row: index; Layout.column: 1
                        Layout.preferredHeight: compact.height / 2
                        Layout.preferredWidth: Math.ceil(widest.width)
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignLeft
                        text: root.fmtRate(modelData)
                        font: Kirigami.Theme.smallFont
                        color: root.rateColor(modelData)
                    }
                }
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading { level: 3; text: "Net Speed"; Layout.fillWidth: true }
                PlasmaComponents.ComboBox {
                    id: picker
                    model: ["auto", "all"].concat(root.ifaces)
                    currentIndex: Math.max(0, model.indexOf(root.iface))
                    displayText: currentText === "auto" ? "auto (" + (root.defaultIface || "none") + ")" : currentText
                    onActivated: Plasmoid.configuration.iface = currentText
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            GridLayout {
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing * 2
                Layout.fillWidth: true

                Repeater {
                    model: [
                        { label: "Download", rate: root.down, peak: root.peakDown, total: root.totalRx, color: Kirigami.Theme.highlightColor },
                        { label: "Upload",   rate: root.up,   peak: root.peakUp,   total: root.totalTx, color: Kirigami.Theme.positiveTextColor }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        spacing: 0
                        Layout.fillWidth: true
                        RowLayout {
                            Rectangle { width: 8; height: 8; radius: 4; color: modelData.color }
                            PlasmaComponents.Label { text: modelData.label; opacity: 0.8 }
                        }
                        PlasmaComponents.Label {
                            text: root.fmtRate(modelData.rate)
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
                            font.weight: Font.DemiBold
                        }
                        PlasmaComponents.Label {
                            text: "peak " + root.fmtRate(modelData.peak) + "\ntotal " + root.fmtBytes(modelData.total)
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Canvas {
                id: graph
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                property var d: root.histDown
                property var u: root.histUp
                onDChanged: requestPaint()
                onUChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const max = Math.max(1024, ...d, ...u) * 1.1
                    const step = width / (root.historyLen - 1)

                    ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    ctx.lineWidth = 1
                    for (let i = 1; i < 4; i++) {
                        const y = Math.round(height * i / 4) + 0.5
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                    }

                    function plot(series, color) {
                        if (series.length < 2) return
                        const x0 = width - (series.length - 1) * step
                        ctx.beginPath()
                        ctx.moveTo(x0, height)
                        series.forEach((v, i) => ctx.lineTo(x0 + i * step, height - v / max * height))
                        ctx.lineTo(width, height)
                        ctx.closePath()
                        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.25)
                        ctx.fill()
                        ctx.beginPath()
                        series.forEach((v, i) => {
                            const x = x0 + i * step, y = height - v / max * height
                            i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)
                        })
                        ctx.strokeStyle = color
                        ctx.lineWidth = 1.5
                        ctx.stroke()
                    }
                    plot(d, Kirigami.Theme.highlightColor)
                    plot(u, Kirigami.Theme.positiveTextColor)
                }
                PlasmaComponents.Label {
                    anchors { top: parent.top; left: parent.left }
                    text: root.fmtRate(Math.max(1024, ...root.histDown, ...root.histUp) * 1.1)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
                PlasmaComponents.Label {
                    anchors { bottom: parent.bottom; left: parent.left }
                    text: "last " + root.historyLen + "s"
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Switch {
                    text: "Show in bits"
                    checked: root.bits
                    onToggled: Plasmoid.configuration.bits = checked
                }
                Item { Layout.fillWidth: true }
                PlasmaComponents.ToolButton {
                    icon.name: "edit-clear-history"
                    PlasmaComponents.ToolTip { text: "Reset peaks and graph" }
                    onClicked: root.resetCounters()
                }
            }
        }
    }
}
