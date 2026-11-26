import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// ═══════════════════════════════════════════════════════════════════
//  Меню тем (Pause / Break): картки з мініатюрами шпалер, вибір стрілками / цифрами / мишею.
//  Застосування — коло з новими шпалерами розкривається від картки (зі світним кільцем),
//  під ним tools/theme перемикає шпалери й кольори всього інтерфейсу, тоді меню розчиняється.
//  qs -p ~/.config/wallpapers_QS/bg_themes/shell.qml ipc call themes toggle
// ═══════════════════════════════════════════════════════════════════
ShellRoot {
    id: root
    ThemeColors { id: tc }

    readonly property string ctl: Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/theme"
    property bool shown: false
    property var themes: []
    property int sel: 0
    property real openedAt: 0

    // перехід
    property bool switching: false
    property var target: null
    property real revealR: 0
    property real revealX: 960
    property real revealY: 540
    property real veil: 1               // прозорість усього меню наприкінці переходу

    IpcHandler {
        target: "themes"
        function toggle(): void { if (root.shown) root.close(); else root.open() }
        function open(): void { root.open() }
        function close(): void { root.close() }
        // застосувати тему з анімацією (напр. з «Налаштувань»): меню відкривається й одразу запускає перехід
        function apply(id: string): void {
            if (!root.shown) root.open()
            root.pendingId = id
            pendingT.restart()
        }
    }
    property string pendingId: ""
    Timer {
        id: pendingT; interval: 500
        onTriggered: {
            const i = root.themes.findIndex(t => t.id === root.pendingId)
            if (i >= 0) root.apply(i, cards.itemAt(i))
        }
    }

    function open() {
        if (root.switching) return
        root.veil = 1
        root.revealR = 0
        root.target = null
        lister.running = false; lister.running = true
        root.openedAt = Date.now()
        root.shown = true
    }
    function close() { if (!root.switching) root.shown = false }

    Process {
        id: lister
        command: [root.ctl, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.themes = JSON.parse(text) } catch (e) { root.themes = [] }
                const i = root.themes.findIndex(t => t.current)
                root.sel = i >= 0 ? i : 0
            }
        }
    }
    Process { id: applier; onExited: settleT.start() }

    function apply(i, fromItem) {
        if (root.switching || i < 0 || i >= root.themes.length) return
        const t = root.themes[i]
        if (t.current) { root.close(); return }
        root.sel = i
        root.target = t
        // центр кола — центр картки
        if (fromItem) {
            const p = fromItem.mapToItem(null, fromItem.width / 2, fromItem.height / 2)
            root.revealX = p.x; root.revealY = p.y
        }
        root.switching = true
        revealA.restart()
        applyT.restart()
    }
    // tools/theme — трохи згодом, коли коло вже накрило більшу частину екрана (перезавантаження шпалер не видно)
    Timer { id: applyT; interval: 380; onTriggered: { applier.command = [root.ctl, "set", root.target.id]; applier.running = true } }
    // справжні шпалери вантажаться асинхронно — чекаємо, тоді розчиняємо меню
    Timer { id: settleT; interval: 650; onTriggered: fadeA.restart() }
    NumberAnimation {
        id: revealA; target: root; property: "revealR"
        from: 0; to: Math.hypot(Math.max(root.revealX, 1920 - root.revealX), Math.max(root.revealY, 1080 - root.revealY)) + 60
        duration: 820; easing.type: Easing.InOutCubic
    }
    SequentialAnimation {
        id: fadeA
        NumberAnimation { target: root; property: "veil"; to: 0; duration: 520; easing.type: Easing.OutCubic }
        ScriptAction { script: { root.switching = false; root.shown = false; root.revealR = 0 } }
    }

    PanelWindow {
        id: win
        visible: root.shown || backdrop.opacity > 0.01
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "themes"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: stage
            anchors.fill: parent
            opacity: root.veil
            focus: root.shown

            Keys.onPressed: (e) => {
                if (root.switching) return
                const n = root.themes.length
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Pause) root.close()
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) root.sel = (root.sel + n - 1) % n
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) root.sel = (root.sel + 1) % n
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.apply(root.sel, cards.itemAt(root.sel))
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && e.key - Qt.Key_1 < n) root.apply(e.key - Qt.Key_1, cards.itemAt(e.key - Qt.Key_1))
                e.accepted = true
            }

            // ── затемнення ──
            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)
                opacity: root.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent; onClicked: root.close() }
                // ледь кольорове сяйво теми, що вибрана
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.1; height: width; radius: width / 2
                    color: root.themes.length ? root.themes[root.sel].palette.accent : tc.accent
                    opacity: 0.07
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
            }

            // ── заголовок ──
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.5 - 220 + (root.shown ? 0 : -30)
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                opacity: root.shown && !root.switching ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Теми"
                    color: "#ffffff"; font.pixelSize: 34; font.family: "Comfortaa"; font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "← → вибір   ·   Enter застосувати   ·   1–" + root.themes.length + " одразу   ·   Esc закрити"
                    color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 13
                }
            }

            // ── картки ──
            Row {
                id: row
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.5 - 110
                spacing: 22
                Repeater {
                    id: cards
                    model: root.themes
                    Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property var t: modelData
                        readonly property bool isSel: index === root.sel
                        readonly property bool isTarget: root.switching && root.target && root.target.id === t.id
                        width: 300; height: 236

                        // поява по черзі: знизу вгору
                        property real enter: 0
                        Connections {
                            target: root
                            function onShownChanged() { if (root.shown) { card.enter = 0; enterA.restart() } }
                        }
                        Component.onCompleted: if (root.shown) enterA.restart()     // картки з'являються вже у відкритому меню
                        SequentialAnimation {
                            id: enterA
                            PauseAnimation { duration: 60 + card.index * 55 }
                            NumberAnimation { target: card; property: "enter"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                        }
                        opacity: (root.switching ? (isTarget ? 1 : 0) : 1) * Math.min(1, enter * 1.4)
                        Behavior on opacity { enabled: root.switching; NumberAnimation { duration: 260 } }
                        transform: Translate { y: (1 - card.enter) * 70 + (card.isSel && !root.switching ? -14 : 0)
                                               Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } } }
                        scale: isTarget ? 1.08 : (isSel ? 1.06 : 0.94)
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                        // сяйво вибраної
                        Rectangle {
                            anchors.fill: thumbBox; anchors.margins: -10
                            radius: 26
                            color: "transparent"
                            border.width: 2
                            border.color: card.t.palette.accent
                            opacity: card.isSel ? 0.9 : 0
                            Behavior on opacity { NumberAnimation { duration: 220 } }
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blur: 0.6; blurMax: 24; brightness: 0.2 }
                        }
                        Rectangle {
                            id: thumbBox
                            width: 300; height: 169; radius: 18
                            color: card.t.palette.bg
                            border.width: card.isSel ? 2 : 1
                            border.color: card.isSel ? card.t.palette.accent : Qt.rgba(1, 1, 1, 0.12)
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            Image {
                                id: thumb
                                anchors.fill: parent; anchors.margins: 2
                                source: "file://" + card.t.thumb
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                asynchronous: true
                                sourceSize.width: 600
                            }
                            Rectangle { id: thMask; anchors.fill: thumb; radius: 16; visible: false; layer.enabled: true }
                            MultiEffect {
                                anchors.fill: thumb; source: thumb
                                maskEnabled: true; maskSource: thMask
                                brightness: card.isSel ? 0.0 : -0.18
                                saturation: card.isSel ? 0.1 : -0.25
                                Behavior on brightness { NumberAnimation { duration: 220 } }
                                Behavior on saturation { NumberAnimation { duration: 220 } }
                            }
                            // позначка «зараз»
                            Rectangle {
                                visible: card.t.current
                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10
                                height: 24; radius: 12; width: curT.implicitWidth + 18
                                color: Qt.rgba(0, 0, 0, 0.55)
                                Text { id: curT; anchors.centerIn: parent; text: "зараз"; color: "#ffffff"; font.pixelSize: 11 }
                            }
                            Text {
                                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
                                text: String(card.index + 1)
                                color: "#ffffff"; font.pixelSize: 13; font.bold: true
                                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.5)
                            }
                        }
                        Column {
                            anchors.top: thumbBox.bottom; anchors.topMargin: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 7
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: card.t.icon + "  " + card.t.name
                                color: card.isSel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.7)
                                font.pixelSize: 15; font.bold: card.isSel
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6
                                Repeater {
                                    model: [card.t.palette.accent, card.t.palette.accent2, card.t.palette.bg, card.t.palette.text]
                                    Rectangle {
                                        required property string modelData
                                        width: 14; height: 14; radius: 7
                                        color: modelData
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (!root.switching) root.sel = card.index
                            onClicked: root.apply(card.index, thumbBox)
                        }
                    }
                }
            }

            // ── перехід: коло з новими шпалерами, що розкривається ──
            Item {
                id: reveal
                anchors.fill: parent
                visible: root.switching
                Image {
                    id: newWall
                    anchors.fill: parent
                    source: root.target ? "file://" + root.target.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    sourceSize.width: 1920
                }
                Item {
                    id: circleMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Rectangle {
                        x: root.revealX - root.revealR; y: root.revealY - root.revealR
                        width: root.revealR * 2; height: width; radius: width / 2
                        color: "black"
                    }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: newWall
                    maskEnabled: true
                    maskSource: circleMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 0.25
                }
                // світне кільце по краю кола
                Rectangle {
                    x: root.revealX - root.revealR; y: root.revealY - root.revealR
                    width: root.revealR * 2; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 6
                    border.color: root.target ? root.target.palette.accent : tc.accent
                    opacity: root.revealR > 10 ? Math.max(0, 1 - root.revealR / 2200) : 0
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 0.8; blurMax: 32; brightness: 0.3 }
                }
                Rectangle {
                    x: root.revealX - root.revealR * 0.985; y: root.revealY - root.revealR * 0.985
                    width: root.revealR * 1.97; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: root.target ? root.target.palette.accent2 : tc.accent2
                    opacity: root.revealR > 10 ? Math.max(0, 0.8 - root.revealR / 2400) : 0
                }
                // назва нової теми — коротко по центру
                Text {
                    anchors.centerIn: parent
                    text: root.target ? root.target.icon + "  " + root.target.name : ""
                    color: "#ffffff"
                    font.pixelSize: 40; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                    style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35)
                    opacity: root.revealR > 900 ? Math.min(1, (root.revealR - 900) / 400) : 0
                    scale: 0.9 + 0.1 * opacity
                }
            }
        }
    }
}
