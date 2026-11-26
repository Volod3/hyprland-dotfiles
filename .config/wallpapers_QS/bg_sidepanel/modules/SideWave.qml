import QtQuick

// Хвилястий прогрес-бар плеєра: хвиля "біжить", поки грає музика, і розпрямляється на паузі.
// Перемотка: під час тягнення бігунок рухається лише візуально, а позиція відправляється плеєру,
// коли відпускаєш (раніше — на кожен рух миші, що смикало звук і засипало D-Bus).
Item {
    id: w

    required property var theme
    property real progress: 0       // 0..1
    property bool playing: false
    property bool active: true      // false, коли панель закрита (зупиняє анімацію)
    property bool seekable: true
    property real phase: 0
    property real amplitude: playing ? 3.2 : 0

    property bool dragging: false
    property real dragFrac: 0
    readonly property real shownProgress: (dragging || holdTimer.running) ? dragFrac : progress

    signal seek(real fraction)

    height: 24

    Behavior on amplitude { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

    NumberAnimation on phase {
        running: w.playing && w.active
        from: 0; to: Math.PI * 2
        duration: 1300
        loops: Animation.Infinite
    }

    onPhaseChanged: canvas.requestPaint()
    onShownProgressChanged: canvas.requestPaint()
    onAmplitudeChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onThemeChanged: canvas.requestPaint()

    function css(c) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a + ")"
    }

    // після відпускання ще мить показуємо нову позицію, поки плеєр її застосує (без «стрибка» назад)
    Timer { id: holdTimer; interval: 400 }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (width < 10) return
            const mid = height / 2
            const x0 = 3
            const x1 = width - 5
            const px = x0 + (x1 - x0) * Math.max(0, Math.min(1, w.shownProgress))
            const waveY = (x) => mid + Math.sin(x / 8 - w.phase) * w.amplitude * Math.min(1, (x - x0) / 14)

            ctx.lineCap = "round"
            ctx.lineWidth = 4

            // решта доріжки
            ctx.strokeStyle = w.css(w.theme.track)
            ctx.beginPath()
            ctx.moveTo(px, mid)
            ctx.lineTo(x1, mid)
            ctx.stroke()

            // хвиля до поточної позиції (на початку плавно виходить із лінії)
            ctx.strokeStyle = w.css(w.theme.accent)
            ctx.beginPath()
            ctx.moveTo(x0, waveY(x0))
            for (let x = x0 + 2; x < px; x += 2) ctx.lineTo(x, waveY(x))
            ctx.lineTo(px, waveY(px))          // дотягнути рівно до бігунка (раніше міг лишатись зазор)
            ctx.stroke()

            // бігунок
            ctx.fillStyle = w.css(w.theme.accent)
            ctx.fillRect(px - 2, mid - 9, 4, 18)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: w.seekable
        preventStealing: true
        cursorShape: w.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor

        function frac(mx) { return Math.max(0, Math.min(1, (mx - 3) / Math.max(1, width - 8))) }

        onPressed: (m) => { w.dragging = true; w.dragFrac = frac(m.x) }
        onPositionChanged: (m) => { if (pressed && w.dragging) w.dragFrac = frac(m.x) }
        onReleased: (m) => {
            if (!w.dragging) return
            w.dragFrac = frac(m.x)
            w.dragging = false
            holdTimer.restart()
            w.seek(w.dragFrac)
        }
        onCanceled: w.dragging = false
    }
}
