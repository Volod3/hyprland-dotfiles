import QtQuick

// Тонкий слайдер у стилі "скла": доріжка, градієнтна заливка, кільце на кнопці.
Item {
    id: sl

    property real value: 50
    property real from: 0
    property real to: 150
    property color fillA: "#8ff0ff"
    property color fillB: "#3f86d8"
    property bool boost: false          // value > 100 (тільки для звуку)
    property bool dragging: false
    property bool hovered: false

    signal moved(real v)
    signal finished(real v)

    implicitHeight: 18
    height: implicitHeight

    readonly property real frac: Math.max(0, Math.min(1, (value - from) / Math.max(1, to - from)))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 7
        radius: 3.5
        color: "#12ffffff"
        border.width: 1
        border.color: sl.hovered || sl.dragging ? "#22ffffff" : "#12ffffff"
        Behavior on border.color { ColorAnimation { duration: 140 } }
    }

    Rectangle {
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        height: 7
        radius: 3.5
        width: Math.max(0, track.width * sl.frac)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: sl.boost ? "#7fdcff" : sl.fillB }
            GradientStop { position: 1.0; color: sl.boost ? "#e8fdff" : sl.fillA }
        }
        Behavior on width { NumberAnimation { duration: sl.dragging ? 0 : 180; easing.type: Easing.OutCubic } }
    }

    // мітка 100%
    Rectangle {
        visible: sl.to > 100
        x: Math.round(track.width * (100 - sl.from) / (sl.to - sl.from)) - 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 11
        radius: 1
        color: sl.value > 100 ? "#aa7fdcff" : "#33ffffff"
    }

    Rectangle {
        id: knobGlow
        width: 26
        height: 26
        radius: 13
        color: "transparent"
        border.width: 1
        border.color: sl.boost ? "#88e8fdff" : "#667fdcff"
        opacity: sl.dragging ? 1 : 0
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(-13, Math.min(parent.width - 13, track.width * sl.frac - 13))
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Rectangle {
        id: knob
        width: sl.dragging ? 15 : 12
        height: width
        radius: width / 2
        color: "#eafcff"
        border.width: 2
        border.color: sl.boost ? "#7fdcff" : "#5ea8e8"
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(-width / 2, Math.min(parent.width - width / 2, track.width * sl.frac - width / 2))
        Behavior on width { NumberAnimation { duration: 130 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.topMargin: -9
        anchors.bottomMargin: -9
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onEntered: sl.hovered = true
        onExited: sl.hovered = false
        function valAt(mx) {
            var f = Math.max(0, Math.min(1, mx / track.width));
            return sl.from + f * (sl.to - sl.from);
        }
        onPressed: (m) => { sl.dragging = true; sl.value = valAt(m.x); sl.moved(sl.value); }
        onPositionChanged: (m) => { if (pressed) { sl.value = valAt(m.x); sl.moved(sl.value); } }
        onReleased: (m) => { sl.dragging = false; sl.finished(sl.value); }
        onCanceled: sl.dragging = false
    }
}
