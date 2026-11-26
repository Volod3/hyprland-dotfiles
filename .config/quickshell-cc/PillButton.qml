import QtQuick

// Маленька скляна "пігулка"-кнопка для другорядних дій.
Rectangle {
    id: pill

    property string text: ""
    property bool accent: false
    property bool active: false
    signal clicked

    implicitHeight: 24
    implicitWidth: lbl.implicitWidth + 20
    radius: 8
    color: active ? "#227fdcff" : (ma.containsMouse ? "#16ffffff" : "#0bffffff")
    border.width: 1
    border.color: active ? "#5a7fdcff" : (ma.containsMouse ? "#2affffff" : "#12ffffff")

    Behavior on color { ColorAnimation { duration: 130 } }
    Behavior on border.color { ColorAnimation { duration: 130 } }

    Text {
        id: lbl
        anchors.centerIn: parent
        text: pill.text
        color: pill.accent || pill.active ? "#a9ecff" : "#9db6d2"
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: 10
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
