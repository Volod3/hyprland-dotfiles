import QtQuick

// Повзунок у стилі «Азур»: підпис, значення, градієнтна смуга.
// `value` лишається прив'язкою до моделі (bindings не рвуться),
// під час перетягування показується локальне `shown`, а назовні йде moved().
Item {
    id: root

    property string label: ""
    property string hint: ""
    property real from: 0
    property real to: 10
    property real step: 1
    property real value: 0
    property real shown: 0
    property int decimals: 0
    property string suffix: ""
    property string zeroText: ""          // підпис замість 0 (напр. «ніколи»)
    property bool enabled: true

    signal moved(real v)
    signal released()

    property bool dragging: false

    implicitHeight: hint !== "" ? 62 : 48

    onValueChanged: if (!dragging) shown = value
    Component.onCompleted: shown = value

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

    function quantize(v) {
        var q = Math.round((v - from) / step) * step + from;
        return clamp(Math.round(q * 1000) / 1000, from, to);
    }

    function ratio() {
        return to > from ? (shown - from) / (to - from) : 0;
    }

    Text {
        id: labelText
        text: root.label
        color: root.enabled ? Theme.text : Theme.textMute
        font.family: Theme.mono
        font.pixelSize: 12
        anchors.left: parent.left
        anchors.top: parent.top
    }

    Text {
        visible: root.hint !== ""
        text: root.hint
        color: Theme.textMute
        font.family: Theme.mono
        font.pixelSize: 10
        anchors.left: parent.left
        anchors.top: labelText.bottom
        anchors.topMargin: 2
    }

    Rectangle {
        id: chip
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -3
        width: Math.max(46, valueText.implicitWidth + 16)
        height: 22
        radius: 7
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)

        Text {
            id: valueText
            anchors.centerIn: parent
            text: (root.zeroText.length && Math.abs(root.shown) < 1e-9) ? root.zeroText : root.shown.toFixed(root.decimals) + root.suffix
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    Item {
        id: trackArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        height: 18
        opacity: root.enabled ? 1 : 0.4

        Rectangle {
            id: groove
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(0.35, 0.45, 0.65, 0.25)
        }

        Rectangle {
            id: fill
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(2, trackArea.width * Math.max(0, Math.min(1, root.ratio())))
            height: 4
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentDeep }
                GradientStop { position: 1.0; color: Theme.accent }
            }
            Behavior on width { enabled: !sliderArea.pressed; NumberAnimation { duration: 90 } }
        }

        Rectangle {
            id: handle
            x: Math.max(0, Math.min(trackArea.width - width,
                trackArea.width * Math.max(0, Math.min(1, root.ratio())) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: sliderArea.containsMouse || sliderArea.pressed ? Theme.accent : Theme.text
            border.width: 2
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)

            Rectangle {
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 12
                color: Theme.accent
                opacity: sliderArea.pressed ? 0.28 : (sliderArea.containsMouse ? 0.16 : 0)
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            enabled: root.enabled
            cursorShape: Qt.PointingHandCursor

            function update(mx) {
                var r = Math.max(0, Math.min(1, (mx + 6) / trackArea.width));
                var v = root.quantize(root.from + r * (root.to - root.from));
                if (v !== root.shown) {
                    root.shown = v;
                    root.moved(v);
                }
            }

            onPressed: (mouse) => { root.dragging = true; update(mouse.x); }
            onPositionChanged: (mouse) => { if (pressed) update(mouse.x); }
            onReleased: { root.dragging = false; root.released(); }
            onCanceled: root.dragging = false
            onWheel: (wheel) => {
                var v = root.quantize(root.shown + (wheel.angleDelta.y > 0 ? root.step : -root.step));
                if (v !== root.shown) {
                    root.shown = v;
                    root.moved(v);
                    root.released();
                }
            }
        }
    }
}
