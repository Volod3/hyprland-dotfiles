import QtQuick

// «Обране»: сітка програм з favorites.json.
// ЛКМ — запустити, ПКМ — прибрати з обраного. Додати — зірочка ☆ у пошуку програм праворуч від панелі.
Rectangle {
    id: fav

    required property var theme
    property var apps: []                 // [{ id, name, icon, exec, terminal }]
    property int columns: 4
    signal launch(var app)
    signal remove(string id)

    height: head.height + grid.height + 34
    radius: 24
    color: theme.tile
    border.width: 1
    border.color: theme.border

    Item {
        id: head
        x: 16; y: 12
        width: parent.width - 32
        height: 20
        Text {
            text: "Обране"
            font.family: fav.theme.textFont
            font.pixelSize: 13
            font.bold: true
            color: fav.theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: fav.apps.length ? "ПКМ — прибрати" : ""
            font.family: fav.theme.textFont
            font.pixelSize: 11
            color: fav.theme.subtext
        }
    }

    Text {
        visible: fav.apps.length === 0
        x: 16; y: head.y + head.height + 10
        width: parent.width - 32
        wrapMode: Text.Wrap
        text: "Тут поки порожньо. Натисни ☆ біля програми в пошуку праворуч — і вона з'явиться тут."
        font.family: fav.theme.textFont
        font.pixelSize: 12
        color: fav.theme.subtext
    }

    Grid {
        id: grid
        x: 10; y: head.y + head.height + 8
        width: parent.width - 20
        columns: fav.columns
        readonly property real cellW: width / columns
        height: fav.apps.length ? implicitHeight : 34

        Repeater {
            model: fav.apps
            Rectangle {
                required property var modelData
                width: grid.cellW
                height: 78
                radius: 16
                color: ma.containsMouse ? fav.theme.tileHover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Image {
                    id: ico
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10
                    width: 36; height: 36
                    sourceSize: Qt.size(72, 72)
                    source: modelData.icon ? "file://" + modelData.icon : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.08 : 1)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                }
                Text {
                    visible: ico.status !== Image.Ready
                    anchors.centerIn: ico
                    text: modelData.name ? modelData.name.charAt(0) : "?"
                    font.pixelSize: 20; font.bold: true
                    color: fav.theme.accent
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 52
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.name
                    font.family: fav.theme.textFont
                    font.pixelSize: 11
                    color: fav.theme.text
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (m) => m.button === Qt.RightButton ? fav.remove(modelData.id) : fav.launch(modelData)
                }
            }
        }
    }
}
