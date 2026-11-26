import Quickshell
import QtQuick

Rectangle {
    id: menu

    property var items: []
    property var theme: ({})

    readonly property var colors: ({
        bg:     (theme && theme.bg)     || "#1a1b26",
        border: (theme && theme.border) || "#7aa2f7",
        text:   (theme && theme.text)   || "#c0caf5",
        hover:  (theme && theme.hover)  || "#333856"
    })

    signal actionRequested(string act)

    // команда: рядок або { "sh": ["рядок 1", "рядок 2"] }
    // (пункти приходять через модель Repeater-а, де масиви — Qt-списки, тож без Array.isArray)
    function scriptOf(v) {
        if (v === undefined || v === null) return ""
        if (typeof v === "string") return v
        if (typeof v === "object" && v.sh && typeof v.sh.length === "number")
            return Array.prototype.slice.call(v.sh).join("\n")
        return ""
    }

    width: 190
    height: menuCol.implicitHeight + 16
    radius: 14
    color: menu.colors.bg
    border.width: 1
    border.color: menu.colors.border
    visible: false
    transformOrigin: Item.TopLeft

    onVisibleChanged: if (visible) openAnim.restart()

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: menu; property: "scale"; from: 0.86; to: 1.0; duration: 140; easing.type: Easing.OutBack }
        NumberAnimation { target: menu; property: "opacity"; from: 0.0; to: 1.0; duration: 110 }
    }

    Column {
        id: menuCol
        x: 8; y: 8
        width: parent.width - 16
        spacing: 4

        Repeater {
            model: menu.items

            Rectangle {
                id: row
                required property var modelData
                width: parent.width
                height: 32
                radius: 8
                color: mArea.containsMouse ? menu.colors.hover : "transparent"

                Behavior on color { ColorAnimation { duration: 90 } }

                Text {
                    anchors.centerIn: parent
                    text: row.modelData.label || ""
                    color: menu.colors.text
                    font.family: menu.theme && menu.theme.font ? menu.theme.font : Qt.application.font.family
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    id: mArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menu.visible = false
                        const cmd = menu.scriptOf(row.modelData.cmd)
                        if (cmd.length) {
                            Quickshell.execDetached(["sh", "-c", cmd])
                        } else if (row.modelData.action) {
                            menu.actionRequested(row.modelData.action)
                        }
                    }
                }
            }
        }
    }
}
