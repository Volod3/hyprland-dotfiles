import QtQuick

// Кругла кнопка з іконкою (Nerd Font). filled = акцентна "пілюля" (як Play).
Item {
    id: b

    required property var theme
    property string icon: ""
    property int size: 36
    property int iconSize: 16
    property bool filled: false     // акцентний фон
    property bool on: false         // іконка акцентним кольором (напр. shuffle увімкнено)
    property bool dim: false        // неактивна (напівпрозора)

    signal clicked()

    width: filled ? Math.round(size * 1.5) : size
    height: size
    opacity: dim ? 0.35 : 1.0
    scale: ma.pressed ? 0.9 : 1.0
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: b.filled ? b.theme.accent : (ma.containsMouse ? b.theme.tileHover : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
        anchors.centerIn: parent
        text: b.icon
        font.family: b.theme.iconFont
        font.pixelSize: b.iconSize
        color: b.filled ? b.theme.onAccent : (b.on ? b.theme.accent : b.theme.text)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
