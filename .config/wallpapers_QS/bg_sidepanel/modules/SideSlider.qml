import QtQuick

// Повзунок-пілюля з іконкою зліва та відсотками справа (гучність / мікрофон / яскравість / custom).
Item {
    id: s

    required property var theme
    property string icon: ""
    property real value: 0          // поточне значення, minValue..maxValue
    property real minValue: 0
    property real maxValue: 1.0
    property bool percentOfRange: false   // true = відсоток від діапазону (для custom), false = value × 100 (150% гучності)
    property bool dragging: false
    property real dragValue: 0
    readonly property real range: Math.max(1e-9, maxValue - minValue)
    readonly property real shown: dragging ? dragValue : value
    readonly property real frac: Math.max(0, Math.min(1, (shown - minValue) / range))

    signal moved(real v)            // користувач змінив значення

    height: 38

    function clampV(v) { return Math.max(minValue, Math.min(maxValue, v)) }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: s.theme.track
    }

    Rectangle {
        id: fill
        height: parent.height
        radius: height / 2
        width: Math.max(height, parent.width * s.frac)
        // перелив: блакитний → ніжно-рожевий
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: s.theme.accent }
            GradientStop { position: 1.0; color: Qt.tint(s.theme.accent, Qt.rgba(s.theme.accent2.r, s.theme.accent2.g, s.theme.accent2.b, 0.55)) }
        }
        Behavior on width { enabled: !s.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    Text {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: s.icon
        font.family: s.theme.iconFont
        font.pixelSize: 15
        color: s.theme.onAccent
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round((s.percentOfRange ? s.frac : s.shown) * 100) + "%"
        font.family: s.theme.textFont
        font.pixelSize: 12
        font.bold: true
        color: fill.width > s.width - 56 ? s.theme.onAccent : s.theme.text
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true           // щоб Flickable панелі не «вкрав» перетягування

        property real wheelAcc: 0

        function setFrom(x) {
            s.dragValue = s.minValue + Math.max(0, Math.min(1, x / width)) * s.range
            s.moved(s.dragValue)
        }

        onPressed: (m) => { s.dragging = true; setFrom(m.x) }
        onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
        onReleased: s.dragging = false
        onCanceled: s.dragging = false

        // Раніше: горизонтальний скрол тачпада (y = 0) ЗМЕНШУВАВ значення, а кожна дрібна подія
        // тачпада міняла його на цілі 5%. Тепер дельти накопичуються: 1 клацання коліщатка = 5%.
        onWheel: (w) => {
            const d = w.angleDelta.y
            if (d === 0) return
            wheelAcc += d
            const steps = wheelAcc > 0 ? Math.floor(wheelAcc / 120) : Math.ceil(wheelAcc / 120)
            if (steps === 0) return
            wheelAcc -= steps * 120
            s.moved(s.clampV(s.value + steps * 0.05 * s.range))
        }
    }
}
