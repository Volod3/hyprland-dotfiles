import Quickshell
import QtQuick

// ===== CLOCK =====
Item {
    id: root

    required property var cfg        // settings.json -> clock
    required property var parallax   // модуль Parallax

    function opt(k, d) { return cfg[k] !== undefined ? cfg[k] : d; }
    function fontOpt(k, d) { const f = cfg.font; return (f && f[k] !== undefined) ? f[k] : d; }

    // формат як у Qt.formatDateTime: "hh:mm", "hh:mm:ss", "dd.MM  hh:mm" ...
    readonly property string format: opt("format", "hh:mm")
    readonly property bool centered: opt("anchor", "top-left") === "center"   // true = x/y — це центр годинника

    // ===== ПОЗИЦІЯ МІЖ ШАРАМИ + ПАРАЛАКС =====
    z: parallax.zOf(cfg)
    readonly property real depth: parallax.depthOf(cfg)

    width: row.implicitWidth
    height: row.implicitHeight
    x: opt("x", 0) - (centered ? width / 2 : 0)
    y: opt("y", 0) - (centered ? height / 2 : 0)
    transform: Translate { x: root.parallax.dx(root.depth); y: root.parallax.dy(root.depth) }

    // оновлюється рівно на зміні хвилини (або секунди, якщо в форматі є секунди),
    // а не раз на секунду з запізненням до 1 с, як було з Timer
    SystemClock {
        id: clock
        precision: /s/.test(root.format) ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ===== ШРИФТ =====
    // font.weight: 100..900 (для змінних шрифтів типу Comfortaa/Outfit); якщо нема — bold true/false
    property font clockFont: Qt.font({
        family: fontOpt("family", ""),
        pixelSize: fontOpt("size", 120),
        weight: fontOpt("weight", fontOpt("bold", true) ? Font.Bold : Font.Normal),
        styleName: fontOpt("style", "")      // назва стилю зі шрифту: "Bold", "Light"... (надійніше для змінних шрифтів)
    })
    // кожна цифра — у клітинці ширини найширшої цифри, тож годинник не «стрибає»,
    // навіть якщо в шрифті цифри різної ширини ("monoDigits": false — вимкнути)
    readonly property bool monoDigits: opt("monoDigits", true)
    readonly property real digitWidth: {
        let w = 0
        for (let i = 0; i < 10; i++) w = Math.max(w, metrics.advanceWidth(String(i)))
        return w
    }
    FontMetrics { id: metrics; font: root.clockFont }

    readonly property string timeText: Qt.formatDateTime(clock.date, root.format)

    Row {
        id: row
        Repeater {
            model: root.timeText.length
            Text {
                required property int index
                readonly property string ch: root.timeText.charAt(index)
                readonly property bool digit: root.monoDigits && ch >= "0" && ch <= "9"
                text: ch
                width: digit ? root.digitWidth : implicitWidth
                horizontalAlignment: Text.AlignHCenter
                color: root.opt("color", "#ffffff")
                font: root.clockFont
            }
        }
    }
}
