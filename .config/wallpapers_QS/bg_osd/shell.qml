import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// ═══════════════════════════════════════════════════════════════════
//  Спливаючі віконця на дії (OSD, як у KDE Plasma): гучність, мікрофон, яскравість, підсвітка клавіатури,
//  зарядка підключена/відключена, флешку підключено/від'єднано/можна витягати, розкладка клавіатури.
//  Самі стежать за: зарядкою (udev), флешками (tools/devices watch), розкладкою (Hyprland), підсвіткою (sysfs).
//  Ззовні (tools/osdctl, tools/devices):
//    qs -p ~/.config/wallpapers_QS/bg_osd/shell.qml ipc call osd level  volume 45 0      (тип, %, вимкнено 0/1)
//    ... ipc call osd event    usb "Флешку підключено" "Kingston · 32 ГБ"
//    ... ipc call osd progress usb "Дописую дані" 42 "залишилось 120 МБ"
// ═══════════════════════════════════════════════════════════════════
ShellRoot {
    id: root
    ThemeColors { id: tc }          // кольори поточної теми (Pause — меню тем)

    readonly property color cBg: tc.a(tc.bg, 0.92)
    readonly property color cBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cAccent: tc.accent
    readonly property color cPink: tc.accent2
    readonly property color cText: tc.text
    readonly property color cSub: tc.sub
    readonly property color cWarn: tc.warn
    readonly property color cGood: tc.good
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    property bool shown: false
    property string icon: ""
    property color iconColor: cAccent
    property string title: ""
    property string sub: ""
    property real value: -1          // 0..1 — смужка; -1 — без смужки
    property bool muted: false
    property int bump: 0             // лічильник для «підстрибування» при новій події

    function show(ic, col, ti, su, val, mut, ms) {
        root.icon = ic; root.iconColor = col; root.title = ti; root.sub = su
        root.value = val; root.muted = !!mut
        root.bump++
        root.shown = true
        hideT.interval = ms || 1800
        hideT.restart()
    }
    Timer { id: hideT; onTriggered: root.shown = false }

    // звуки інтерфейсу (tools/sfx — під поточну тему)
    function sfx(ev) { if (ev) Quickshell.execDetached([Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/sfx", ev]) }
    function eventSfx(kind, title) {
        if (kind === "error") return "error"
        if (kind === "game") return title.indexOf("вимкнено") >= 0 ? "game-off" : "game-on"
        if (kind === "ac") return "plug"
        if (kind === "usb") return "usb-in"
        if (kind === "usb-off") return "usb-out"
        if (kind === "usb-ok" || kind === "battery" || kind === "eco" || kind === "info") return "notify"
        return ""
    }

    function levelIcon(kind, v, m) {
        if (kind === "volume") return m || v <= 0 ? "󰝟" : v < 34 ? "󰕿" : v < 67 ? "󰖀" : "󰕾"
        if (kind === "mic") return m ? "󰍭" : "󰍬"
        if (kind === "brightness") return v < 34 ? "󰃞" : v < 67 ? "󰃟" : "󰃠"
        if (kind === "kbd") return v <= 0 ? "󰌌" : "󰌌"
        return "󰋽"
    }
    readonly property var levelTitle: ({ volume: "Гучність", mic: "Мікрофон", brightness: "Яскравість", kbd: "Підсвітка клавіатури" })
    readonly property var eventIcon: ({ usb: "󱊞", "usb-off": "󱊟", "usb-ok": "󰕓", ac: "󰚥", battery: "󰁹", layout: "󰌌",
                                        error: "󰀦", game: "󰊴", eco: "󰌪", info: "󰋽", dnd: "󰂛" })

    IpcHandler {
        target: "osd"
        function level(kind: string, percent: int, muted: int): void {
            const p = Math.max(0, Math.min(100, percent))
            root.show(root.levelIcon(kind, p, muted), muted ? root.cSub : root.cAccent, root.levelTitle[kind] || kind,
                      muted ? "вимкнено" : p + "%", p / 100, muted, 1500)
        }
        function event(kind: string, title: string, sub: string): void {
            root.sfx(root.eventSfx(kind, title))
            root.show(root.eventIcon[kind] || "󰋽", kind === "error" ? root.cWarn : (kind === "usb-ok" || kind === "ac") ? root.cGood : root.cAccent,
                      title, sub, -1, false, 3200)
        }
        function progress(kind: string, title: string, percent: int, sub: string): void {
            root.show(root.eventIcon[kind] || "󰋽", root.cAccent, title, sub, Math.max(0, Math.min(100, percent)) / 100, false, 2500)
        }
    }

    // ── зарядка підключена / відключена ──
    property string acPath: ""
    property int acOnline: -1
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/power_supply/*; do [ \"$(cat $d/type 2>/dev/null)\" = Mains ] && echo $d && break; done"]
        stdout: StdioCollector { onStreamFinished: root.acPath = text.trim() }
    }
    Process {
        id: batP
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const on = root.acOnline === 1
                root.sfx(on ? "plug" : "unplug")
                root.show(on ? "󰂄" : "󰁹", on ? root.cGood : root.cAccent, on ? "Зарядку підключено" : "Зарядку відключено",
                          "батарея " + text.trim() + "%", -1, false, 2600)
            }
        }
    }

    // ── підсвітка клавіатури (змінюється й клавішами Fn самим ноутбуком) ──
    property string kbdPath: ""
    property int kbdMax: 0
    property int kbdLast: -1
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/leds/*kbd_backlight*; do [ -e $d/brightness ] && echo $d $(cat $d/max_brightness) && break; done"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim().split(" "); if (p.length === 2) { root.kbdPath = p[0]; root.kbdMax = Number(p[1]) } } }
    }

    // опитування раз на 0.5 с (sysfs не повідомляє про зміни): один маленький cat читає обидва файли
    Process {
        id: pollP
        command: ["cat", root.acPath.length ? root.acPath + "/online" : "/dev/null",
                         root.kbdPath.length ? root.kbdPath + "/brightness" : "/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n")
                let i = 0
                if (root.acPath.length) {
                    const a = Number(v[i++])
                    if (!isNaN(a)) {
                        if (root.acOnline !== -1 && a !== root.acOnline) { root.acOnline = a; batP.running = true }
                        root.acOnline = a
                    }
                }
                if (root.kbdPath.length && root.kbdMax > 0) {
                    const k = Number(v[i])
                    if (!isNaN(k)) {
                        if (root.kbdLast !== -1 && k !== root.kbdLast)
                            root.show("󰌌", k > 0 ? root.cAccent : root.cSub, "Підсвітка клавіатури", k > 0 ? (k + " з " + root.kbdMax) : "вимкнено",
                                      k / root.kbdMax, k === 0, 1500)
                        root.kbdLast = k
                    }
                }
            }
        }
    }
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: if (!pollP.running && (root.acPath.length || root.kbdPath.length)) pollP.running = true
    }

    // ── флешки ──
    Process {
        running: true
        command: [Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/devices", "watch"]
        stdout: SplitParser {
            onRead: (line) => {
                let e = null
                try { e = JSON.parse(line) } catch (x) { return }
                if (e.ev === "added") root.sfx("usb-in")
                if (e.ev === "removed") root.sfx("usb-out")
                if (e.ev === "added") root.show("󱊞", root.cAccent, "Підключено «" + e.label + "»", e.size + " · меню — у панелі вгорі", -1, false, 3500)
                else if (e.ev === "removed") root.show("󱊟", root.cSub, "Від'єднано «" + e.label + "»", "", -1, false, 2200)
            }
        }
    }

    // ── розкладка клавіатури ──
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activelayout") return
            const parts = String(ev.data).split(",")
            const lay = parts.slice(1).join(",")
            const short = ({ "Ukrainian": "UA", "English (US)": "EN", "English (UK)": "EN", "Russian": "RU", "Polish": "PL", "German": "DE" })[lay] || lay.slice(0, 2).toUpperCase()
            root.show("󰌌", root.cAccent, short, lay, -1, false, 1100)
        }
    }

    // ═════════════ саме віконце ═════════════
    PanelWindow {
        id: win
        visible: root.shown || card.opacity > 0.01
        color: "transparent"
        anchors { bottom: true }
        margins { bottom: 110 }
        implicitWidth: 420
        implicitHeight: 130
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}                       // не заважає клікам

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.max(260, Math.min(400, row.implicitWidth + 40))
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            height: root.value >= 0 ? 86 : 70
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            radius: 22
            color: root.cBg
            border.width: 1
            border.color: root.cBorder

            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.88
            transform: Translate { id: slide; y: root.shown ? 0 : 24 }
            Behavior on opacity { NumberAnimation { duration: root.shown ? 160 : 260; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

            // «підстрибнути», коли приходить нова подія, поки віконце вже показане
            Connections {
                target: root
                function onBumpChanged() { if (card.opacity > 0.5) bumpA.restart() }
            }
            SequentialAnimation {
                id: bumpA
                NumberAnimation { target: card; property: "scale"; to: 1.04; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: card; property: "scale"; to: 1.0; duration: 220; easing.type: Easing.OutBack }
            }
            NumberAnimation { target: slide; property: "y"; running: root.shown; from: 24; to: 0; duration: 340; easing.type: Easing.OutBack }

            Rectangle {   // блиск зверху
                anchors.top: parent.top; anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 44; height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            Row {
                id: row
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.value >= 0 ? -9 : 0
                spacing: 14
                Rectangle {
                    width: 40; height: 40; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(root.iconColor.r, root.iconColor.g, root.iconColor.b, 0.16)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.icon
                        font.family: root.iconFont; font.pixelSize: 21
                        color: root.iconColor
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: root.title
                        color: root.cText; font.pixelSize: 15; font.bold: true
                        width: Math.min(implicitWidth, 300); elide: Text.ElideRight
                    }
                    Text {
                        visible: root.sub.length > 0
                        text: root.sub
                        color: root.cSub; font.pixelSize: 12
                        width: Math.min(implicitWidth, 300); elide: Text.ElideRight
                    }
                }
            }
            // смужка рівня / прогресу
            Rectangle {
                visible: root.value >= 0
                x: 18; width: parent.width - 36
                anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                height: 6; radius: 3
                color: Qt.rgba(1, 1, 1, 0.09)
                Rectangle {
                    height: parent.height; radius: 3
                    width: Math.max(height, parent.width * Math.max(0, root.value))
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    opacity: root.muted ? 0.35 : 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.cAccent }
                        GradientStop { position: 1.0; color: root.value > 1 ? root.cWarn : tc.accentSoft }
                    }
                }
            }
        }
    }
}
