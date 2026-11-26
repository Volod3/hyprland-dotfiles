import QtQuick

// Кругла кнопка-глиф у скляному стилі.
Rectangle {
    id: btn

    property string glyph: ""
    property string tip: ""
    property bool active: false
    property bool danger: false
    property int size: 30
    signal clicked

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    radius: size / 2.4

    color: active ? (danger ? "#2eff7096" : "#267fdcff")
                  : (ma.containsMouse ? "#16ffffff" : "#0dffffff")
    border.width: 1
    border.color: active ? (danger ? "#88ff7096" : "#777fdcff")
                         : (ma.containsMouse ? "#28ffffff" : "#14ffffff")

    Behavior on color { ColorAnimation { duration: 130 } }
    Behavior on border.color { ColorAnimation { duration: 130 } }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.active ? (btn.danger ? "#ffb3c9" : "#a9ecff") : "#b9d6ef"
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: Math.round(btn.size * 0.56)
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
