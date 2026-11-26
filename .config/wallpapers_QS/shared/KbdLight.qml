import Quickshell
import Quickshell.Io
import QtQuick

// ═══════════════════════════════════════════════════════════════════
//  Підсвітка клавіатури — спільний компонент (бокова панель + «Налаштування» → «Клавіатура»).
//  • жива мініатюра клавіатури: світиться вибраним кольором і показує ефект (дихання / веселка / пульс)
//  • ступінчастий повзунок яскравості, ефекти й кольори (RGB — лише якщо ноутбук уміє)
//  Працює на будь-якому ПК: якщо підсвітки немає — висота 0 (розділ ховається).
//  Яскравість — brightnessctl; RGB — /sys/class/leds/*kbd_backlight*/kbd_rgb_mode (asus-wmi; права дає power-perms.service).
// ═══════════════════════════════════════════════════════════════════
Item {
    id: kb

    // кольори ззовні (у панелі — root.theme, у налаштуваннях — Theme)
    property color cAccent: "#8cc8ff"
    property color cText: "#e8ecf4"
    property color cSub: "#8f98ab"
    property color cTrack: Qt.rgba(1, 1, 1, 0.08)
    property color cHover: Qt.rgba(1, 1, 1, 0.12)
    property color cOnAccent: "#0e1420"
    property string font: ""
    property string iconFont: "JetBrainsMono Nerd Font"
    property bool showTitle: true

    property string dev: ""
    property int maxB: 0
    property int cur: 0
    property bool rgb: false
    property int mode: 0
    property string rgbColor: "8cc8ff"
    readonly property bool present: dev.length > 0
    readonly property color lightColor: rgb ? ("#" + rgbColor) : "#f4f1ea"

    implicitHeight: present ? col.implicitHeight : 0
    height: implicitHeight
    visible: present

    function refresh() { if (!probe.running) probe.running = true }
    Component.onCompleted: refresh()

    Process {
        id: probe
        command: ["sh", "-c", "d=$(ls -d /sys/class/leds/*kbd_backlight* 2>/dev/null | head -n1); [ -n \"$d\" ] || exit 0; " +
                  "echo \"$(basename $d) $(cat $d/max_brightness) $(cat $d/brightness) $([ -e $d/kbd_rgb_mode ] && echo rgb || echo no)\"; " +
                  "cat \"$HOME/.cache/kbd-rgb.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const p = (lines[0] || "").split(" ")
                if (p.length < 4) { kb.dev = ""; return }
                kb.dev = p[0]; kb.maxB = Number(p[1]); kb.cur = Number(p[2]); kb.rgb = p[3] === "rgb"
                try { const st = JSON.parse(lines.slice(1).join("\n")); kb.mode = st.mode; kb.rgbColor = st.color } catch (e) {}
            }
        }
    }
    // яскравість могли змінити клавішами Fn — підтягувати, поки видно
    Timer { interval: 1500; repeat: true; running: kb.visible && kb.present; onTriggered: kb.refresh() }

    function setLevel(n) {
        n = Math.max(0, Math.min(kb.maxB, n))
        kb.cur = n
        Quickshell.execDetached(["brightnessctl", "-q", "-d", kb.dev, "set", String(n)])
    }
    function applyRgb() {
        const c = kb.rgbColor
        const r = parseInt(c.slice(0, 2), 16), g = parseInt(c.slice(2, 4), 16), b = parseInt(c.slice(4, 6), 16)
        if (kb.cur === 0) kb.setLevel(Math.max(1, Math.round(kb.maxB / 2)))     // вибрав колір — значить, хоче світла
        // asus-wmi: «1 (зберегти в прошивці) режим R G B швидкість»
        Quickshell.execDetached(["sh", "-c", "echo '1 " + kb.mode + " " + r + " " + g + " " + b + " 1' > /sys/class/leds/" + kb.dev + "/kbd_rgb_mode; " +
            "printf '{\"mode\": %d, \"color\": \"%s\"}' " + kb.mode + " " + c + " > \"$HOME/.cache/kbd-rgb.json\""])
    }

    // фаза анімації мініатюри (0..1, по колу)
    property real phase: 0
    NumberAnimation on phase { from: 0; to: 1; duration: kb.mode === 3 ? 900 : 2600; loops: Animation.Infinite; running: kb.visible && kb.present }

    Column {
        id: col
        width: parent.width
        spacing: 12

        // ── заголовок ──
        Item {
            visible: kb.showTitle
            width: parent.width; height: 22
            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "󰌌"; font.family: kb.iconFont; font.pixelSize: 16; color: kb.cur > 0 ? kb.lightColor : kb.cSub
                       anchors.verticalCenter: parent.verticalCenter; Behavior on color { ColorAnimation { duration: 250 } } }
                Text { text: "Підсвітка клавіатури"; color: kb.cText; font.pixelSize: 13; font.family: kb.font; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: kb.cur === 0 ? "вимкнено" : (kb.cur === kb.maxB ? "максимум" : kb.cur + " з " + kb.maxB)
                color: kb.cSub; font.pixelSize: 11; font.family: kb.font
            }
        }

        // ── жива мініатюра клавіатури ──
        Rectangle {
            id: kbdPrev
            width: parent.width
            height: 74
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            clip: true

            // сяйво під клавішами
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.9; height: parent.height * 0.8; radius: height / 2
                color: kb.lightColor
                opacity: kb.cur === 0 ? 0 : 0.10 * kb.cur / Math.max(1, kb.maxB) * (kb.mode === 1 ? (0.4 + 0.6 * Math.abs(Math.sin(kb.phase * Math.PI))) : 1)
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
            Column {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: [12, 12, 11, 7]
                    Row {
                        required property int index
                        required property int modelData
                        readonly property int rowI: index
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3
                        Repeater {
                            model: modelData
                            Rectangle {
                                required property int index
                                readonly property real pos: (index + rowI * 0.5) / 13          // 0..1 зліва направо
                                readonly property real level: kb.cur / Math.max(1, kb.maxB)
                                readonly property real fx: kb.mode === 1 ? (0.35 + 0.65 * Math.abs(Math.sin(kb.phase * Math.PI)))       // дихання
                                                         : kb.mode === 3 ? (kb.phase < 0.18 ? 1 : 0.25)                                   // пульс
                                                         : 1
                                width: rowI === 3 && index === 3 ? 58 : 16
                                height: 13; radius: 3.5
                                color: kb.cur === 0 ? Qt.rgba(1, 1, 1, 0.07)
                                     : kb.rgb && kb.mode === 2 ? Qt.hsva((pos + kb.phase) % 1, 0.55, 1, 1)                                  // веселка хвилею
                                     : kb.lightColor
                                opacity: kb.cur === 0 ? 1 : (0.25 + 0.75 * level) * fx
                                Behavior on opacity { enabled: kb.mode === 0; NumberAnimation { duration: 220 } }
                                Behavior on color { enabled: kb.mode !== 2; ColorAnimation { duration: 250 } }
                            }
                        }
                    }
                }
            }
        }

        // ── яскравість: ступінчастий повзунок ──
        Item {
            id: steps
            width: parent.width; height: 34
            readonly property real stepW: (width - 28) / Math.max(1, kb.maxB)
            Rectangle {
                id: trackBg
                x: 14; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28; height: 6; radius: 3
                color: kb.cTrack
                Rectangle {
                    height: parent.height; radius: 3
                    width: steps.stepW * kb.cur
                    color: kb.lightColor
                    opacity: 0.85
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }
            Repeater {
                model: kb.maxB + 1
                Rectangle {
                    required property int index
                    readonly property bool lit: index <= kb.cur && kb.cur > 0
                    x: 14 + steps.stepW * index - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: index === kb.cur ? 22 : 12; height: width; radius: width / 2
                    color: index === kb.cur ? (kb.cur === 0 ? kb.cSub : kb.lightColor) : (lit ? kb.lightColor : Qt.rgba(1, 1, 1, 0.18))
                    border.width: index === kb.cur ? 3 : 0
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                    // ореол активної точки
                    Rectangle {
                        visible: index === kb.cur && kb.cur > 0
                        anchors.centerIn: parent
                        width: parent.width + 14; height: width; radius: width / 2
                        color: "transparent"
                        border.width: 2; border.color: kb.lightColor
                        opacity: 0.35
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function pick(mx) { kb.setLevel(Math.round((mx - 14) / steps.stepW)) }
                onPressed: (m) => pick(m.x)
                onPositionChanged: (m) => { if (pressed) pick(m.x) }
                onWheel: (w) => kb.setLevel(kb.cur + (w.angleDelta.y > 0 ? 1 : -1))
            }
        }

        // ── ефекти (RGB) ──
        Row {
            visible: kb.rgb
            width: parent.width
            spacing: 6
            Repeater {
                model: [ { m: 0, i: "󰝤", t: "Статично" }, { m: 1, i: "󰞍", t: "Дихання" }, { m: 2, i: "󰏘", t: "Веселка" }, { m: 3, i: "󱐋", t: "Пульс" } ]
                Rectangle {
                    required property var modelData
                    readonly property bool on: kb.mode === modelData.m
                    width: (parent.width - 18) / 4; height: 46; radius: 12
                    color: on ? Qt.rgba(kb.lightColor.r, kb.lightColor.g, kb.lightColor.b, 0.20) : (em.containsMouse ? kb.cHover : kb.cTrack)
                    border.width: on ? 1 : 0
                    border.color: kb.lightColor
                    scale: em.pressed ? 0.95 : 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.i; font.family: kb.iconFont; font.pixelSize: 15
                               color: parent.parent.on ? kb.lightColor : kb.cSub }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; font.pixelSize: 10; font.family: kb.font
                               color: parent.parent.on ? kb.cText : kb.cSub }
                    }
                    MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { kb.mode = modelData.m; kb.applyRgb() } }
                }
            }
        }

        // ── кольори (RGB; у «Веселці» колір не потрібен) ──
        Item {
            visible: kb.rgb
            width: parent.width; height: 30
            opacity: kb.mode === 2 ? 0.35 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9
                Repeater {
                    model: ["8cc8ff", "f2b8d4", "b48cff", "7ee0b8", "ffcf7a", "ff8a65", "ff5c7a", "ffffff"]
                    Item {
                        required property string modelData
                        readonly property bool on: kb.rgbColor === modelData
                        width: 26; height: 26
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.on ? 26 : 22; height: width; radius: width / 2
                            color: "#" + modelData
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                            scale: cm.containsMouse && !parent.on ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                visible: parent.parent.on
                                text: "󰄬"; font.family: kb.iconFont; font.pixelSize: 13
                                color: "#14161f"
                            }
                        }
                        Rectangle {        // кільце вибраного
                            anchors.centerIn: parent
                            visible: parent.on
                            width: 34; height: 34; radius: 17
                            color: "transparent"; border.width: 2; border.color: "#" + modelData
                            opacity: 0.55
                        }
                        MouseArea { id: cm; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { kb.rgbColor = modelData; kb.applyRgb() } }
                    }
                }
            }
        }
    }
}
