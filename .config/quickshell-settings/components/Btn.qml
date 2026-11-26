import QtQuick

// Кнопка у стилі «Азур»: скло, акцентна рамка, м'яке підсвічування при наведенні.
Item {
    id: btn

    property string text: ""
    property string icon: ""
    property bool accent: false
    property bool danger: false
    property bool enabled: true
    property int padH: 16
    property int minW: 0

    signal clicked()

    implicitHeight: 36
    implicitWidth: Math.max(minW, label.implicitWidth + padH * 2 + (icon !== "" ? 18 : 0))
    opacity: enabled ? 1.0 : 0.45

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 10
        color: btn.accent
            ? (ma.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.80) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65))
            : btn.danger
                ? Qt.rgba(1, 0.439, 0.588, ma.containsMouse ? 0.20 : 0.13)
                : Qt.rgba(0.498, 0.863, 1, ma.containsMouse ? 0.14 : 0.07)
        border.width: 1
        border.color: btn.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.9)
            : btn.danger ? Qt.rgba(1, 0.439, 0.588, 0.55)
            : Qt.rgba(0.498, 0.863, 1, ma.containsMouse ? 0.45 : 0.22)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                visible: btn.icon !== ""
                text: btn.icon
                font.family: Theme.mono
                font.pixelSize: 14
                color: btn.accent ? Theme.bg0 : (btn.danger ? Theme.danger : Theme.accent)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: label
                text: btn.text
                font.family: Theme.mono
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: btn.accent ? Theme.bg0 : (btn.danger ? Theme.danger : Theme.text)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
