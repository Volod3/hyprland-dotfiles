import QtQuick

// Заголовок секції: іконка + назва + лінія.
Item {
    property string title: ""
    property string icon: ""
    property string note: ""

    implicitHeight: 28
    width: parent ? parent.width : 0

    Text {
        id: iconText
        visible: icon !== ""
        text: icon
        color: Theme.accent
        font.family: Theme.mono
        font.pixelSize: 13
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        id: titleText
        text: title.toUpperCase()
        color: Theme.textDim
        font.family: Theme.mono
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        anchors.left: iconText.visible ? iconText.right : parent.left
        anchors.leftMargin: iconText.visible ? 8 : 0
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        visible: note !== ""
        text: note
        color: Theme.textMute
        font.family: Theme.mono
        font.pixelSize: 9
        anchors.left: titleText.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        anchors.left: titleText.visible ? titleText.right : parent.left
        anchors.leftMargin: visible ? 10 : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Theme.strokeSoft
        visible: note === ""
    }
}
