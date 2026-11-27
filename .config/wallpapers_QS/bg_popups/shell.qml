import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick

// ═══════════════════════════════════════════════════════════════════
//  Вікна з waybar / бокової панелі: звук, мережа, Bluetooth, система.
//  Відкрити/закрити:  qs -p ~/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup toggle audio|net|bt|sys
//  Закрити:           ... ipc call popup close      (або Esc / клік поза вікном)
//  Дані й дії — ./popctl (python).
//  УВАГА: у ShellRoot імена без «root.» у функціях не завжди знаходять властивості — пиши root.xxx.
// ═══════════════════════════════════════════════════════════════════
ShellRoot {
    id: root
    ThemeColors { id: tc }          // кольори поточної теми (Pause — меню тем)

    property string mode: ""                 // "" | "audio" | "net" | "bt" | "sys" | "power"
    readonly property bool open: mode !== ""
    readonly property string ctl: Quickshell.shellPath("popctl")

    // ── палітра: світле синє скло (під ним блюр Hyprland) ──
    readonly property color cBg: tc.a(tc.bg, 0.88)
    readonly property color cCard: tc.a(tc.border, 0.06)
    readonly property color cCardHover: tc.a(tc.border, 0.12)
    readonly property color cBorder: tc.a(tc.border, 0.16)
    readonly property color cAccent: tc.accent
    readonly property color cOnAccent: tc.onAccent
    readonly property color cText: tc.text
    readonly property color cSub: tc.sub
    readonly property color cWarn: tc.warn
    readonly property color cGood: tc.good
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    property var net: ({})
    property var bt: ({})
    property var sys: ({})
    property var audio: ({})
    property var dev: ({})                   // tools/devices list: знімні диски + змонтовані ФС
    readonly property string devCtl: Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/devices"
    function human(n) {
        n = Number(n || 0)
        const u = ["Б", "КБ", "МБ", "ГБ", "ТБ"]; let i = 0
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
        return (i < 2 || n >= 100 ? n.toFixed(0) : n.toFixed(1)) + " " + u[i]
    }
    function devRun(args, closeAfter) { Quickshell.execDetached([root.devCtl].concat(args)); soon.restart(); if (closeAfter) root.mode = "" }
    property string busy: ""
    property string status: ""
    property string pwFor: ""

    // швидкість мережі (з лічильників rx/tx)
    property real rxRate: 0
    property real txRate: 0
    property var lastNet: null

    property string lastClosed: ""
    property real lastClosedAt: 0

    // ── браузерні джерела (як у плеєрі шпалер): Chrome дає трек без обкладинки, plasma-browser-integration — з нею ──
    function normTitle(t) {
        return String(t || "").replace(/^\(\d+\)\s*/, "").replace(/\s+[-–—]\s+(YouTube|YouTube Music|SoundCloud|Spotify)$/i, "").trim().toLowerCase()
    }
    function sameTrack(a, b) {
        const x = root.normTitle(a.trackTitle), y = root.normTitle(b.trackTitle)
        return x.length > 0 && y.length > 0 && (x === y || x.indexOf(y) !== -1 || y.indexOf(x) !== -1)
    }
    function isPlasma(p) { return !!p && (p.dbusName || "").indexOf("plasma-browser-integration") !== -1 }
    function mediaPlayers() {
        const ps = Mpris.players.values
        const alive = ps.some(q => !root.isPlasma(q) && /chrom|firefox|brave|vivaldi|opera|edge|zen/.test(((q.dbusName || "") + " " + (q.identity || "")).toLowerCase()))
        return ps.filter(p => {
            if (root.isPlasma(p)) return alive                       // «висить» після закриття браузера
            return !ps.some(q => q !== p && root.isPlasma(q) && alive && root.sameTrack(p, q))   // дубль трека з plasma
        })
    }
    function artOf(p) {
        if (!p) return ""
        if (p.trackArtUrl) return p.trackArtUrl
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++)
            if (ps[i] !== p && ps[i].trackArtUrl && root.sameTrack(p, ps[i])) return ps[i].trackArtUrl
        return ""
    }

    IpcHandler {
        target: "popup"
        function toggle(name: string): void {
            if (root.mode === name) { root.mode = ""; return }
            if (root.lastClosed === name && Date.now() - root.lastClosedAt < 350) return
            root.mode = name
        }
        function close(): void { root.mode = "" }
        function open(name: string): void { root.mode = name }      // відкрити (не перемикати) — напр. меню флешок при підключенні
    }

    onModeChanged: {
        root.confirm = ""
        root.status = ""
        root.pwFor = ""
        root.lastNet = null
        if (root.mode !== "") root.refresh()
    }

    function refresh() {
        if (root.mode === "net" && !netP.running) netP.running = true
        if (root.mode === "bt" && !btP.running) btP.running = true
        if (root.mode === "sys" && !sysP.running) sysP.running = true
        if (root.mode === "audio" && !audP.running) audP.running = true
        if ((root.mode === "dev" || root.mode === "sys") && !devP.running) devP.running = true
    }

    function act(key, args) {
        if (actP.running) return
        root.busy = key
        root.status = ""
        actP.command = [root.ctl].concat(args)
        actP.running = true
    }
    // швидкі дії без очікування (гучність, вибір пристрою)
    function fire(args) { Quickshell.execDetached([root.ctl].concat(args)); soon.restart() }
    Timer { id: soon; interval: 350; onTriggered: root.refresh() }
    function sh(cmd) { Quickshell.execDetached(["setsid", "-f", "sh", "-c", cmd]); root.mode = "" }

    function parse(t) {
        if (!t || !String(t).trim().length) return null          // порожня відповідь (диск саме перепідключався тощо) — не помилка
        try { return JSON.parse(t) } catch (e) { console.warn("[popups] JSON: " + e); return null }
    }

    function onNet(j) {
        const e = (j.ethernet || []).find(x => x.connected)
        if (e && root.lastNet && e.rx !== undefined) {
            const dt = (Date.now() - root.lastNet.t) / 1000
            if (dt > 0.3) {
                root.rxRate = Math.max(0, (e.rx - root.lastNet.rx) / dt)
                root.txRate = Math.max(0, (e.tx - root.lastNet.tx) / dt)
            }
        }
        if (e) root.lastNet = { rx: e.rx, tx: e.tx, t: Date.now() }
        root.net = j
    }
    function fmtRate(b) {
        if (b > 1048576) return (b / 1048576).toFixed(1) + " МБ/с"
        if (b > 1024) return (b / 1024).toFixed(0) + " КБ/с"
        return Math.round(b) + " Б/с"
    }

    Process { id: netP; command: [root.ctl, "net"]; stdout: StdioCollector { onStreamFinished: { const j = root.parse(text); if (j) root.onNet(j) } } }
    Process { id: btP;  command: [root.ctl, "bt"];  stdout: StdioCollector { onStreamFinished: { const j = root.parse(text); if (j) root.bt = j } } }
    Process { id: sysP; command: [root.ctl, "sys"]; stdout: StdioCollector { onStreamFinished: { const j = root.parse(text); if (j) root.sys = j } } }
    Process { id: devP; command: [root.devCtl, "list"]; stdout: StdioCollector { onStreamFinished: { const j = root.parse(text); if (j) root.dev = j } } }
    Process { id: audP; command: [root.ctl, "audio"]; stdout: StdioCollector { onStreamFinished: { const j = root.parse(text); if (j) root.audio = j } } }
    Process {
        id: actP
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text)
                if (j && !j.ok) root.status = j.msg || "Не вдалося"
                root.busy = ""
                root.refresh()
            }
        }
    }

    // хвилька cava для вікна звуку (працює лише поки вікно відкрите)
    property var cavaVals: []
    Process {
        id: cavaP
        running: root.mode === "audio"
        command: ["sh", "-c",
            'f="${XDG_RUNTIME_DIR:-/tmp}/popups-cava.conf"; printf "[general]\\nbars = 36\\nframerate = 40\\n[input]\\nmethod = pipewire\\nsource = auto\\n[smoothing]\\nnoise_reduction = 70\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n" > "$f"; exec cava -p "$f"']
        stdout: SplitParser { onRead: (data) => root.cavaVals = data.split(";").filter(x => x.length).map(Number) }
    }

    Timer {
        interval: root.mode === "dev" ? 1000 : root.mode === "audio" ? 1500 : (root.mode === "sys" ? 2000 : 2500)
        repeat: true
        running: root.open
        onTriggered: root.refresh()
    }

    function screenNow() {
        const m = Hyprland.focusedMonitor
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (m && Quickshell.screens[i].name === m.name) return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    // ── меню живлення: що чекає підтвердження (другого натискання) ──
    property string confirm: ""
    Timer { id: confirmReset; interval: 3500; onTriggered: root.confirm = "" }
    readonly property string lockCmd: "~/.config/wallpapers_QS/tools/lock"
    readonly property var powerItems: [
        { id: "lock",     icon: "󰌾", text: "Заблокувати",   key: "L", danger: false, cmd: "sleep 0.3; " + lockCmd },
        { id: "sleep",    icon: "󰤄", text: "Сон",           key: "S", danger: false, cmd: "systemctl suspend" },
        { id: "logout",   icon: "󰍃", text: "Вийти",         key: "E", danger: true,  cmd: "hyprctl dispatch 'hl.dsp.exit()'" },
        { id: "reboot",   icon: "󰜉", text: "Перезапустити", key: "R", danger: true,  cmd: "systemctl reboot" },
        { id: "poweroff", icon: "󰐥", text: "Вимкнути",      key: "P", danger: true,  cmd: "systemctl poweroff" }
    ]
    function power(it) {
        if (it.danger && root.confirm !== it.id) { root.confirm = it.id; confirmReset.restart(); return }
        root.sh(it.cmd)
    }

    HyprlandFocusGrab {
        windows: [win, pwin]
        active: root.open
        onCleared: { root.lastClosed = root.mode; root.lastClosedAt = Date.now(); root.mode = "" }
    }

    // ════════════════════ компоненти ════════════════════
    component Icon: Text {
        font.family: root.iconFont
        font.pixelSize: 18
        color: root.cText
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
    component Label: Text {
        color: root.cText
        font.pixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    component SectionTitle: Label { font.pixelSize: 11; font.bold: true; color: root.cSub; font.letterSpacing: 1 }

    component Switch: Rectangle {
        id: sw
        property bool on: false
        property bool allowed: true
        signal toggled()
        width: 44; height: 24; radius: 12
        opacity: allowed ? 1 : 0.4
        color: on ? root.cAccent : Qt.rgba(1, 1, 1, 0.14)
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: 18; height: 18; radius: 9
            y: 3; x: sw.on ? sw.width - width - 3 : 3
            color: sw.on ? root.cOnAccent : root.cText
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        }
        MouseArea { anchors.fill: parent; enabled: sw.allowed; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }

    component Btn: Rectangle {
        id: b
        property string text: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        property bool active: false
        signal clicked()
        implicitWidth: row.implicitWidth + 24
        height: 30; radius: 10
        color: primary || active ? root.cAccent : (ma.containsMouse ? root.cCardHover : root.cCard)
        border.width: primary || active ? 0 : 1
        border.color: root.cBorder
        scale: ma.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Icon { visible: b.icon.length > 0; text: b.icon; font.pixelSize: 14; color: b.primary || b.active ? root.cOnAccent : (b.danger ? root.cWarn : root.cText) }
            Label { visible: b.text.length > 0; text: b.text; font.pixelSize: 12; font.bold: true; color: b.primary || b.active ? root.cOnAccent : (b.danger ? root.cWarn : root.cText) }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    component ItemRow: Rectangle {
        id: ir
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool highlight: false
        property alias trailing: trail.data
        signal clicked()
        width: parent ? parent.width : 300
        height: 52; radius: 14
        color: highlight ? tc.a(tc.accent, 0.20) : (ma2.containsMouse ? root.cCardHover : "transparent")
        border.width: highlight ? 1 : 0
        border.color: root.cBorder
        Behavior on color { ColorAnimation { duration: 150 } }
        MouseArea { id: ma2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ir.clicked() }
        Rectangle {
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 11
            color: ir.highlight ? root.cAccent : root.cCard
            Behavior on color { ColorAnimation { duration: 180 } }
            Icon { anchors.centerIn: parent; text: ir.icon; color: ir.highlight ? root.cOnAccent : root.cText; font.pixelSize: 17 }
        }
        Column {
            x: 54; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 54 - trail.width - 12
            spacing: 1
            Label { width: parent.width; text: ir.title; font.bold: true }
            Label { width: parent.width; text: ir.sub; visible: text.length > 0; font.pixelSize: 11; color: root.cSub }
        }
        Row { id: trail; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 6 }
    }

    // повзунок гучності: іконка (клік — вимкнути звук), доріжка, відсоток
    component VolSlider: Item {
        id: vs
        property real value: 0              // 0..max
        property real max: 100
        property bool muted: false
        property string icon: "󰕾"
        property string label: ""
        signal moved(real v)
        signal iconClicked()
        property real shown: value
        property bool drag: false
        onValueChanged: if (!drag) shown = value
        width: parent ? parent.width : 300
        height: label.length ? 50 : 36

        Label { visible: vs.label.length > 0; x: 44; width: parent.width - 100; text: vs.label; font.pixelSize: 11; color: root.cSub }
        Rectangle {
            id: ib
            y: vs.label.length ? 14 : 0
            width: 34; height: 34; radius: 11
            color: ibm.containsMouse ? root.cCardHover : root.cCard
            Icon { anchors.centerIn: parent; text: vs.muted ? "󰝟" : vs.icon; font.pixelSize: 16; color: vs.muted ? root.cWarn : root.cText }
            MouseArea { id: ibm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: vs.iconClicked() }
        }
        Item {
            id: track
            x: 44; y: ib.y
            width: parent.width - 44 - 50
            height: 34
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: 3
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle {
                    width: Math.max(6, parent.width * Math.min(1, vs.shown / vs.max))
                    height: parent.height; radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: vs.muted ? root.cSub : root.cAccent }
                        GradientStop { position: 1.0; color: vs.muted ? root.cSub : tc.accent2Soft }
                    }
                    Behavior on width { enabled: !vs.drag; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
            Rectangle {
                width: vs.drag || tma.containsMouse ? 18 : 14; height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(track.width, track.width * Math.min(1, vs.shown / vs.max)) - width / 2
                color: root.cText
                border.width: 2; border.color: root.cAccent
                Behavior on width { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: tma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function upd(mx) { vs.shown = Math.round(Math.max(0, Math.min(1, mx / track.width)) * vs.max); vs.moved(vs.shown) }
                onPressed: (m) => { vs.drag = true; upd(m.x) }
                onPositionChanged: (m) => { if (pressed) upd(m.x) }
                onReleased: vs.drag = false
                onWheel: (w) => { vs.shown = Math.max(0, Math.min(vs.max, vs.shown + (w.angleDelta.y > 0 ? 5 : -5))); vs.moved(vs.shown) }
            }
        }
        Label { x: parent.width - 44; y: ib.y; width: 44; height: 34; horizontalAlignment: Text.AlignRight; text: Math.round(vs.shown) + "%"; font.bold: true; font.pixelSize: 12 }
    }

    // вибір зі списку: кнопка з поточним варіантом і ▾, клік — список з галочкою, вибір — згорнути
    component DevPicker: Column {
        id: pk
        property var options: []           // [{ label, sub, icon, selected, args: [...] }]
        property bool expanded: false
        readonly property var cur: options.find(o => o.selected) || options[0] || null
        width: parent ? parent.width : 300
        spacing: 4
        Rectangle {
            width: parent.width; height: 42; radius: 12
            color: hm.containsMouse || pk.expanded ? root.cCardHover : root.cCard
            border.width: 1; border.color: pk.expanded ? root.cAccent : root.cBorder
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; text: pk.cur ? pk.cur.icon : ""; font.pixelSize: 16; color: root.cAccent }
            Column {
                x: 40; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - 36
                Label { width: parent.width; text: pk.cur ? pk.cur.label : "—"; font.bold: true; font.pixelSize: 12 }
                Label { width: parent.width; visible: !!(pk.cur && pk.cur.sub); text: pk.cur ? (pk.cur.sub || "") : ""; font.pixelSize: 10; color: root.cSub }
            }
            Icon {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: "󰅀"; font.pixelSize: 16; color: root.cSub
                rotation: pk.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
            MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pk.expanded = !pk.expanded }
        }
        Item {
            width: parent.width
            height: pk.expanded ? optCol.implicitHeight : 0
            clip: true
            opacity: pk.expanded ? 1 : 0
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Column {
                id: optCol
                width: parent.width
                spacing: 2
                Repeater {
                    model: pk.options
                    Rectangle {
                        required property var modelData
                        width: optCol.width; height: 38; radius: 10
                        color: om.containsMouse ? root.cCardHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.selected ? "󰄬" : ""; font.pixelSize: 15; color: tc.accent2; width: 18 }
                        Icon { x: 36; anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.pixelSize: 14; color: root.cSub }
                        Column {
                            x: 60; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 70
                            Label { width: parent.width; text: modelData.label; font.pixelSize: 12; font.bold: modelData.selected; opacity: modelData.off ? 0.5 : 1 }
                            Label { width: parent.width; visible: !!modelData.sub; text: modelData.sub || ""; font.pixelSize: 10; color: root.cSub }
                        }
                        MouseArea {
                            id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { for (const a of modelData.args) root.fire(a); pk.expanded = false }
                        }
                    }
                }
            }
        }
    }

    component Bar: Item {
        id: bar
        property real value: 0
        property string label: ""
        property string rtext: ""
        property string icon: ""
        width: parent ? parent.width : 100
        height: 38
        Row {
            spacing: 6
            width: bar.width - rlab.implicitWidth - 10
            clip: true
            Icon { text: bar.icon; font.pixelSize: 13; color: root.cSub; width: 16 }
            Label { text: bar.label; font.pixelSize: 12; color: root.cSub; width: parent.width - 22; elide: Text.ElideRight }
        }
        Label { id: rlab; anchors.right: parent.right; text: bar.rtext; font.pixelSize: 12; font.bold: true }
        Rectangle {
            y: 24; width: parent.width; height: 6; radius: 3
            color: Qt.rgba(1, 1, 1, 0.10)
            Rectangle {
                width: Math.max(6, parent.width * Math.min(1, Math.max(0, bar.value)))
                height: parent.height; radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: bar.value > 0.85 ? root.cWarn : root.cAccent }
                    GradientStop { position: 1.0; color: bar.value > 0.85 ? root.cWarn : tc.accent2Soft }
                }
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    // заголовок вікна: іконка, назва, праворуч — що завгодно
    component Header: Item {
        id: hd
        property string icon: ""
        property string title: ""
        default property alias rightItems: rr.data
        width: parent ? parent.width : 300
        height: 30
        Row {
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: 30; height: 30; radius: 10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.cAccent }
                    GradientStop { position: 1.0; color: tc.accent2Soft }
                }
                Icon { anchors.centerIn: parent; text: hd.icon; font.pixelSize: 16; color: root.cOnAccent }
            }
            Label { anchors.verticalCenter: parent.verticalCenter; text: hd.title; font.pixelSize: 16; font.bold: true }
        }
        Row { id: rr; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8 }
    }

    // ════════════════════ вікно ════════════════════
    PanelWindow {
        id: win
        visible: root.open && root.mode !== "power"
        screen: root.screenNow()
        color: "transparent"
        anchors { top: true; left: root.mode === "audio"; right: root.mode !== "audio" }
        margins { top: 46; left: 14; right: 14 }
        // вікно сталої висоти (до низу екрана), анімується лише картка всередині — без зміни розміру
        // поверхні Wayland на кожному кадрі (саме це давало ривки при розгортанні списків)
        implicitWidth: 420
        implicitHeight: (screen ? screen.height : 1080) - 60
        mask: Region { item: card }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "popups"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: card
            width: 420
            height: body.implicitHeight + 32
            radius: 24
            color: root.cBg
            border.width: 1
            border.color: root.cBorder
            focus: true
            Keys.onEscapePressed: root.mode = ""

            // ледь рожевий відтінок унизу
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.6; color: "transparent" }
                    GradientStop { position: 1.0; color: tc.a(tc.accent2, 0.10) }
                }
            }
            // блиск зверху скла
            Rectangle {
                anchors.top: parent.top; anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 40; height: 1
                color: Qt.rgba(1, 1, 1, 0.22)
            }

            // поява: виїжджає згори з легким пружинням
            opacity: root.open ? 1 : 0
            y: root.open ? 0 : -16
            scale: root.open ? 1 : 0.97
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            layer.enabled: true          // картка малюється як текстура — рівні 60+ кадрів при анімаціях
            layer.smooth: true

            Column {
                id: body
                x: 16; y: 16
                width: parent.width - 32
                spacing: 12

                Loader { width: parent.width; active: root.mode === "audio"; visible: active; sourceComponent: audioView }
                Loader { width: parent.width; active: root.mode === "net"; visible: active; sourceComponent: netView }
                Loader { width: parent.width; active: root.mode === "bt";  visible: active; sourceComponent: btView }
                Loader { width: parent.width; active: root.mode === "sys"; visible: active; sourceComponent: sysView }
                Loader { width: parent.width; active: root.mode === "cal"; visible: active; sourceComponent: calView }
                Loader { width: parent.width; active: root.mode === "dev"; visible: active; sourceComponent: devView }

                Label {
                    width: parent.width
                    visible: root.status.length > 0
                    text: root.status
                    color: root.cWarn
                    wrapMode: Text.Wrap
                    font.pixelSize: 11
                }
            }
        }
    }

    // ════════════════════ ЗВУК ════════════════════
    Component {
        id: audioView
        Column {
            spacing: 12
            readonly property var sinks: root.audio.sinks || []
            readonly property var sources: root.audio.sources || []
            readonly property var apps: root.audio.apps || []
            readonly property var sink: sinks.find(x => x.default) || sinks[0] || null
            readonly property var src: sources.find(x => x.default) || sources[0] || null
            // «Пристрій — порт» для списку; вибір = зробити пристрій основним + перемкнути порт
            function opts(list, kind) {
                const out = []
                for (const d of list) {
                    const ports = d.ports && d.ports.length ? d.ports : [null]
                    for (const p of ports) {
                        const name = p ? p.desc : d.desc
                        const ic = kind === "source" ? (p && /headset/.test(p.name) ? "󰋎" : "󰍬")
                                 : (d.bt || (p && /headphone|headset/.test(p.name)) ? "󰋋" : (p && /speaker/.test(p.name) ? "󰓃" : "󰕾"))
                        const args = [["audio-default", kind, d.name]]
                        if (p) args.push(["audio-port", kind, d.name, p.name])
                        out.push({ label: name + (p && p.off ? " (не підключено)" : ""), sub: p ? d.desc : "",
                                   icon: ic, off: p ? p.off : false,
                                   selected: d.default && (!p || d.port === p.name), args: args })
                    }
                }
                return out
            }
            readonly property var players: root.mediaPlayers()

            Header {
                icon: "󰕾"; title: "Звук"
                Btn { icon: "󰒓"; text: "Мікшер"; onClicked: root.sh("pavucontrol") }
            }

            // хвилька
            Rectangle {
                width: parent.width; height: 56; radius: 14
                color: root.cCard
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: 36
                        Rectangle {
                            required property int index
                            readonly property real v: root.cavaVals.length > index ? root.cavaVals[index] / 100 : 0
                            width: 7; radius: 3.5
                            height: Math.max(4, v * 44)
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(0.55 + v * 0.3, 0.78, 1.0, 0.55 + v * 0.45)
                            Behavior on height { NumberAnimation { duration: 60 } }
                        }
                    }
                }
            }

            SectionTitle { text: "ВИХІД" }
            VolSlider {
                visible: sink !== null
                value: sink ? sink.vol : 0
                max: 150
                muted: sink ? sink.muted : false
                icon: sink && sink.bt ? "󰋋" : "󰕾"
                label: sink ? sink.desc : ""
                onMoved: (v) => { sinkT.go(v); sinkSfx.restart() }
                onIconClicked: root.fire(["audio-mute", "sink", String(sink.id)])
                Timer { id: sinkT; property real v: 0; interval: 60; function go(x) { v = x; if (!running) start() } onTriggered: root.fire(["audio-vol", "sink", String(sink.id), String(v)]) }
                Timer { id: sinkSfx; interval: 260; onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/sfx", "volume"]) }   // «тук» після зміни, як у KDE
            }
            DevPicker { options: opts(sinks, "sink") }

            SectionTitle { text: "МІКРОФОН" }
            VolSlider {
                visible: src !== null
                value: src ? src.vol : 0
                max: 100
                muted: src ? src.muted : false
                icon: "󰍬"
                label: src ? src.desc : ""
                onMoved: (v) => srcT.go(v)
                onIconClicked: root.fire(["audio-mute", "source", String(src.id)])
                Timer { id: srcT; property real v: 0; interval: 60; function go(x) { v = x; if (!running) start() } onTriggered: root.fire(["audio-vol", "source", String(src.id), String(v)]) }
            }
            DevPicker { options: opts(sources, "source") }

            SectionTitle { text: "ПРОГРАМИ"; visible: apps.length > 0 }
            Repeater {
                model: apps
                VolSlider {
                    required property var modelData
                    value: modelData.vol
                    max: 150
                    muted: modelData.muted
                    icon: "󰎆"
                    label: modelData.name + (modelData.media ? " · " + modelData.media : "")
                    onMoved: (v) => appT.go(v)
                    onIconClicked: root.fire(["audio-mute", "app", String(modelData.id)])
                    Timer { id: appT; property real v: 0; interval: 60; function go(x) { v = x; if (!running) start() } onTriggered: root.fire(["audio-vol", "app", String(modelData.id), String(v)]) }
                }
            }

            SectionTitle { text: "ПЛЕЄРИ"; visible: players.length > 0 }
            Repeater {
                model: players
                Rectangle {
                    required property var modelData
                    readonly property var p: modelData
                    width: parent.width; height: 74; radius: 16
                    color: root.cCard
                    border.width: 1; border.color: root.cBorder
                    Rectangle {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        width: 54; height: 54; radius: 12; clip: true
                        color: root.cCardHover
                        Image { id: pArt; anchors.fill: parent; source: root.artOf(p); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: 128 }
                        Icon { anchors.centerIn: parent; visible: pArt.status !== Image.Ready; text: "󰝚"; color: root.cSub }
                    }
                    Column {
                        x: 74; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 74 - 120
                        spacing: 2
                        Label { width: parent.width; text: String(p.trackTitle || p.identity || "").replace(/^\(\d+\)\s*/, "").replace(/\s+[-–—]\s+YouTube$/i, ""); font.bold: true; elide: Text.ElideRight }
                        Label { width: parent.width; text: (p.trackArtist || "") + (p.trackArtist ? " · " : "") + (root.isPlasma(p) ? "Браузер" : (p.identity || "")); font.pixelSize: 11; color: root.cSub; elide: Text.ElideRight }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Btn { width: 32; icon: "󰒮"; onClicked: p.previous() }
                        Btn { width: 38; primary: true; icon: p.isPlaying ? "󰏤" : "󰐊"; onClicked: p.togglePlaying() }
                        Btn { width: 32; icon: "󰒭"; onClicked: p.next() }
                    }
                }
            }
        }
    }

    // ════════════════════ МЕРЕЖА ════════════════════
    Component {
        id: netView
        Column {
            spacing: 12
            readonly property var eth: root.net.ethernet || []
            readonly property var nets: root.net.wifi || []
            readonly property var act: eth.find(x => x.connected) || null
            readonly property var profiles: root.net.profiles || []

            Header {
                icon: "󰛳"; title: "Мережа"
                Label {
                    text: root.net.active ? "● Підключено" : "● Немає з'єднання"
                    color: root.net.active ? root.cGood : root.cWarn
                    font.pixelSize: 12
                }
            }

            // ── активне з'єднання: деталі й швидкість ──
            Rectangle {
                width: parent.width
                visible: act !== null
                height: detCol.implicitHeight + 24; radius: 16
                color: root.cCard; border.width: 1; border.color: root.cBorder
                Column {
                    id: detCol
                    x: 14; y: 12; width: parent.width - 28
                    spacing: 8
                    Row {
                        spacing: 10
                        Icon { text: "󰈀"; font.pixelSize: 22; color: root.cAccent }
                        Column {
                            Label { text: act ? act.name : ""; font.bold: true }
                            Label { text: act ? ("Дротове · " + act.speed + " Мбіт/с · " + act.dev) : ""; font.pixelSize: 11; color: root.cSub }
                        }
                    }
                    Row {
                        spacing: 18
                        Row { spacing: 6; Icon { text: "󰇚"; font.pixelSize: 14; color: root.cGood } Label { text: root.fmtRate(root.rxRate); font.bold: true } }
                        Row { spacing: 6; Icon { text: "󰕒"; font.pixelSize: 14; color: root.cAccent } Label { text: root.fmtRate(root.txRate); font.bold: true } }
                    }
                    Grid {
                        columns: 2; columnSpacing: 16; rowSpacing: 3
                        Label { text: "IP"; color: root.cSub; font.pixelSize: 12 }
                        Label { text: act ? act.ip : ""; font.pixelSize: 12 }
                        Label { text: "Шлюз"; color: root.cSub; font.pixelSize: 12 }
                        Label { text: act ? act.gateway : ""; font.pixelSize: 12 }
                        Label { text: "DNS"; color: root.cSub; font.pixelSize: 12 }
                        Label { text: act ? (act.dns || []).join(", ") : ""; font.pixelSize: 12 }
                        Label { text: "MAC"; color: root.cSub; font.pixelSize: 12 }
                        Label { text: act ? act.mac : ""; font.pixelSize: 12 }
                    }
                    Row {
                        spacing: 8
                        Btn { text: root.busy === "eth" ? "…" : "Відключити"; danger: true; icon: "󰅖"; onClicked: root.act("eth", ["net-down", act.name]) }
                        Btn { text: "Скопіювати IP"; icon: "󰆏"; onClicked: Quickshell.execDetached(["sh", "-c", "printf %s '" + act.ip + "' | wl-copy"]) }
                    }
                }
            }
            ItemRow {
                visible: act === null && eth.length > 0
                width: parent.width
                icon: "󰈂"
                title: eth.length ? (eth[0].name || eth[0].dev) : ""
                sub: "Кабель не підключено або з'єднання вимкнено"
                trailing: Btn { text: "Підключити"; primary: true; visible: eth.length > 0 && eth[0].name; onClicked: root.act("eth", ["net-up", eth[0].name]) }
            }

            // ── Wi-Fi ──
            Item {
                width: parent.width; height: 26
                SectionTitle { text: "WI-FI"; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    allowed: root.net.wifiHw === true
                    on: root.net.wifiOn === true
                    onToggled: root.act("wifi", ["wifi", on ? "off" : "on"])
                }
            }
            Rectangle {
                width: parent.width
                visible: root.net.wifiHw !== true
                height: noWifi.implicitHeight + 20; radius: 12
                color: root.cCard
                Label {
                    id: noWifi
                    x: 12; y: 10; width: parent.width - 24
                    wrapMode: Text.Wrap; elide: Text.ElideNone
                    color: root.cSub; font.pixelSize: 12
                    text: root.net.wifiNote || "Wi-Fi-адаптер не знайдено"
                }
            }
            Flickable {
                width: parent.width
                visible: nets.length > 0
                height: Math.min(nets.length * 54, 54 * 5)
                contentHeight: netCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: netCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: nets
                        Column {
                            required property var modelData
                            width: netCol.width
                            spacing: 4
                            ItemRow {
                                width: parent.width
                                icon: modelData.signal > 75 ? "󰤨" : modelData.signal > 50 ? "󰤥" : modelData.signal > 25 ? "󰤢" : "󰤟"
                                highlight: modelData.active
                                title: modelData.ssid
                                sub: (modelData.active ? "Підключено · " : (modelData.known ? "Збережена · " : "")) + "сигнал " + modelData.signal + "%" + (modelData.secure ? " · 󰌾" : " · відкрита")
                                onClicked: {
                                    if (modelData.active) root.act("w:" + modelData.ssid, ["net-down", modelData.ssid])
                                    else if (modelData.secure && !modelData.known) root.pwFor = modelData.ssid
                                    else root.act("w:" + modelData.ssid, ["wifi-connect", modelData.ssid])
                                }
                                trailing: Btn { text: root.busy === "w:" + modelData.ssid ? "…" : (modelData.active ? "Відключити" : "Підключити"); primary: !modelData.active }
                            }
                            Row {
                                visible: root.pwFor === modelData.ssid
                                spacing: 6
                                x: 54
                                Rectangle {
                                    width: netCol.width - 54 - okBtn.width - 6; height: 30; radius: 10
                                    color: Qt.rgba(1, 1, 1, 0.08); border.width: 1; border.color: root.cBorder
                                    TextInput {
                                        id: pw
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: root.cText; font.pixelSize: 13
                                        echoMode: TextInput.Password
                                        focus: root.pwFor === modelData.ssid
                                        onAccepted: okBtn.clicked()
                                        Text { anchors.verticalCenter: parent.verticalCenter; visible: !pw.text.length; text: "Пароль"; color: root.cSub; font.pixelSize: 13 }
                                    }
                                }
                                Btn {
                                    id: okBtn
                                    primary: true; text: "OK"
                                    onClicked: { root.act("w:" + modelData.ssid, ["wifi-connect", modelData.ssid, pw.text]); root.pwFor = "" }
                                }
                            }
                        }
                    }
                }
            }

            // ── збережені з'єднання ──
            SectionTitle { text: "ЗБЕРЕЖЕНІ З'ЄДНАННЯ"; visible: profiles.length > 0 }
            Repeater {
                model: profiles
                ItemRow {
                    required property var modelData
                    width: parent.width; height: 44
                    icon: modelData.type === "wifi" ? "󰖩" : modelData.type === "vpn" ? "󰖂" : "󰈀"
                    title: modelData.name
                    sub: modelData.active ? "Активне · " + modelData.dev : "Не активне"
                    trailing: Btn {
                        text: root.busy === "p:" + modelData.name ? "…" : (modelData.active ? "Вимкнути" : "Увімкнути")
                        onClicked: root.act("p:" + modelData.name, ["net-profile", modelData.active ? "down" : "up", modelData.name])
                    }
                }
            }

            Row {
                spacing: 8
                Btn { icon: "󰐕"; text: "Додати з'єднання"; onClicked: root.sh("nm-connection-editor --create") }
                Btn { icon: "󰒓"; text: "Налаштування"; onClicked: root.sh("nm-connection-editor") }
            }
        }
    }

    // ════════════════════ BLUETOOTH ════════════════════
    Component {
        id: btView
        Column {
            spacing: 12
            readonly property var devs: root.bt.devices || []
            readonly property var paired: devs.filter(d => d.paired)
            readonly property var found: devs.filter(d => !d.paired)
            readonly property bool scanning: root.busy === "scan" || root.bt.discovering === true

            function devIcon(i) {
                if (/headset|headphone|audio/.test(i)) return "󰋋"
                if (/mouse/.test(i)) return "󰍽"
                if (/keyboard/.test(i)) return "󰌌"
                if (/phone/.test(i)) return "󰏲"
                if (/computer/.test(i)) return "󰟀"
                if (/gaming|joystick/.test(i)) return "󰊴"
                return "󰂯"
            }
            function devType(i) {
                if (/headset|headphone/.test(i)) return "Навушники"
                if (/audio/.test(i)) return "Аудіо"
                if (/mouse/.test(i)) return "Миша"
                if (/keyboard/.test(i)) return "Клавіатура"
                if (/phone/.test(i)) return "Телефон"
                if (/computer/.test(i)) return "Комп'ютер"
                if (/gaming|joystick/.test(i)) return "Геймпад"
                return "Пристрій"
            }
            function sig(r) { return r === undefined ? "" : (r > -60 ? " · сигнал сильний" : r > -75 ? " · сигнал середній" : " · сигнал слабкий") }

            Header {
                icon: root.bt.powered ? "󰂯" : "󰂲"; title: "Bluetooth"
                Switch {
                    allowed: root.bt.available === true && root.busy !== "power"
                    on: root.bt.powered === true
                    onToggled: root.act("power", ["bt-power", on ? "off" : "on"])
                }
            }

            Label { visible: root.bt.available === false; text: "Bluetooth-адаптер не знайдено"; color: root.cSub }
            Label { visible: root.bt.available === true && !root.bt.powered; text: "Bluetooth вимкнено — увімкни перемикачем угорі"; color: root.cSub }

            Rectangle {
                visible: root.bt.powered === true
                width: parent.width; height: 50; radius: 14
                color: root.cCard
                Column {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    Label { text: "Видимий для інших"; font.bold: true }
                    Label { text: "ім'я: " + (root.bt.alias || ""); font.pixelSize: 11; color: root.cSub }
                }
                Switch {
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    on: root.bt.discoverable === true
                    onToggled: root.act("disc", ["bt-discoverable", on ? "off" : "on"])
                }
            }

            SectionTitle { text: "МОЇ ПРИСТРОЇ"; visible: paired.length > 0 }
            Repeater {
                model: paired
                ItemRow {
                    required property var modelData
                    width: parent.width
                    icon: devIcon(modelData.icon)
                    highlight: modelData.connected
                    title: modelData.name
                    sub: devType(modelData.icon) + " · " + (modelData.connected ? "підключено" : "не підключено")
                         + (modelData.battery >= 0 ? " · 󰁹 " + modelData.battery + "%" : "") + sig(modelData.rssi)
                    trailing: [
                        Btn {
                            text: root.busy === modelData.mac ? "…" : (modelData.connected ? "Відключити" : "Підключити")
                            primary: !modelData.connected
                            onClicked: root.act(modelData.mac, [modelData.connected ? "bt-disconnect" : "bt-connect", modelData.mac])
                        },
                        Btn { icon: "󰆴"; danger: true; width: 30; onClicked: root.act(modelData.mac, ["bt-remove", modelData.mac]) }
                    ]
                }
            }

            Btn {
                visible: root.bt.powered === true
                width: parent.width
                height: 36
                primary: !scanning
                active: scanning
                icon: scanning ? "󰑐" : "󰐕"
                text: scanning ? "Шукаю пристрої поруч…" : "Додати пристрій"
                onClicked: if (!scanning) root.act("scan", ["bt-scan"])
            }
            Label {
                visible: scanning && found.length === 0
                width: parent.width; wrapMode: Text.Wrap; elide: Text.ElideNone
                text: "Переведи пристрій у режим створення пари (зазвичай — затиснути кнопку живлення / Bluetooth)."
                color: root.cSub; font.pixelSize: 11
            }

            SectionTitle { text: "ЗНАЙДЕНІ ПОРУЧ"; visible: found.length > 0 }
            Flickable {
                width: parent.width
                visible: found.length > 0
                height: Math.min(found.length * 54, 54 * 4)
                contentHeight: foundCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: foundCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: found
                        ItemRow {
                            required property var modelData
                            width: foundCol.width
                            icon: devIcon(modelData.icon)
                            title: modelData.name
                            sub: devType(modelData.icon) + " · новий" + sig(modelData.rssi)
                            onClicked: root.act(modelData.mac, ["bt-connect", modelData.mac])
                            trailing: Btn { text: root.busy === modelData.mac ? "Пару створюю…" : "З'єднати"; primary: true; onClicked: root.act(modelData.mac, ["bt-connect", modelData.mac]) }
                        }
                    }
                }
            }

            Row {
                spacing: 8
                visible: root.bt.available === true
                Btn { icon: "󰒓"; text: "Налаштування Bluetooth"; onClicked: root.sh("blueman-manager") }
                Btn { icon: "󰂳"; text: "Файл на пристрій"; onClicked: root.sh("blueman-sendto") }
            }
        }
    }

    // ════════════════════ ДИСКИ Й ПРИСТРОЇ (флешки) ════════════════════
    Component {
        id: devView
        Column {
            spacing: 12
            readonly property var drives: (root.dev.drives || [])

            Header {
                icon: "󱊞"; title: "Диски й пристрої"
                Row {
                    spacing: 6
                    Btn { icon: "󰉋"; text: "Файли"; onClicked: root.sh("dolphin") }
                }
            }

            Label {
                visible: drives.length === 0
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                topPadding: 14; bottomPadding: 14
                text: "Знімних дисків немає\nпідключи флешку — вона змонтується сама"
                color: root.cSub; font.pixelSize: 13
            }

            Repeater {
                model: drives
                Rectangle {
                    id: dcard
                    required property var modelData
                    readonly property var d: modelData
                    readonly property var ej: d.eject || ({})
                    readonly property bool ejecting: ej.stage === "sync" || ej.stage === "unmount" || ej.stage === "format"
                    property bool fmtOpen: false
                    property string fmtFs: "exfat"
                    property bool fmtConfirm: false
                    width: parent.width
                    height: dcol.implicitHeight + 24
                    radius: 16
                    color: root.cCard
                    border.width: 1; border.color: root.cBorder

                    Column {
                        id: dcol
                        x: 12; y: 12
                        width: parent.width - 24
                        spacing: 10

                        // заголовок диска
                        Item {
                            width: parent.width; height: 38
                            Rectangle {
                                width: 38; height: 38; radius: 12
                                color: tc.a(tc.accent, 0.16)
                                Icon { anchors.centerIn: parent; text: d.busy ? "󱊟" : "󱊞"; color: root.cAccent; font.pixelSize: 19 }
                            }
                            Column {
                                x: 48; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 48 - ejectBtn.width - 8
                                Label { width: parent.width; text: d.label; font.bold: true; elide: Text.ElideRight }
                                Label {
                                    width: parent.width; font.pixelSize: 11; color: root.cSub; elide: Text.ElideRight
                                    text: root.human(d.size) + (d.tran ? " · " + d.tran.toUpperCase() : "")
                                          + (d.read > 1024 || d.write > 1024 ? "  ·  ↓ " + root.fmtRate(d.read) + "  ↑ " + root.fmtRate(d.write) : "")
                                }
                            }
                            Btn {
                                id: ejectBtn
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                icon: "󰕓"
                                text: dcard.ej.stage === "format" ? "Форматую…" : dcard.ejecting ? "Від'єдную…" : (dcard.ej.stage === "done" ? "Можна витягати" : "Від'єднати")
                                primary: dcard.ej.stage !== "done"
                                onClicked: if (!dcard.ejecting) root.devRun(["eject", d.path], false)
                            }
                        }

                        Row {
                            spacing: 6
                            Btn { icon: "󰋊"; text: "Форматувати"; active: dcard.fmtOpen; onClicked: { dcard.fmtOpen = !dcard.fmtOpen; dcard.fmtConfirm = false } }
                            Btn { icon: "󰉋"; text: "Відкрити"; visible: d.parts.length > 0; onClicked: root.devRun(["open", d.parts[0].path], true) }
                        }
                        Label {
                            visible: d.parts.length === 0 && !dcard.fmtOpen && !dcard.ejecting
                            width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 12; color: root.cWarn
                            text: "На диску немає розділу з файлами — натисни «Форматувати», щоб ним користуватися"
                        }

                        // ── форматування ──
                        Column {
                            visible: dcard.fmtOpen && !dcard.ejecting
                            width: parent.width
                            spacing: 8
                            Flow {
                                width: parent.width; spacing: 6
                                Repeater {
                                    model: [ { v: "exfat", t: "exFAT", h: "рекомендовано: великі файли, Windows, Mac, ТВ, телефони" },
                                             { v: "vfat",  t: "FAT32", h: "старі пристрої, магнітоли; файли до 4 ГБ" },
                                             { v: "ntfs",  t: "NTFS",  h: "для Windows" },
                                             { v: "ext4",  t: "ext4",  h: "лише для Linux" } ]
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool on: dcard.fmtFs === modelData.v
                                        width: ft.implicitWidth + 22; height: 30; radius: 10
                                        color: on ? root.cAccent : (fm.containsMouse ? root.cCardHover : root.cCard)
                                        border.width: on ? 0 : 1; border.color: root.cBorder
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                        Label { id: ft; anchors.centerIn: parent; text: modelData.t; font.pixelSize: 12; font.bold: parent.on; color: parent.on ? root.cOnAccent : root.cText }
                                        MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { dcard.fmtFs = modelData.v; dcard.fmtConfirm = false } }
                                    }
                                }
                            }
                            Label {
                                width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 11; color: root.cSub
                                text: ({ exfat: "рекомендовано: великі файли, Windows, Mac, ТВ, телефони", vfat: "старі пристрої, магнітоли; файли до 4 ГБ",
                                         ntfs: "для Windows", ext4: "лише для Linux" })[dcard.fmtFs]
                            }
                            Rectangle {
                                width: parent.width; height: 34; radius: 10
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: lbl.activeFocus ? 1 : 1
                                border.color: lbl.activeFocus ? root.cAccent : root.cBorder
                                TextInput {
                                    id: lbl
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: root.cText; font.pixelSize: 13
                                    maximumLength: dcard.fmtFs === "vfat" ? 11 : 32
                                    clip: true
                                    Label { anchors.verticalCenter: parent.verticalCenter; visible: !lbl.text.length; text: "Назва флешки (необов'язково)"; color: root.cSub; font.pixelSize: 12 }
                                }
                            }
                            Item {
                                width: parent.width; height: 32
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - fbtn.width - 10; wrapMode: Text.Wrap
                                    text: "Усі файли на «" + d.label + "» буде знищено"
                                    color: root.cWarn; font.pixelSize: 11
                                }
                                Btn {
                                    id: fbtn
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    icon: "󰋊"
                                    text: dcard.fmtConfirm ? "Точно? Ще раз" : "Форматувати"
                                    danger: true
                                    primary: dcard.fmtConfirm
                                    onClicked: {
                                        if (!dcard.fmtConfirm) { dcard.fmtConfirm = true; return }
                                        dcard.fmtConfirm = false; dcard.fmtOpen = false
                                        root.devRun(["format", d.path, dcard.fmtFs, lbl.text], false)
                                    }
                                }
                            }
                        }

                        // запис / від'єднання: прогрес
                        Column {
                            visible: d.busy || dcard.ejecting || dcard.ej.stage === "error"
                            width: parent.width
                            spacing: 5
                            Label {
                                width: parent.width; font.pixelSize: 12
                                color: dcard.ej.stage === "error" ? root.cWarn : root.cText
                                text: dcard.ej.stage === "error" ? (dcard.ej.msg || "Не вдалося від'єднати")
                                    : dcard.ej.stage === "sync" ? "Дописую дані перед від'єднанням… " + (dcard.ej.pct || 0) + "%  (ще " + root.human(dcard.ej.left) + ")"
                                    : dcard.ej.stage === "unmount" ? "Відмонтовую…"
                                    : dcard.ej.stage === "format" ? "Форматую… " + (dcard.ej.msg || "")
                                    : "Йде запис… незаписаних даних: " + root.human(d.pending)
                                wrapMode: Text.Wrap
                            }
                            Rectangle {
                                visible: dcard.ej.stage !== "error"
                                width: parent.width; height: 6; radius: 3
                                color: Qt.rgba(1, 1, 1, 0.08)
                                clip: true
                                Rectangle {
                                    // відомий відсоток — смужка; просто запис — «біжуча» смужка
                                    readonly property bool known: dcard.ejecting
                                    height: parent.height; radius: 3
                                    width: known ? parent.width * Math.max(0.04, (dcard.ej.pct || 0) / 100) : parent.width * 0.3
                                    color: root.cAccent
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                    SequentialAnimation on x {
                                        running: !parent.known && parent.visible
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -60; to: 360; duration: 1300; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }

                        // розділи
                        Repeater {
                            model: d.parts
                            Item {
                                required property var modelData
                                readonly property var p: modelData
                                width: dcol.width; height: 46
                                Column {
                                    width: parent.width - pbtns.width - 10
                                    spacing: 4
                                    Label {
                                        width: parent.width; elide: Text.ElideRight; font.pixelSize: 12
                                        text: p.label + "  ·  " + (p.fs || "") + (p.mount ? "" : "  ·  не змонтовано")
                                    }
                                    Rectangle {
                                        width: parent.width; height: 5; radius: 2.5
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        visible: p.mount.length > 0 && p.size > 0
                                        Rectangle {
                                            height: parent.height; radius: 2.5
                                            width: parent.width * Math.min(1, p.used / Math.max(1, p.size))
                                            color: p.used / Math.max(1, p.size) > 0.9 ? root.cWarn : root.cAccent
                                        }
                                    }
                                    Label {
                                        font.pixelSize: 10; color: root.cSub
                                        text: p.mount ? "зайнято " + root.human(p.used) + " з " + root.human(p.size) + " · вільно " + root.human(p.size - p.used) : root.human(p.size)
                                    }
                                }
                                Row {
                                    id: pbtns
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Btn { icon: "󰉋"; onClicked: root.devRun(["open", p.path], true) }
                                    Btn { icon: "󰋊"; visible: p.mount.length > 0; onClicked: root.sh("filelight '" + p.mount + "'") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════ СИСТЕМА ════════════════════
    Component {
        id: sysView
        Column {
            spacing: 12
            readonly property var bat: root.sys.battery || null
            readonly property var gpu: root.sys.gpu || null

            function statusUk(s) {
                return ({ Charging: "Заряджається", Discharging: "Від батареї", Full: "Заряджено",
                          "Not charging": "Не заряджається" })[s] || s || ""
            }
            function batIcon(p, s) {
                if (s === "Charging") return "󰂄"
                const ic = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
                return ic[Math.max(0, Math.min(10, Math.round(p / 10)))]
            }

            Header {
                icon: "󰍛"; title: "Система"
                Label { text: root.sys.uptime ? "працює " + root.sys.uptime : ""; color: root.cSub; font.pixelSize: 11 }
            }

            Rectangle {
                width: parent.width; height: 76; radius: 16
                color: root.cCard; border.width: 1; border.color: root.cBorder
                visible: bat !== null
                Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 36; color: root.cAccent; text: bat ? batIcon(bat.pct, bat.status) : "" }
                Column {
                    x: 66; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 66 - 14
                    spacing: 2
                    Row {
                        spacing: 8
                        Label { text: bat ? bat.pct + "%" : ""; font.pixelSize: 21; font.bold: true }
                        Label { anchors.bottom: parent.bottom; anchors.bottomMargin: 3; text: bat ? statusUk(bat.status) : ""; color: root.cSub; font.pixelSize: 12 }
                    }
                    Label {
                        width: parent.width
                        color: root.cSub; font.pixelSize: 11
                        text: bat ? [bat.eta ? "залишилось " + bat.eta : "", bat.watts > 0 ? bat.watts + " Вт" : "",
                                     bat.health > 0 ? "стан батареї " + bat.health + "%" : "", bat.ac ? "від мережі 󰚥" : ""].filter(x => x).join(" · ") : ""
                    }
                }
            }

            SectionTitle { text: "РЕЖИМ ЖИВЛЕННЯ" }
            Row {
                width: parent.width
                spacing: 6
                Repeater {
                    model: [
                        { id: "power-saver", name: "Економія", icon: "󰌪" },
                        { id: "balanced", name: "Баланс", icon: "󰾅" },
                        { id: "performance", name: "Потужність", icon: "󰓅" }
                    ]
                    Btn {
                        required property var modelData
                        width: (parent.width - 12) / 3
                        icon: modelData.icon
                        text: modelData.name
                        active: root.sys.profile === modelData.id
                        onClicked: root.act("profile", ["profile", modelData.id])
                    }
                }
            }

            SectionTitle { text: "НАВАНТАЖЕННЯ" }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 16
                rowSpacing: 6
                Bar { width: (parent.width - 16) / 2; icon: "󰻠"; label: "Процесор"; value: (root.sys.cpu || 0) / 100; rtext: (root.sys.cpu || 0) + "%" }
                Bar { width: (parent.width - 16) / 2; icon: "󰔏"; label: "Температура"; value: (root.sys.temp || 0) / 100; rtext: (root.sys.temp || 0) + "°C" }
                Bar {
                    width: (parent.width - 16) / 2; icon: "󰍛"; label: "Пам'ять"
                    value: root.sys.ram ? root.sys.ram.used / root.sys.ram.total : 0
                    rtext: root.sys.ram ? root.sys.ram.used + " / " + root.sys.ram.total + " ГБ" : ""
                }
                Bar {
                    width: (parent.width - 16) / 2; icon: "󰋊"; label: "Диск"
                    value: root.sys.disk ? root.sys.disk.used / root.sys.disk.total : 0
                    rtext: root.sys.disk ? root.sys.disk.used + " / " + root.sys.disk.total + " ГБ" : ""
                }
            }

            SectionTitle { text: "ДИСКИ" }
            Column {
                width: parent.width
                spacing: 4
                Repeater {
                    model: (root.dev.mounts || [])
                    Rectangle {
                        required property var modelData
                        readonly property var m: modelData
                        readonly property real frac: m.used / Math.max(1, m.size)
                        width: parent.width; height: 46; radius: 12
                        color: dma.containsMouse ? root.cCardHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; text: m.removable ? "󱊞" : (m.mount === "/" ? "󰋊" : "󰉋"); color: root.cSub; font.pixelSize: 16 }
                        Column {
                            x: 34; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34 - 12
                            spacing: 4
                            Item {
                                width: parent.width; height: 16
                                Label { text: m.mount === "/" ? "Система (/)" : m.mount; font.pixelSize: 12; width: parent.width - 150; elide: Text.ElideMiddle }
                                Label { anchors.right: parent.right; text: root.human(m.used) + " / " + root.human(m.size); font.pixelSize: 12; font.bold: true }
                            }
                            Rectangle {
                                width: parent.width; height: 5; radius: 2.5
                                color: Qt.rgba(1, 1, 1, 0.08)
                                Rectangle {
                                    height: parent.height; radius: 2.5
                                    width: parent.width * Math.min(1, frac)
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: frac > 0.9 ? root.cWarn : root.cAccent }
                                        GradientStop { position: 1.0; color: frac > 0.9 ? root.cWarn : tc.accentSoft }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.sh("filelight '" + m.mount + "'")       // що саме займає місце
                        }
                    }
                }
                Label { text: "клік по диску — що займає місце (Filelight)"; font.pixelSize: 10; color: root.cSub; leftPadding: 8 }
            }

            SectionTitle { text: "ВІДЕОКАРТИ" }
            Column {
                width: parent.width
                spacing: 6
                Repeater {
                    model: root.sys.gpus || []
                    Bar {
                        required property var modelData
                        width: parent.width
                        icon: modelData.kind === "igpu" ? "󰍹" : "󰢮"
                        label: modelData.name
                        value: modelData.util / 100
                        rtext: modelData.sleeping ? "спить 󰒲" : [modelData.util + "%", modelData.temp ? modelData.temp + "°C" : "",
                               modelData.watts ? modelData.watts + " Вт" : "", modelData.freq ? modelData.freq + " МГц" : ""].filter(x => x).join(" · ")
                    }
                }
                Bar {
                    visible: gpu !== null && !!gpu.memTotal
                    width: parent.width; icon: "󰘚"; label: "Відеопам'ять NVIDIA"
                    value: gpu && gpu.memTotal ? gpu.memUsed / gpu.memTotal : 0
                    rtext: gpu && gpu.memTotal ? (gpu.memUsed / 1024).toFixed(1) + " / " + (gpu.memTotal / 1024).toFixed(0) + " ГБ" : ""
                }
            }

            SectionTitle { text: "ПРОЦЕСИ" }
            Column {
                width: parent.width
                spacing: 2
                Repeater {
                    model: root.sys.procs || []
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 28; radius: 8
                        color: pma.containsMouse ? root.cCardHover : "transparent"
                        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true }
                        Label { x: 8; width: parent.width - 190; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.pixelSize: 12 }
                        Label { x: parent.width - 180; width: 60; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: modelData.cpu.toFixed(1) + "%"; font.pixelSize: 12; color: modelData.cpu > 50 ? root.cWarn : root.cText }
                        Label { x: parent.width - 112; width: 70; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: modelData.mem + " МБ"; font.pixelSize: 12; color: root.cSub }
                        Icon {
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            visible: pma.containsMouse || kma.containsMouse
                            text: "󰅖"; font.pixelSize: 14; color: root.cWarn
                            MouseArea { id: kma; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.act("kill", ["kill", String(modelData.pid)]) }
                        }
                    }
                }
            }

            Row {
                spacing: 8
                Btn { icon: "󰄨"; text: "Диспетчер завдань"; primary: true; onClicked: root.sh("setsid -f missioncenter") }
                Btn { icon: "󰒓"; text: "Живлення й сон"; onClicked: root.sh("~/.config/theme-switch/bin/hypr-settings") }
            }
        }
    }

    // ════════════════════ МЕНЮ ЖИВЛЕННЯ ════════════════════
    PanelWindow {
        id: pwin
        visible: root.mode === "power"
        screen: root.screenNow()
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "popups"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: dim
            anchors.fill: parent
            color: Qt.rgba(0.0, 0.0, 0.02, 0.58)
            opacity: pwin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            focus: pwin.visible
            Keys.onEscapePressed: root.mode = ""
            Keys.onPressed: (e) => {
                const k = e.text.toUpperCase()
                const it = root.powerItems.find(x => x.key === k)
                if (it) { root.power(it); e.accepted = true }
            }
            MouseArea { anchors.fill: parent; onClicked: root.mode = "" }

            Rectangle {
                id: pcard
                anchors.centerIn: parent
                width: prow.implicitWidth + 36
                height: prow.implicitHeight + 74
                radius: 24
                // мінімалістичне темне скло (без кольорових градієнтів)
                color: tc.a(tc.bg, 0.93)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)
                opacity: pwin.visible ? 1 : 0
                scale: pwin.visible ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent }       // клік по картці не закриває меню

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    text: root.confirm.length ? "Натисни ще раз, щоб підтвердити" : "Живлення"
                    font.pixelSize: 13
                    font.letterSpacing: 0.5
                    color: root.confirm.length ? tc.warn : root.cSub
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                Row {
                    id: prow
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 48
                    spacing: 8
                    Repeater {
                        model: root.powerItems
                        Rectangle {
                            id: pbtn
                            required property var modelData
                            required property int index
                            readonly property bool armed: root.confirm === modelData.id
                            readonly property color tint: modelData.danger ? tc.warn : tc.accent
                            width: 96; height: 100; radius: 16
                            color: armed ? tc.a(tc.warn, 0.10) : (pm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.width: armed ? 1 : 0
                            border.color: tc.warn
                            Behavior on color { ColorAnimation { duration: 140 } }

                            // поява по черзі
                            opacity: 0
                            transform: Translate { id: ptr; y: 10 }
                            Connections {
                                target: pwin
                                function onVisibleChanged() {
                                    if (pwin.visible) { pbtn.opacity = 0; ptr.y = 10; pin.restart() }
                                }
                            }
                            Component.onCompleted: if (pwin.visible) pin.restart()
                            SequentialAnimation {
                                id: pin
                                PauseAnimation { duration: 40 + pbtn.index * 35 }
                                ParallelAnimation {
                                    NumberAnimation { target: pbtn; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: ptr; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                                }
                            }

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 18
                                text: modelData.icon
                                font.pixelSize: 30
                                color: pm.containsMouse || pbtn.armed ? pbtn.tint : Qt.lighter(pbtn.tint, 1.0)
                                opacity: pm.containsMouse || pbtn.armed ? 1 : 0.8
                                scale: pm.pressed ? 0.9 : (pm.containsMouse ? 1.08 : 1)
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 60
                                text: modelData.text
                                font.pixelSize: 12
                                color: pm.containsMouse || pbtn.armed ? root.cText : root.cSub
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 78
                                text: modelData.key
                                font.pixelSize: 9
                                color: Qt.rgba(1, 1, 1, 0.28)
                            }
                            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.power(modelData) }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════ КАЛЕНДАР ════════════════════
    SystemClock { id: clk; precision: SystemClock.Seconds }
    Component {
        id: calView
        Column {
            id: cal
            spacing: 12
            property int year: clk.date.getFullYear()
            property int month: clk.date.getMonth()          // 0..11
            property int dir: 0                              // напрям гортання для анімації
            readonly property var monthsUk: ["Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень",
                                             "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень"]
            readonly property var monthsGen: ["січня", "лютого", "березня", "квітня", "травня", "червня",
                                              "липня", "серпня", "вересня", "жовтня", "листопада", "грудня"]
            readonly property var daysUk: ["неділя", "понеділок", "вівторок", "середа", "четвер", "пʼятниця", "субота"]
            function shift(d) {
                dir = d
                let m = month + d, y = year
                if (m < 0) { m = 11; y-- } else if (m > 11) { m = 0; y++ }
                month = m; year = y
                slideIn.restart()
            }
            function goToday() { year = clk.date.getFullYear(); month = clk.date.getMonth(); dir = 0; slideIn.restart() }
            // 42 клітинки (6 тижнів), тиждень з понеділка
            readonly property var cells: {
                const first = new Date(year, month, 1)
                const off = (first.getDay() + 6) % 7
                const out = []
                for (let i = 0; i < 42; i++) {
                    const d = new Date(year, month, 1 - off + i)
                    out.push({ d: d.getDate(), cur: d.getMonth() === month, wk: (i % 7) >= 5,
                               today: d.toDateString() === clk.date.toDateString() })
                }
                return out
            }

            Item {
                width: parent.width; height: 74
                Column {
                    Label { text: Qt.formatTime(clk.date, "HH:mm"); font.pixelSize: 40; font.bold: true }
                    Label {
                        text: cal.daysUk[clk.date.getDay()] + ", " + clk.date.getDate() + " " + cal.monthsGen[clk.date.getMonth()] + " " + clk.date.getFullYear()
                        color: root.cSub; font.pixelSize: 13
                    }
                }
                Label {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 14
                    text: Qt.formatTime(clk.date, ":ss"); color: tc.accent2; font.pixelSize: 20; font.bold: true
                }
            }

            Item {
                width: parent.width; height: 32
                Label { anchors.verticalCenter: parent.verticalCenter; text: cal.monthsUk[cal.month] + " " + cal.year; font.pixelSize: 15; font.bold: true }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Btn { width: 32; icon: "󰅁"; onClicked: cal.shift(-1) }
                    Btn { text: "Сьогодні"; onClicked: cal.goToday() }
                    Btn { width: 32; icon: "󰅂"; onClicked: cal.shift(1) }
                }
            }

            Row {
                Repeater {
                    model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"]
                    Label {
                        required property string modelData
                        required property int index
                        width: cal.width / 7; horizontalAlignment: Text.AlignHCenter
                        text: modelData; font.pixelSize: 11; font.bold: true
                        color: index >= 5 ? tc.accent2 : root.cSub
                    }
                }
            }

            Item {
                width: parent.width; height: grid.height
                clip: true
                Grid {
                    id: grid
                    columns: 7
                    // гортання місяця: нова сітка виїжджає збоку й проявляється (одна анімація, без «застрягань»)
                    ParallelAnimation {
                        id: slideIn
                        NumberAnimation { target: grid; property: "x"; from: cal.dir * 36; to: 0; duration: 240; easing.type: Easing.OutQuint }
                        NumberAnimation { target: grid; property: "opacity"; from: cal.dir === 0 ? 0.4 : 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    }
                    Repeater {
                        model: cal.cells
                        Rectangle {
                            required property var modelData
                            width: cal.width / 7; height: 38; radius: 12
                            color: modelData.today ? root.cAccent : (dm.containsMouse && modelData.cur ? root.cCardHover : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Label {
                                anchors.centerIn: parent
                                text: modelData.d
                                font.bold: modelData.today
                                color: modelData.today ? root.cOnAccent : (!modelData.cur ? Qt.rgba(1, 1, 1, 0.25) : (modelData.wk ? tc.accent2 : root.cText))
                            }
                            MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }
            }
        }
    }
}
