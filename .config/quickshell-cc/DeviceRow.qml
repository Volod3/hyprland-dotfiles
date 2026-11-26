import QtQuick

// Рядок вибору пристрою (sink/source) — радіо-стиль.
Rectangle {
    id: row

    property string title: ""
    property bool active: false
    signal clicked

    implicitHeight: 26
    radius: 9
    color: active ? "#167fdcff" : (ma.containsMouse ? "#10ffffff" : "#00000000")
    border.width: 1
    border.color: active ? "#4d7fdcff" : "#00000000"

    Behavior on color { ColorAnimation { duration: 130 } }

    Rectangle {
        id: dot
        width: 8; height: 8; radius: 4
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: row.active ? "#7fdcff" : "transparent"
        border.width: 1
        border.color: row.active ? "#7fdcff" : "#3d5478"
    }

    Text {
        anchors.left: dot.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.title
        color: row.active ? "#d9f3ff" : "#9db6d2"
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: 10
        elide: Text.ElideRight
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
