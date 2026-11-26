import QtQuick

// Плитка швидкого перемикача (Wi-Fi / BT / DND / гра).
Rectangle {
    id: tile

    property string glyph: ""
    property string label: ""
    property string state: ""
    property bool active: false
    property bool unavailable: false
    property color accent: "#7fdcff"
    signal clicked

    implicitHeight: 62
    radius: 15
    color: active ? "#1f7fdcff" : (ma.containsMouse ? "#12ffffff" : "#0bffffff")
    border.width: 1
    border.color: active ? "#6b7fdcff" : (ma.containsMouse ? "#26ffffff" : "#12ffffff")
    opacity: unavailable ? 0.45 : 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    // м'яке світіння для активного стану
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: tile.active ? "#2e7fdcff" : "#00000000" }
            GradientStop { position: 1.0; color: "#00000000" }
        }
        opacity: tile.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 11
        anchors.rightMargin: 11
        spacing: 9

        Item {
            width: 26
            height: parent.height
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tile.glyph
                color: tile.active ? tile.accent : "#8fb4d6"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 20
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        Column {
            width: parent.width - 70
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: tile.label
                color: tile.active ? "#e6f7ff" : "#cbdcf0"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: tile.state
                color: tile.active ? "#8ff0ff" : "#5f7a99"
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 9
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // індикатор
    Rectangle {
        width: 6; height: 6; radius: 3
        anchors.right: parent.right
        anchors.rightMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        color: tile.active ? tile.accent : "#2a3d5c"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
