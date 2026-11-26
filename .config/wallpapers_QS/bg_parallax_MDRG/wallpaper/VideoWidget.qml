import QtQuick
import QtMultimedia

// ===== VIDEO WIDGET =====
// Вантажиться з Widgets.qml (потрібен qt6-multimedia). Параметри — з елемента widgets.items у settings.json.
Item {
    id: root

    property var cfg: ({})     // елемент widgets.items[i]
    property string src: ""    // повний URL відео

    function opt(k, d) { return (cfg && cfg[k] !== undefined) ? cfg[k] : d; }

    // controls: false/нема = без керування; true = усе; або об'єкт {"pause":true,"seek":true,"volume":true,...}
    function ctl(k, d) {
        const c = cfg ? cfg.controls : undefined;
        if (c === true) return d;
        if (c && typeof c === "object") return c[k] !== undefined ? c[k] : d;
        return false;
    }
    function style(k, d) {
        const c = cfg ? cfg.controls : undefined;
        return (c && typeof c === "object" && c[k] !== undefined) ? c[k] : d;
    }
    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }
    function fmtBtn() { return player.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"; }
    function toggle() {
        if (player.playbackState === MediaPlayer.PlayingState) player.pause();
        else player.play();
    }

    // природний розмір відео (для авто-розміру віджета)
    readonly property real natW: out.sourceRect.width
    readonly property real natH: out.sourceRect.height

    property bool curMuted: opt("muted", true)       // за замовчуванням без звуку
    property real curVolume: opt("volume", 0.5)
    property bool started: false

    // що з керування показувати (саме з конфігу, а не з visible — той залежить від того, чи видно панель)
    readonly property bool showPause: ctl("pause", true)
    readonly property bool showSeek: ctl("seek", true)
    readonly property bool showVolume: ctl("volume", true)
    readonly property bool anyControls: showPause || showSeek || showVolume
    readonly property color cAccent: style("color", "#ffffff")

    // повзунок 0..1 (для перемотки та гучності)
    component SliderBar: Item {
        id: sb
        property real value: 0
        property color accent: "#ffffff"
        property real trackHeight: 4
        property bool dragging: false
        property real dragValue: 0
        signal moved(real v)        // під час тягнення
        signal committed(real v)    // коли відпустили
        // після відпускання ще мить показуємо нову позицію, поки плеєр її застосує (без «стрибка» назад)
        readonly property real shown: (dragging || holdTimer.running) ? dragValue : value

        implicitHeight: 16

        Timer { id: holdTimer; interval: 300 }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: sb.trackHeight
            radius: height / 2
            color: Qt.rgba(sb.accent.r, sb.accent.g, sb.accent.b, 0.25)

            Rectangle {
                id: fillBar
                height: parent.height
                radius: height / 2
                color: sb.accent
                width: parent.width * Math.max(0, Math.min(1, sb.shown))
            }
            Rectangle {
                width: 12; height: 12; radius: 6
                color: sb.accent
                anchors.verticalCenter: parent.verticalCenter
                x: fillBar.width - width / 2
                scale: sb.dragging ? 1.3 : (area.containsMouse ? 1 : 0.7)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            function frac(mx) { return Math.max(0, Math.min(1, mx / width)); }

            onPressed: mouse => { sb.dragging = true; sb.dragValue = frac(mouse.x); sb.moved(sb.dragValue); }
            onPositionChanged: mouse => { if (pressed && sb.dragging) { sb.dragValue = frac(mouse.x); sb.moved(sb.dragValue); } }
            onReleased: { sb.dragging = false; holdTimer.restart(); sb.committed(sb.dragValue); }
            onCanceled: sb.dragging = false
        }
    }

    MediaPlayer {
        id: player
        source: root.src
        videoOutput: out
        audioOutput: AudioOutput { volume: root.curVolume; muted: root.curMuted }
        loops: root.opt("loop", true) ? MediaPlayer.Infinite : 1
        playbackRate: root.opt("speed", 1.0)

        // нове відео (змінили source у settings.json) — знову автозапуск; раніше лишалось на паузі
        onSourceChanged: root.started = false

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && !root.started) {
                root.started = true;
                if (root.opt("autoplay", true)) play();
                else pause();       // показати перший кадр
            }
        }
        onErrorOccurred: (error, errorString) => console.warn("widgets: відео", root.src, "—", errorString)
    }

    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: {
            const f = root.opt("fit", "contain");   // contain / cover / stretch
            return f === "cover" ? VideoOutput.PreserveAspectCrop
                 : (f === "stretch" ? VideoOutput.Stretch : VideoOutput.PreserveAspectFit);
        }
    }

    HoverHandler { id: hover }

    // клік по відео = пауза/відтворення (якщо clickToPause: true)
    MouseArea {
        anchors.fill: parent
        enabled: root.opt("clickToPause", false)
        onClicked: root.toggle()
    }

    // ===== ЕЛЕМЕНТИ КЕРУВАННЯ =====
    Item {
        id: bar
        visible: root.anyControls && opacity > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.style("margin", 10)
        height: root.style("height", 32)
        opacity: (root.ctl("always", false) || hover.hovered || seekBar.dragging || volBar.dragging) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.tint(root.style("backgroundColor", "#000000"), root.style("backgroundAlpha", 0.45))
        }

        // пауза / відтворення
        Item {
            id: pauseBtn
            visible: root.showPause
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.showPause ? parent.height : 0
            height: parent.height

            Text {
                anchors.centerIn: parent
                text: root.fmtBtn()
                color: root.cAccent
                font.pixelSize: parent.height * 0.5
                scale: pauseMouse.pressed ? 0.85 : (pauseMouse.containsMouse ? 1.15 : 1)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }
            MouseArea {
                id: pauseMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle()
            }
        }

        // перемотка
        SliderBar {
            id: seekBar
            visible: root.showSeek
            anchors.left: root.showPause ? pauseBtn.right : parent.left
            anchors.right: root.showVolume ? volBox.left : parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            accent: root.cAccent
            value: player.duration > 0 ? player.position / player.duration : 0
            onCommitted: v => { if (player.seekable && player.duration > 0) player.position = v * player.duration; }
        }

        // гучність: іконка (клік = вимкнути/увімкнути звук) + повзунок
        Item {
            id: volBox
            visible: root.showVolume
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: root.showVolume ? 24 + 8 + root.style("volumeWidth", 70) : 0
            height: parent.height

            Text {
                id: volIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: (root.curMuted || root.curVolume <= 0) ? "🔇" : (root.curVolume < 0.5 ? "🔉" : "🔊")
                color: root.cAccent
                font.pixelSize: parent.height * 0.45
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // увімкнули звук на нулі — повертаємо чутну гучність
                        if (root.curMuted && root.curVolume <= 0) root.curVolume = 0.5;
                        root.curMuted = !root.curMuted;
                    }
                }
            }
            SliderBar {
                id: volBar
                anchors.left: volIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                accent: root.cAccent
                value: root.curMuted ? 0 : root.curVolume
                onMoved: v => { root.curVolume = v; root.curMuted = v <= 0; }
            }
        }
    }
}
