import Quickshell
import Quickshell.Io
import QtQuick

// Плитка швидких налаштувань (sidepanel.json -> presets + секція tiles):
//   title, icon, sub,
//   align ("left" | "center") або center (true/false),
//   check / stateCmd, run / toggleCmd / cmd, rightRun / rightCmd,
//   showState, wide, requires, closeOnClick, alwaysActive (завжди підсвічена),
//   команда: рядок, масив [програма, арг...] або { "sh": ["рядок 1", "рядок 2"] },
//   кольори (опційно — якщо не задано, береться загальна тема):
//     color, hoverColor, activeColor, borderColor,
//     textColor, iconColor, subColor, onActiveColor
Item {
    id: tile

    required property var spec
    required property var theme

    signal closeRequested()

    property bool active: false                                  // стан з stateCmd
    // "alwaysActive": true — плитка завжди підсвічена, незалежно від стану
    readonly property bool alwaysActive: spec.alwaysActive === true
    readonly property bool lit: alwaysActive || active           // що реально показуємо
    property string sub: spec.sub !== undefined ? String(spec.sub) : ""
    property bool available: spec.requires === undefined

    readonly property bool centered: {
        if (spec.center !== undefined) return Boolean(spec.center)
        if (typeof spec.align === "string") return spec.align.trim().toLowerCase() === "center"
        return false
    }

    readonly property var checkSpec: spec.check !== undefined ? spec.check : spec.stateCmd
    readonly property var runSpec: spec.run !== undefined
        ? spec.run
        : (spec.toggleCmd !== undefined ? spec.toggleCmd : spec.cmd)
    readonly property var rightRunSpec: spec.rightRun !== undefined ? spec.rightRun : spec.rightCmd
    readonly property bool allowAutoState: spec.showState !== undefined
        ? Boolean(spec.showState)
        : (toCommand(checkSpec) !== null)

    // ---------- індивідуальні кольори плитки з fallback на тему ----------
    function liftColor(c) {
        const q = Qt.color(c)
        return Qt.rgba(
            Math.min(1, q.r + 0.08),
            Math.min(1, q.g + 0.08),
            Math.min(1, q.b + 0.08),
            Math.min(1, q.a + 0.06)
        )
    }

    readonly property color baseBg: spec.color ? Qt.color(spec.color) : tile.theme.tile
    readonly property color hoverBg: spec.hoverColor
        ? Qt.color(spec.hoverColor)
        : (spec.color ? liftColor(spec.color) : tile.theme.tileHover)
    readonly property color activeBg: spec.activeColor ? Qt.color(spec.activeColor) : tile.theme.accent
    readonly property color borderCol: spec.borderColor ? Qt.color(spec.borderColor) : tile.theme.border

    readonly property color activeFg: spec.onActiveColor ? Qt.color(spec.onActiveColor) : tile.theme.onAccent
    readonly property color titleFg: spec.textColor ? Qt.color(spec.textColor) : tile.theme.text
    readonly property color iconFg: spec.iconColor ? Qt.color(spec.iconColor) : titleFg
    readonly property color subFg: spec.subColor ? Qt.color(spec.subColor) : tile.theme.subtext

    visible: available
    height: 72

    function cap(s) { return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s }

    // Увага: spec приходить через модель Repeater-а, і JSON-масиви там стають Qt-списками,
    // для яких Array.isArray() == false. Тому перевіряємо «схожість на масив», а не isArray.
    function isList(v) { return v !== null && typeof v === "object" && typeof v.length === "number" }
    function toList(v) { return Array.prototype.slice.call(v) }

    function toCommand(cmdVal) {
        if (cmdVal === undefined || cmdVal === null) return null
        if (isList(cmdVal)) return cmdVal.length ? toList(cmdVal).map(String) : null
        if (typeof cmdVal === "object" && isList(cmdVal.sh)) cmdVal = toList(cmdVal.sh).join("\n")
        else if (typeof cmdVal === "object") return null
        const s = String(cmdVal).trim()
        if (!s.length) return null
        return ["sh", "-c", s]
    }

    function refresh() {
        const cmd = toCommand(checkSpec)
        if (!available || !cmd || stateProc.running) return
        stateProc.command = cmd
        stateProc.running = true
    }

    // чи є потрібна програма в системі
    Process {
        id: reqProc
        // назва програми передається аргументом, а не вклеюється в скрипт
        command: ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1", "sh", String(tile.spec.requires)]
        running: tile.spec.requires !== undefined
        onExited: (exitCode, exitStatus) => {
            tile.available = (exitCode === 0)
            if (tile.available) tile.refresh()      // одразу показати стан, коли з'ясувалось, що програма є
        }
    }

    Component.onCompleted: refresh()                // стан плитки одразу після створення, а не через 2.5 с

    Process {
        id: stateProc
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.replace(/\r/g, "")
                const lines = raw.split("\n")
                const firstLine = (lines[0] || "").trim()

                let stateToken = firstLine
                let explicitSub = (lines[1] || "").trim()
                let fromToken = false     // підпис з першого рядка (стан на кшталт balanced -> Balanced)
                if (!explicitSub.length && firstLine.indexOf(",") >= 0) {
                    const commaIdx = firstLine.indexOf(",")
                    stateToken = firstLine.slice(0, commaIdx).trim()
                    explicitSub = firstLine.slice(commaIdx + 1).trim()
                    fromToken = true
                }

                const norm = stateToken.toLowerCase()
                if (norm === "on" || norm === "1" || norm === "true" || norm === "active" || norm === "yes") {
                    tile.active = true
                } else if (norm === "off" || norm === "0" || norm === "false" || norm === "inactive" || norm === "no") {
                    tile.active = false
                } else {
                    tile.active = norm.length > 0 && norm !== "balanced" && norm !== "off"
                    if (!explicitSub.length && stateToken.length > 0) {
                        explicitSub = stateToken
                        fromToken = true
                    }
                }

                if (explicitSub.length > 0) {
                    // назву Wi-Fi чи пристрою лишаємо як є (раніше «myWifi» ставало «MyWifi»)
                    tile.sub = fromToken ? tile.cap(explicitSub) : explicitSub
                } else if (tile.spec.sub !== undefined) {
                    tile.sub = String(tile.spec.sub)
                } else if (tile.allowAutoState) {
                    tile.sub = tile.active ? "On" : "Off"
                } else {
                    tile.sub = ""
                }
            }
        }
    }

    Timer {
        id: after
        interval: 600
        onTriggered: tile.refresh()
    }

    function runCmd(cmdVal) {
        const cmd = toCommand(cmdVal)
        if (!cmd) return
        Quickshell.execDetached(cmd)
    }

    scale: ma.pressed ? 0.965 : 1.0
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: tile.lit ? tile.activeBg : (ma.containsMouse ? tile.hoverBg : tile.baseBg)
        border.width: (tile.lit && !tile.spec.activeColor) ? 0 : 1
        border.color: tile.borderCol
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    Rectangle {          // ледь рожевий відблиск на увімкнених плитках
        anchors.fill: parent
        radius: 22
        opacity: tile.lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(tile.theme.accent2.r, tile.theme.accent2.g, tile.theme.accent2.b, 0.45) }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: tile.centered ? 10 : 15
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            horizontalAlignment: tile.centered ? Text.AlignHCenter : Text.AlignLeft
            text: tile.spec.icon || ""
            font.family: tile.theme.iconFont
            font.pixelSize: 17
            color: tile.lit ? tile.activeFg : tile.iconFg
        }
        Text {
            width: parent.width
            horizontalAlignment: tile.centered ? Text.AlignHCenter : Text.AlignLeft
            text: tile.spec.title || ""
            elide: Text.ElideRight
            font.family: tile.theme.textFont
            font.pixelSize: 13
            font.bold: true
            color: tile.lit ? tile.activeFg : tile.titleFg
        }
        Text {
            width: parent.width
            visible: text.length > 0
            horizontalAlignment: tile.centered ? Text.AlignHCenter : Text.AlignLeft
            text: tile.sub
            elide: Text.ElideRight
            font.family: tile.theme.textFont
            font.pixelSize: 11
            color: tile.lit ? tile.activeFg : tile.subFg
            opacity: tile.lit ? 0.75 : 1.0
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
            if (m.button === Qt.RightButton) {
                if (tile.rightRunSpec) {
                    tile.runCmd(tile.rightRunSpec)
                    if (tile.spec.closeOnClick !== false) tile.closeRequested()
                }
                return
            }
            if (!tile.runSpec) return
            tile.runCmd(tile.runSpec)
            if (tile.spec.closeOnClick === true) tile.closeRequested()
            else after.restart()
        }
    }
}