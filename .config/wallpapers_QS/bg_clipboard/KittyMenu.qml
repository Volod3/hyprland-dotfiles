import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// ═══════════════════════════════════════════════════════════════════
//  Контекстне меню kitty (правий клік) — рідне вікно Quickshell замість старого Qt-меню через Xwayland
//  (те то зникало, то не відкривалось, а кнопки не діяли, бо не знали сокета kitty).
//  Відкриває kitty.conf:  mouse_map right press ungrabbed launch --type=background sh -c '... ipc call kittymenu open SOCK WID SEL'
//  Дії — через kitty remote control:  kitten @ --to SOCK action --match id:WID ...
// ═══════════════════════════════════════════════════════════════════
Scope {
    id: km
    ThemeColors { id: tc }          // кольори поточної теми (Pause — меню тем)

    property bool shown: false
    property string sock: ""
    property string wid: ""
    property bool hasSel: false
    property real px: 0
    property real py: 0
    property int sel: -1

    readonly property color cBg: tc.a(tc.bg, 0.98)
    readonly property color cHover: tc.a(tc.accent, 0.16)
    readonly property color cBorder: tc.a(tc.border, 0.16)
    readonly property color cAccent: tc.accent
    readonly property color cText: tc.text
    readonly property color cSub: tc.a(tc.sub, 0.85)
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    readonly property var items: [
        { id: "copy", icon: "󰆏", text: "Копіювати", key: "Ctrl+C", needSel: true },
        { id: "paste", icon: "󰆒", text: "Вставити", key: "Ctrl+V" },
        { id: "sep" },
        { id: "selectall", icon: "󰒆", text: "Виділити все на екрані", key: "" },
        { id: "clear", icon: "󰃢", text: "Очистити термінал", key: "Ctrl+L" },
        { id: "sep" },
        { id: "font", icon: "󰛖", text: "Скинути розмір шрифту", key: "Ctrl+Shift+⌫" },
        { id: "reload", icon: "󰑓", text: "Перечитати конфіг", key: "Ctrl+Shift+F5" }
    ]

    function enabled(it) { return it.id !== "sep" && !(it.needSel && !km.hasSel) }

    function open(sock, wid, selection) {
        km.sock = sock; km.wid = wid; km.hasSel = selection.length > 0 && selection !== "@selection"   // у фоновому запуску kitty не підставляє виділення
        km.sel = -1
        posP.running = false; posP.running = true          // позиція курсора від Hyprland → тоді показати
    }
    function close() { km.shown = false }

    function kitty(args) {
        Quickshell.execDetached(["kitten", "@", "--to", km.sock, "action", "--match", "id:" + km.wid].concat(args))
    }
    function run(it) {
        if (!it || !km.enabled(it)) return
        km.close()
        if (it.id === "copy") km.kitty(["copy_to_clipboard"])
        else if (it.id === "paste") km.kitty(["kitten", "smartpaste.py"])
        else if (it.id === "selectall") km.kitty(["select_all"])
        else if (it.id === "clear") {
            // шрифт назад → Ctrl+L у fish (лишається запрошення) → чистимо історію
            Quickshell.execDetached(["sh", "-c",
                "K='kitten @ --to " + km.sock + " action --match id:" + km.wid + "'; $K send_text all '\\x0c'; sleep 0.2; $K clear_terminal scrollback active"])
        }
        else if (it.id === "font") km.kitty(["change_font_size", "current", "0"])
        else if (it.id === "reload") km.kitty(["load_config_file"])
    }

    Process {
        id: posP
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",")
                km.px = Number(p[0]) || 0
                km.py = Number(p[1]) || 0
                km.shown = true
            }
        }
    }

    IpcHandler {
        target: "kittymenu"
        function open(sock: string, wid: string, selection: string): void { km.open(sock, wid, selection) }
        function close(): void { km.close() }
    }

    HyprlandFocusGrab {
        windows: [mwin]
        active: km.shown && grabT.ready
        onCleared: km.close()
    }
    Timer { id: grabT; property bool ready: false; interval: 120; running: km.shown; onTriggered: ready = true }
    Connections { target: km; function onShownChanged() { if (!km.shown) grabT.ready = false } }

    PanelWindow {
        id: mwin
        visible: km.shown || card.opacity > 0.01
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: card }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kittymenu"
        WlrLayershell.keyboardFocus: km.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: card
            width: 320
            height: col.implicitHeight + 12
            // біля курсора, але не за краєм екрана
            x: Math.min(km.px + 2, mwin.width - width - 8)
            y: km.py + 2 + height > mwin.height - 8 ? Math.max(8, km.py - height - 2) : km.py + 2
            radius: 14
            color: km.cBg
            border.width: 1
            border.color: km.cBorder
            focus: km.shown

            opacity: km.shown ? 1 : 0
            scale: km.shown ? 1 : 0.94
            transformOrigin: Item.TopLeft
            Behavior on opacity { NumberAnimation { duration: km.shown ? 120 : 90 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Keys.onEscapePressed: km.close()
            Keys.onUpPressed: { let i = km.sel; do { i = (i - 1 + km.items.length) % km.items.length } while (!km.enabled(km.items[i])); km.sel = i }
            Keys.onDownPressed: { let i = km.sel; do { i = (i + 1) % km.items.length } while (!km.enabled(km.items[i])); km.sel = i }
            Keys.onReturnPressed: km.run(km.items[km.sel])

            Rectangle {   // блиск зверху
                anchors.top: parent.top; anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 30; height: 1
                color: Qt.rgba(1, 1, 1, 0.16)
            }

            Column {
                id: col
                x: 6; y: 6
                width: parent.width - 12
                Repeater {
                    model: km.items
                    Item {
                        required property var modelData
                        required property int index
                        readonly property bool isSep: modelData.id === "sep"
                        readonly property bool ok: km.enabled(modelData)
                        width: col.width
                        height: isSep ? 9 : 34
                        Rectangle {
                            visible: parent.isSep
                            anchors.centerIn: parent
                            width: parent.width - 16; height: 1
                            color: km.cBorder
                        }
                        Rectangle {
                            visible: !parent.isSep
                            anchors.fill: parent
                            radius: 9
                            color: (km.sel === index || ma.containsMouse) && parent.ok ? km.cHover : "transparent"
                            Behavior on color { ColorAnimation { duration: 90 } }
                            Text {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon || ""
                                font.family: km.iconFont; font.pixelSize: 15
                                color: parent.parent.ok ? km.cAccent : km.cSub
                            }
                            Text {
                                x: 36; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text || ""
                                font.pixelSize: 13
                                color: parent.parent.ok ? km.cText : km.cSub
                            }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.key || ""
                                font.pixelSize: 11
                                color: km.cSub
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: parent.parent.ok
                                cursorShape: Qt.PointingHandCursor
                                onEntered: km.sel = index
                                onClicked: km.run(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
