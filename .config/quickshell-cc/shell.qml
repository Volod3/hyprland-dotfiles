import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// ═══════════════════════════════════════════════════════════════
//  Азур · Центр керування  (Quickshell)
//  Відкриття: ~/.config/theme-switch/bin/cc   (toggle)
//  Закриття : Esc / клік поза панеллю / повторний запуск cc
// ═══════════════════════════════════════════════════════════════
PanelWindow {
    id: win

    // ── палітра ────────────────────────────────────────────────
    readonly property color cBg0: "#0b1020"
    readonly property color cBg1: "#131829"
    readonly property color cPanel: "#16203c"
    readonly property color cAccent: "#7fdcff"
    readonly property color cText: "#d6ecff"
    readonly property color cDim: "#6f88ab"
    readonly property color cDanger: "#ff7096"
    readonly property string ff: "JetBrainsMono Nerd Font Mono"
    readonly property string ccctl: "/home/voltimeter/.config/quickshell-cc/ccctl"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-cc"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: true

    // ── стан ───────────────────────────────────────────────────
    property var st: ({})
    property real vol: 50
    property real mic: 30
    property real bright: 100
    property bool volMuted: false
    property bool micMuted: false
    property bool volDrag: false
    property bool micDrag: false
    property bool brightDrag: false
    property real rev: 0
    property bool closing: false
    property bool showSinks: false
    property bool showSrcs: false

    function g(k, dflt) {
        var v = st ? st[k] : undefined;
        return (v === undefined || v === null) ? dflt : v;
    }
    readonly property var sinks: g("sinks", [])
    readonly property var sources: g("sources", [])
    readonly property bool wifiOn: g("wifi", "off") === "on"
    readonly property bool wifiMissing: g("wifi", "off") === "missing"
    readonly property bool btOn: g("bt", "off") === "on"
    readonly property bool btMissing: g("bt", "off") === "missing"
    readonly property bool dndOn: g("dnd", false) === true
    readonly property bool gameOn: g("game", false) === true
    readonly property int bat: g("bat", -1)
    readonly property int temp: g("temp", 0)
    readonly property int cpu: g("cpu", 0)
    readonly property int ram: g("ram", 0)

    // ── реакція на стан ───────────────────────────────────────
    function applyStatus(txt) {
        var j;
        try { j = JSON.parse(txt); } catch (e) { return; }
        if (!j || typeof j !== "object") return;
        st = j;
        if (!volDrag) vol = j.vol;
        if (!micDrag) mic = j.mic;
        if (!brightDrag) bright = j.brightPct;
        volMuted = j.volMuted === true;
        micMuted = j.micMuted === true;
    }

    function act(args) {
        Quickshell.execDetached(["bash", "-c", win.ccctl + " " + args]);
        pollSoon.restart();
    }

    function closePanel() {
        if (closing) return;
        closing = true;
        rev = 0;
        quitTimer.start();
    }

    // ── опитування стану ──────────────────────────────────────
    Process {
        id: statusProc
        command: ["bash", "-c", win.ccctl + " status"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: win.applyStatus(this.text)
        }
    }
    Timer {
        interval: 900; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!statusProc.running) statusProc.running = true; }
    }
    Timer {
        id: pollSoon; interval: 220
        onTriggered: { if (!statusProc.running) statusProc.running = true; }
    }
    // дебаунс запису під час перетягування
    Timer { id: volSetT; interval: 90; onTriggered: win.act("vol " + Math.round(win.vol)) }
    Timer { id: micSetT; interval: 90; onTriggered: win.act("mic " + Math.round(win.mic)) }
    Timer { id: brightSetT; interval: 90; onTriggered: win.act("bright " + Math.round(win.bright)) }
    Timer { id: quitTimer; interval: 200; onTriggered: Qt.exit(0) }

    Behavior on rev {
        NumberAnimation {
            duration: win.closing ? 170 : 340
            easing.type: win.closing ? Easing.InCubic : Easing.OutCubic
        }
    }

    Component.onCompleted: Qt.callLater(function() { win.rev = 1; });

    // ═══════════════════════════════════════════════════════════
    //  КОРІНЬ
    // ═══════════════════════════════════════════════════════════
    Item {
        id: screen
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.closePanel()

        // клік поза панеллю → закрити
        MouseArea {
            anchors.fill: parent
            onClicked: win.closePanel()
        }

        // ── ПАНЕЛЬ ────────────────────────────────────────────
        Item {
            id: panel
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 18
            anchors.topMargin: 46
            width: 412
            height: col.implicitHeight + 36

            opacity: win.rev
            // виїжджає з-під панелі вниз (швидке меню, як у Plasma)
            scale: 0.955 + 0.045 * win.rev
            transform: Translate { y: -34 * (1 - win.rev) }

            // тінь
            MultiEffect {
                source: bg
                anchors.fill: bg
                z: -1
                shadowEnabled: true
                shadowColor: "#e6050a18"
                shadowBlur: 1.0
                shadowVerticalOffset: 16
                shadowHorizontalOffset: 0
                blurMax: 72
                autoPaddingEnabled: true
            }

            // скло
            Rectangle {
                id: bg
                anchors.fill: parent
                radius: 22
                border.width: 1
                border.color: "#337fdcff"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#b42b3d68" }
                    GradientStop { position: 0.45; color: "#ac142039" }
                    GradientStop { position: 1.0; color: "#b00d1526" }
                }

                // верхній відблиск скла
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 1
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 0.5; color: "#77c9f4ff" }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                }

                // акцентна смуга зліва
                Rectangle {
                    width: 2
                    height: parent.height - 48
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 0.3; color: "#8c7fdcff" }
                        GradientStop { position: 0.7; color: "#8c7fdcff" }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                }
            }

            // поглинач кліків по фону панелі
            MouseArea { anchors.fill: parent }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 11

                // ── заголовок ─────────────────────────────────
                RowLayout {
                    width: parent.width
                    height: 34
                    spacing: 8

                    Column {
                        spacing: 3
                        Text {
                            text: "ЦЕНТР КЕРУВАННЯ"
                            color: win.cText
                            font.family: win.ff
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            font.letterSpacing: 2.4
                        }
                        Text {
                            text: "Азур · Hyprland"
                            color: win.cDim
                            font.family: win.ff
                            font.pixelSize: 9
                            font.letterSpacing: 1.2
                        }
                    }
                    Item { Layout.fillWidth: true }
                    GlyphButton {
                        size: 30
                        glyph: "\uf00d"
                        onClicked: win.closePanel()
                    }
                }

                // тонкий розділювач
                Rectangle {
                    width: parent.width
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 0.5; color: "#3a7fdcff" }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                }

                // ═══════════ ЗВУК ═══════════
                Rectangle {
                    width: parent.width
                    implicitHeight: sndCol.implicitHeight + 26
                    radius: 16
                    border.width: 1
                    border.color: "#1c7fdcff"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#16ffffff" }
                        GradientStop { position: 1.0; color: "#07ffffff" }
                    }

                    Column {
                        id: sndCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 13
                        spacing: 9

                        RowLayout {
                            width: parent.width
                            height: 28

                            Text {
                                text: win.volMuted ? "\uf026" : "\uf028"
                                color: win.volMuted ? win.cDanger : win.cAccent
                                font.family: win.ff
                                font.pixelSize: 18
                            }
                            Text {
                                text: "Звук"
                                color: win.cText
                                font.family: win.ff
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.0
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(win.vol) + "%"
                                color: win.vol > 100 ? win.cAccent : (win.volMuted ? win.cDanger : win.cText)
                                font.family: win.ff
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                            GlyphButton {
                                size: 28
                                glyph: win.volMuted ? "\uf131" : "\uf026"
                                active: win.volMuted
                                danger: win.volMuted
                                onClicked: win.act("vol-mute")
                            }
                        }

                        SlimSlider {
                            width: parent.width
                            from: 0
                            to: 150
                            value: win.vol
                            boost: win.vol > 100
                            onMoved: (v) => { win.volDrag = true; win.vol = v; volSetT.restart(); }
                            onFinished: (v) => { win.vol = v; win.act("vol " + Math.round(v)); win.volDrag = false; }
                        }

                        RowLayout {
                            width: parent.width
                            height: 22
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: win.g("sink", "—")
                                color: "#7d97b8"
                                font.family: win.ff
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                            PillButton {
                                visible: win.sinks.length > 1
                                text: win.showSinks ? "пристрої ▴" : "пристрої ▾"
                                onClicked: win.showSinks = !win.showSinks
                            }
                            PillButton {
                                text: "Звук  →"
                                accent: true
                                onClicked: win.act("pavu sink")
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 3
                            visible: win.showSinks
                            Repeater {
                                model: win.sinks
                                DeviceRow {
                                    required property var modelData
                                    width: parent.width
                                    title: modelData.desc
                                    active: modelData.active
                                    onClicked: win.act("sink '" + modelData.name + "'")
                                }
                            }
                        }
                    }
                }

                // ═══════════ МІКРОФОН ═══════════
                Rectangle {
                    width: parent.width
                    implicitHeight: micCol.implicitHeight + 26
                    radius: 16
                    border.width: 1
                    border.color: "#1c7fdcff"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#16ffffff" }
                        GradientStop { position: 1.0; color: "#07ffffff" }
                    }

                    Column {
                        id: micCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 13
                        spacing: 9

                        RowLayout {
                            width: parent.width
                            height: 28

                            Text {
                                text: "\uf130"
                                color: win.micMuted ? win.cDanger : "#9ad8ff"
                                font.family: win.ff
                                font.pixelSize: 18
                            }
                            Text {
                                text: "Мікрофон"
                                color: win.cText
                                font.family: win.ff
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.0
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(win.mic) + "%"
                                color: win.micMuted ? win.cDanger : win.cText
                                font.family: win.ff
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                            GlyphButton {
                                size: 28
                                glyph: win.micMuted ? "\uf131" : "\uf130"
                                active: win.micMuted
                                danger: win.micMuted
                                onClicked: win.act("mic-mute")
                            }
                        }

                        SlimSlider {
                            width: parent.width
                            from: 0
                            to: 150
                            value: win.mic
                            fillA: "#b6e8ff"
                            fillB: "#4c8fd0"
                            onMoved: (v) => { win.micDrag = true; win.mic = v; micSetT.restart(); }
                            onFinished: (v) => { win.mic = v; win.act("mic " + Math.round(v)); win.micDrag = false; }
                        }

                        RowLayout {
                            width: parent.width
                            height: 22
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: win.g("source", "—")
                                color: "#7d97b8"
                                font.family: win.ff
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                            PillButton {
                                visible: win.sources.length > 1
                                text: win.showSrcs ? "джерела ▴" : "джерела ▾"
                                onClicked: win.showSrcs = !win.showSrcs
                            }
                            PillButton {
                                text: "Мікрофон  →"
                                accent: true
                                onClicked: win.act("pavu source")
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 3
                            visible: win.showSrcs
                            Repeater {
                                model: win.sources
                                DeviceRow {
                                    required property var modelData
                                    width: parent.width
                                    title: modelData.desc
                                    active: modelData.active
                                    onClicked: win.act("source '" + modelData.name + "'")
                                }
                            }
                        }
                    }
                }

                // ═══════════ ЯСКРАВІСТЬ ═══════════
                Rectangle {
                    width: parent.width
                    implicitHeight: briCol.implicitHeight + 24
                    radius: 16
                    border.width: 1
                    border.color: "#1c7fdcff"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#16ffffff" }
                        GradientStop { position: 1.0; color: "#07ffffff" }
                    }

                    Column {
                        id: briCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 7

                        RowLayout {
                            width: parent.width
                            height: 24
                            Text {
                                text: "\uf185"
                                color: win.bright < 15 ? "#8b7bb5" : "#ffd98a"
                                font.family: win.ff
                                font.pixelSize: 17
                            }
                            Text {
                                text: "Яскравість"
                                color: win.cText
                                font.family: win.ff
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.0
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(win.bright) + "%"
                                color: win.cText
                                font.family: win.ff
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }
                        SlimSlider {
                            width: parent.width
                            from: 1
                            to: 100
                            value: win.bright
                            fillA: "#ffe4a8"
                            fillB: "#c98a3c"
                            onMoved: (v) => { win.brightDrag = true; win.bright = v; brightSetT.restart(); }
                            onFinished: (v) => { win.bright = v; win.act("bright " + Math.round(v)); win.brightDrag = false; }
                        }
                    }
                }

                // ═══════════ ШВИДКІ ПЕРЕМИКАЧІ ═══════════
                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 9
                    readonly property real cw: (width - spacing) / 2

                    QuickTile {
                        width: parent.cw
                        glyph: "\uf1eb"
                        label: "Wi-Fi"
                        state: win.wifiMissing ? "немає адаптера" : (win.wifiOn ? "увімкнено" : "вимкнено")
                        active: win.wifiOn
                        unavailable: win.wifiMissing
                        onClicked: win.act("wifi toggle")
                    }
                    QuickTile {
                        width: parent.cw
                        glyph: "\uf293"
                        label: "Bluetooth"
                        state: win.btMissing ? "немає" : (win.btOn ? "увімкнено" : "вимкнено")
                        active: win.btOn
                        unavailable: win.btMissing
                        onClicked: win.act("bt toggle")
                    }
                    QuickTile {
                        width: parent.cw
                        glyph: win.dndOn ? "\uf1f6" : "\uf0f3"
                        label: "Не турбувати"
                        state: win.dndOn ? "тиша" : "сповіщення"
                        active: win.dndOn
                        accent: "#ffb8d0"
                        onClicked: win.act("dnd toggle")
                    }
                    QuickTile {
                        width: parent.cw
                        glyph: "\uf11b"
                        label: "Ігровий режим"
                        state: win.gameOn ? "макс. швидкість" : "звичайний"
                        active: win.gameOn
                        accent: "#9dffcf"
                        onClicked: win.act("game toggle")
                    }
                }

                // ═══════════ ІНФО-РЯДОК ═══════════
                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 14
                    border.width: 1
                    border.color: "#157fdcff"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#12ffffff" }
                        GradientStop { position: 1.0; color: "#05ffffff" }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 2

                        Repeater {
                            model: [
                                { gly: "\uf240", lab: "Батарея", val: win.bat < 0 ? "—" : win.bat + "%",
                                  col: win.bat >= 0 && win.bat <= 20 ? win.cDanger : "#a9ecff" },
                                { gly: "\uf2c7", lab: "Темп", val: win.temp + "°",
                                  col: win.temp >= 80 ? win.cDanger : "#a9ecff" },
                                { gly: "\uf2db", lab: "CPU", val: win.cpu + "%",
                                  col: "#a9ecff" },
                                { gly: "\uf233", lab: "RAM", val: win.ram + "%",
                                  col: "#a9ecff" }
                            ]

                            Item {
                                required property var modelData
                                required property int index
                                width: parent.width / 4
                                height: parent.height

                                Rectangle {
                                    visible: index > 0
                                    width: 1
                                    height: parent.height - 22
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#16ffffff"
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Row {
                                        spacing: 5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.gly
                                            color: modelData.col
                                            font.family: win.ff
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.val
                                            color: "#e2f4ff"
                                            font.family: win.ff
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.lab
                                        color: "#63799a"
                                        font.family: win.ff
                                        font.pixelSize: 8
                                        font.letterSpacing: 0.8
                                    }
                                }
                            }
                        }
                    }
                }

                // ── підказка ──────────────────────────────────
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Esc — закрити  ·  клік поза панеллю"
                    color: "#415878"
                    font.family: win.ff
                    font.pixelSize: 8
                    font.letterSpacing: 0.6
                }
            }
        }
    }
}
