import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// ═══════════════════════════════════════════════════════════════════
//  Буфер обміну (як Klipper у KDE): Win+V або значок у waybar.
//  Відкрити/закрити:  qs -p ~/.config/wallpapers_QS/bg_clipboard/shell.qml ipc call clipboard toggle
//  Історію збирає ~/.config/wallpapers_QS/tools/clipd watch (автозапуск).
//  Клавіші: ↑/↓ — вибір, Enter — скопіювати, Delete — видалити, Ctrl+P — закріпити,
//           Tab — фільтр, Esc — закрити, просто друкуй — пошук.
// ═══════════════════════════════════════════════════════════════════
ShellRoot {
    id: root
    ThemeColors { id: tc }          // кольори поточної теми (Pause — меню тем)

    readonly property string ctl: Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/clipd"
    property bool shown: false
    property var items: []
    property string query: ""
    property int filter: 0            // 0 усе, 1 текст, 2 зображення, 3 закріплені
    property int sel: 0
    property bool confirmClear: false
    property real openedAt: 0
    property string lastJson: ""
    Component.onCompleted: refresh()          // історія готова ще до першого відкриття

    readonly property color cBg: tc.a(tc.bg, 0.90)
    readonly property color cCard: tc.a(tc.border, 0.06)
    readonly property color cCardHover: tc.a(tc.border, 0.12)
    readonly property color cBorder: tc.a(tc.border, 0.16)
    readonly property color cAccent: tc.accent
    readonly property color cPink: tc.accent2
    readonly property color cOnAccent: tc.onAccent
    readonly property color cText: tc.text
    readonly property color cSub: tc.sub
    readonly property color cWarn: tc.warn
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    readonly property var shownItems: {
        const q = root.query.toLowerCase()
        const list = root.items.filter(it => {
            if (root.filter === 1 && it.kind !== "text") return false
            if (root.filter === 2 && it.kind !== "image" && !it.thumb) return false
            if (root.filter === 3 && !it.pinned) return false
            if (q.length && (it.kind !== "text" || it.preview.toLowerCase().indexOf(q) < 0)) return false
            return true
        })
        // закріплені — нагору, решта — від нових до старих (sort у QML не зберігає порядок рівних)
        return list.filter(it => it.pinned).concat(list.filter(it => !it.pinned))
    }
    onShownItemsChanged: if (root.sel >= root.shownItems.length) root.sel = Math.max(0, root.shownItems.length - 1)

    function openNow() {
        root.query = ""; root.filter = 0; root.sel = 0; root.confirmClear = false
        root.openedAt = Date.now()
        root.refresh()
        root.shown = true
    }
    function close() { root.shown = false }
    function refresh() { lister.running = false; lister.running = true }
    function run(args) { runner.command = [root.ctl].concat(args); runner.running = true }
    function pick(it) {
        if (!it) return
        Quickshell.execDetached([root.ctl, "copy", it.id])
        root.close()
    }
    function remove(it) { if (it) root.run(["delete", it.id]) }
    function pin(it) { if (it) root.run(["pin", it.id]) }
    function clearAll() {
        if (!root.confirmClear) { root.confirmClear = true; clearReset.restart(); return }
        root.confirmClear = false
        root.run(["clear"])
    }
    function ago(t) {
        const s = Math.max(0, Math.floor(Date.now() / 1000 - t))
        if (s < 60) return "щойно"
        if (s < 3600) return Math.floor(s / 60) + " хв тому"
        if (s < 86400) return Math.floor(s / 3600) + " год тому"
        const d = Math.floor(s / 86400)
        return d === 1 ? "вчора" : d + " дн тому"
    }
    function sizeText(n) { return n > 1048576 ? (n / 1048576).toFixed(1) + " МБ" : Math.max(1, Math.round(n / 1024)) + " КБ" }

    Timer { id: clearReset; interval: 3000; onTriggered: root.confirmClear = false }

    KittyMenu {}            // контекстне меню kitty (правий клік) — KittyMenu.qml

    IpcHandler {
        target: "clipboard"
        function toggle(): void { if (root.shown) root.close(); else root.openNow() }
        function close(): void { root.close() }
    }

    Process {
        id: lister
        command: [root.ctl, "list"]
        stdout: StdioCollector {
            // список перебудовується лише коли історія справді змінилась (інакше всі картинки щоразу
            // перезавантажувались і якийсь час були порожніми)
            onStreamFinished: {
                if (text === root.lastJson) return
                root.lastJson = text
                try { root.items = JSON.parse(text) } catch (e) { root.items = [] }
            }
        }
    }
    Process {
        id: runner
        onExited: root.refresh()
    }

    HyprlandFocusGrab {
        windows: [win]
        active: root.shown && grabDelay.ready
        onCleared: root.close()
    }
    Timer { id: grabDelay; property bool ready: false; interval: 150; running: root.shown; onTriggered: ready = true }
    Connections { target: root; function onShownChanged() { if (!root.shown) grabDelay.ready = false } }

    component Icon: Text {
        font.family: root.iconFont
        font.pixelSize: 16
        color: root.cText
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
    component Label: Text {
        color: root.cText
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
    }
    component IconBtn: Rectangle {
        id: ib
        property string icon: ""
        property color tint: root.cSub
        property bool on: false
        signal clicked()
        width: 28; height: 28; radius: 9
        color: ma.containsMouse ? root.cCardHover : (on ? tc.a(tc.accent, 0.16) : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        Icon { anchors.centerIn: parent; text: ib.icon; font.pixelSize: 14; color: ma.containsMouse ? root.cText : ib.tint }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    }

    PanelWindow {
        id: win
        visible: root.shown || card.opacity > 0.01
        color: "transparent"
        anchors { top: true; right: true }         // праворуч, під значком буфера в waybar
        margins { top: 46; right: 14 }
        implicitWidth: 480
        implicitHeight: 620
        mask: Region { item: card }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clipboard"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: card
            width: parent.width
            height: parent.height
            radius: 24
            color: root.cBg
            border.width: 1
            border.color: root.cBorder

            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.96
            x: root.shown ? 0 : 18
            transformOrigin: Item.TopRight
            Behavior on opacity { NumberAnimation { duration: 170 } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            layer.enabled: true
            layer.smooth: true

            Rectangle {   // ледь рожевий низ
                anchors.fill: parent; radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.65; color: "transparent" }
                    GradientStop { position: 1.0; color: tc.a(tc.accent2, 0.10) }
                }
            }
            Rectangle {   // блиск зверху
                anchors.top: parent.top; anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 40; height: 1
                color: Qt.rgba(1, 1, 1, 0.22)
            }

            Column {
                id: body
                x: 16; y: 16
                width: parent.width - 32
                spacing: 12

                // ── заголовок ──
                Item {
                    width: parent.width; height: 30
                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 30; height: 30; radius: 10
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.cAccent }
                                GradientStop { position: 1.0; color: tc.accent2Soft }
                            }
                            Icon { anchors.centerIn: parent; text: "󰅌"; color: root.cOnAccent; font.pixelSize: 16 }
                        }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: "Буфер обміну"; font.pixelSize: 16; font.bold: true }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: root.items.length ? root.items.length + "" : ""; color: root.cSub; font.pixelSize: 12 }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        height: 28; radius: 9
                        width: clr.implicitWidth + 22
                        visible: root.items.length > 0
                        color: cma.containsMouse || root.confirmClear ? Qt.rgba(1, 0.62, 0.69, 0.16) : root.cCard
                        border.width: 1; border.color: root.confirmClear ? root.cWarn : root.cBorder
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Label {
                            id: clr; anchors.centerIn: parent
                            text: root.confirmClear ? "󰆴  Точно очистити?" : "󰆴  Очистити"
                            font.family: root.iconFont; font.pixelSize: 12
                            color: root.confirmClear || cma.containsMouse ? root.cWarn : root.cSub
                        }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearAll() }
                    }
                }

                // ── пошук ──
                Rectangle {
                    width: parent.width; height: 40; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: search.activeFocus ? 2 : 1
                    border.color: search.activeFocus ? root.cAccent : root.cBorder
                    Icon { x: 13; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; color: root.cSub; font.pixelSize: 15 }
                    TextInput {
                        id: search
                        anchors.fill: parent; anchors.leftMargin: 38; anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.cText; font.pixelSize: 14
                        selectionColor: root.cAccent; selectedTextColor: root.cOnAccent
                        clip: true
                        text: root.query
                        onTextChanged: { root.query = text; root.sel = 0 }
                        Connections {
                            target: root
                            function onShownChanged() { if (root.shown) { search.text = ""; search.forceActiveFocus() } }
                        }
                        Keys.onPressed: (e) => {
                            const n = root.shownItems.length
                            if (e.key === Qt.Key_Escape) { root.close(); e.accepted = true }
                            else if (e.key === Qt.Key_Down) { root.sel = Math.min(n - 1, root.sel + 1); e.accepted = true }
                            else if (e.key === Qt.Key_Up) { root.sel = Math.max(0, root.sel - 1); e.accepted = true }
                            else if (e.key === Qt.Key_PageDown) { root.sel = Math.min(n - 1, root.sel + 5); e.accepted = true }
                            else if (e.key === Qt.Key_PageUp) { root.sel = Math.max(0, root.sel - 5); e.accepted = true }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.pick(root.shownItems[root.sel]); e.accepted = true }
                            else if (e.key === Qt.Key_Delete && (!search.text.length || search.cursorPosition === search.text.length)) {
                                root.remove(root.shownItems[root.sel]); e.accepted = true
                            }
                            else if (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier)) { root.pin(root.shownItems[root.sel]); e.accepted = true }
                            else if (e.key === Qt.Key_Tab) { root.filter = (root.filter + 1) % 4; root.sel = 0; e.accepted = true }
                            else if (e.key === Qt.Key_Backtab) { root.filter = (root.filter + 3) % 4; root.sel = 0; e.accepted = true }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text.length
                            text: "Шукати в історії…"
                            color: tc.a(tc.sub, 0.75); font.pixelSize: 14
                        }
                    }
                }

                // ── фільтри ──
                Row {
                    spacing: 6
                    Repeater {
                        model: [
                            { name: "Усе", icon: "󰒺" },
                            { name: "Текст", icon: "󰦨" },
                            { name: "Зображення", icon: "󰋩" },
                            { name: "Закріплені", icon: "󰐃" }
                        ]
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool on: root.filter === index
                            height: 28; radius: 14
                            width: chip.implicitWidth + 24
                            color: on ? root.cAccent : (fma.containsMouse ? root.cCardHover : root.cCard)
                            border.width: on ? 0 : 1; border.color: root.cBorder
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Label {
                                id: chip; anchors.centerIn: parent
                                text: modelData.icon + "  " + modelData.name
                                font.family: root.iconFont; font.pixelSize: 12
                                color: parent.on ? root.cOnAccent : root.cText
                            }
                            MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.filter = index; root.sel = 0 } }
                        }
                    }
                }

                // ── список ──
                ListView {
                    id: list
                    width: parent.width
                    height: card.height - y - 16 - 26
                    clip: true
                    spacing: 6
                    model: root.shownItems
                    currentIndex: root.sel
                    highlightFollowsCurrentItem: false
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 160 } }
                    displaced: Transition { NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic } }

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isSel: index === root.sel
                        readonly property bool isImg: modelData.kind === "image" || !!modelData.thumb
                        width: ListView.view.width
                        height: isImg ? 112 : Math.min(84, txt.implicitHeight + 38)
                        radius: 14
                        color: isSel ? tc.a(tc.accent, 0.14) : (rma.containsMouse ? root.cCardHover : root.cCard)
                        border.width: 1
                        border.color: isSel ? tc.a(tc.accent, 0.55) : (modelData.pinned ? tc.a(tc.accent2, 0.45) : "transparent")
                        Behavior on color { ColorAnimation { duration: 110 } }

                        MouseArea {
                            id: rma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onEntered: root.sel = row.index
                            onClicked: (m) => { if (m.button === Qt.MiddleButton) root.remove(row.modelData); else root.pick(row.modelData) }
                        }

                        // вміст
                        Text {
                            id: txt
                            visible: !row.isImg
                            x: 14; y: 10
                            width: parent.width - 28 - (rma.containsMouse || row.isSel ? 66 : 0)
                            text: row.isImg ? "" : row.modelData.preview.replace(/\t/g, "    ").replace(/\n{3,}/g, "\n\n")
                            color: root.cText; font.pixelSize: 13
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Rectangle {
                            visible: row.isImg
                            x: 10; y: 10
                            width: Math.min(parent.width * 0.55, Math.max(60, pic.implicitWidth > 0 ? 70 * pic.implicitWidth / pic.implicitHeight : 120))
                            height: 70; radius: 10
                            color: Qt.rgba(0, 0, 0, 0.25)
                            clip: true
                            Image {
                                id: pic
                                anchors.fill: parent
                                source: row.isImg ? "file://" + (row.modelData.thumb || row.modelData.path) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true               // ім'я файлу = хеш вмісту, тож кеш безпечний
                                sourceSize.height: 140
                            }
                        }
                        // підпис унизу
                        Label {
                            x: 14
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                            font.pixelSize: 11; color: root.cSub
                            font.family: root.iconFont
                            text: (row.modelData.pinned ? "󰐃 " : "") + root.ago(row.modelData.time) + " · " +
                                  (row.modelData.thumb ? "файл · " + row.modelData.thumb.split("/").pop()
                                   : row.isImg ? "зображення · " + root.sizeText(row.modelData.size)
                                             : row.modelData.chars + " симв." + (row.modelData.lines > 1 ? " · " + row.modelData.lines + " рядк." : ""))
                        }
                        // кнопки (видно при наведенні / виборі)
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.top: parent.top; anchors.topMargin: 8
                            spacing: 4
                            opacity: rma.containsMouse || row.isSel ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            IconBtn { icon: "󰐃"; on: !!row.modelData.pinned; tint: row.modelData.pinned ? root.cPink : root.cSub; onClicked: root.pin(row.modelData) }
                            IconBtn { icon: "󰆴"; tint: root.cWarn; onClicked: root.remove(row.modelData) }
                        }
                    }

                    // порожньо
                    Column {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        spacing: 8
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; text: root.query.length ? "󰍉" : "󰅌"; font.pixelSize: 42; color: Qt.rgba(0.6, 0.64, 0.71, 0.5) }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.query.length ? "Нічого не знайдено" : (root.filter === 3 ? "Немає закріплених записів" : "Історія порожня — скопіюй щось")
                            color: root.cSub
                        }
                    }
                }
            }

            // підказка
            Label {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Enter — вставити в буфер · Del — видалити · Ctrl+P — закріпити · Tab — фільтр"
                color: tc.a(tc.sub, 0.75); font.pixelSize: 11
            }
        }
    }
}
