import QtQuick

// Перемикач: доріжка + кулька, акцент коли увімкнено.
Item {
    id: sw

    property bool checked: false
    property bool enabled: true

    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 24

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: sw.checked
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
            : Qt.rgba(0.35, 0.45, 0.65, 0.25)
        border.width: 1
        border.color: sw.checked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.75) : Theme.stroke
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Rectangle {
            id: knob
            width: 18
            height: 18
            radius: 9
            y: 2
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Theme.accent : Theme.textMute
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: width / 2
                color: Theme.accent
                opacity: sw.checked ? 0.18 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: sw.enabled
        onClicked: sw.toggled(!sw.checked)
    }
}
