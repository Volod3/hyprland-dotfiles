import Quickshell.Io
import QtQuick
import QtQuick.Effects

// ===== ВІЗУАЛІЗАТОР (cava) =====
Item {
    id: root

    required property var cfg        // settings.json -> visualizer
    required property var parallax   // модуль Parallax

    // opt("bars", "count", 64) — якщо ключа нема, береться значення за замовчуванням
    function opt(g, k, d) {
        const o = cfg[g];
        return (o !== undefined && o !== null && o[k] !== undefined) ? o[k] : d;
    }

    // ===== СМУГИ =====
    readonly property int barCount: Math.max(1, Math.round(opt("bars", "count", 64)))
    readonly property bool bidirectional: opt("bars", "bidirectional", false) === true
    readonly property real maxHeight: opt("bars", "maxHeight", 300)
    readonly property real spacing: opt("bars", "spacing", 2)
    readonly property real overflow: opt("bars", "overflow", 0)
    readonly property real offsetY: opt("bars", "offsetY", 0)
    readonly property real radiusMax: opt("bars", "radius", 6)
    readonly property real barsOpacity: opt("bars", "opacity", 0.8)
    readonly property real gain: opt("bars", "gain", 1.0)
    readonly property color colorTop: opt("bars", "colorTop", "#00ccff")
    readonly property color colorBottom: opt("bars", "colorBottom", "#000066")
    // ── «фішки» (задає тема) ──
    readonly property real reflection: opt("bars", "reflection", 0)       // 0..1 — віддзеркалення під лінією (лише однобічні смуги)
    readonly property real reflectionHeight: opt("bars", "reflectionHeight", 0.45)
    readonly property bool peaksOn: opt("bars", "peaks", false) === true   // «падаючі піки» над смугами
    readonly property real peakFall: opt("bars", "peakFall", 0.9)          // швидкість падіння піка, частка висоти за секунду
    readonly property int segment: opt("bars", "segment", 0)               // >0 — смуги з «кубиків» висотою N px (LED)
    readonly property int segmentGap: opt("bars", "segmentGap", 3)
    readonly property bool fade: opt("bars", "fade", false) === true
    // лінія силуету (частки висоти екрана для кожної смуги; рахує tools/themes/ridge.py) — смуги ростуть з-за рельєфу
    readonly property var ridge: { const r = opt("bars", "ridge", null); return r && r.length > 1 ? r : null }   // список з JSON — не JS Array, тож без Array.isArray
    readonly property bool ridgeMode: ridge !== null && !bidirectional
    readonly property real sink: opt("bars", "sink", 22)                   // наскільки основа смуги нижче лінії (схована за рельєфом)
    function ridgeY(i) {
        if (!ridgeMode) return height
        const f = i / Math.max(1, barCount - 1) * (ridge.length - 1)
        const a = Math.floor(f), b = Math.min(ridge.length - 1, a + 1), t = f - a
        return (ridge[a] * (1 - t) + ridge[b] * t) * height + sink
    }       // основа смуг розчиняється (смуги «виростають» з-за шару)

    // ===== СЯЙВО =====
    readonly property bool glowOn: opt("glow", "enabled", true)
    readonly property real glowOpacity: opt("glow", "opacity", 0.9)
    readonly property real glowBlur: opt("glow", "blur", 1.0)        // 0..1
    readonly property int glowRadius: opt("glow", "radius", 48)      // px

    // ===== CAVA =====
    readonly property int framerate: opt("cava", "framerate", 60)
    readonly property int noiseReduction: opt("cava", "noiseReduction", 77)
    readonly property string inputMethod: opt("cava", "input", "pipewire")
    readonly property string inputSource: opt("cava", "source", "auto")

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }

    property var levels: []        // 0..100 на кожну смугу
    property var peaks: []         // 0..1 — висота піка над кожною смугою
    property real lastPeakT: 0
    onLevelsChanged: {
        if (!peaksOn) return
        const now = Date.now()
        const dt = lastPeakT ? Math.min(0.1, (now - lastPeakT) / 1000) : 0
        lastPeakT = now
        const out = []
        for (let i = 0; i < barCount; i++) {
            const v = Math.max(0, Math.min(1, (levels[i] || 0) / 100 * gain))
            const p = Math.max(0, (peaks[i] || 0) - peakFall * dt)
            out.push(Math.max(v, p))
        }
        peaks = out
    }
    property string lastLine: ""

    readonly property string cavaConf:
        "[general]\n" +
        "bars = " + barCount + "\n" +
        "framerate = " + framerate + "\n" +
        "[input]\n" +
        "method = " + inputMethod + "\n" +
        "source = " + inputSource + "\n" +
        "[smoothing]\n" +
        "noise_reduction = " + noiseReduction + "\n" +
        "[output]\n" +
        "method = raw\n" +
        "raw_target = /dev/stdout\n" +
        "data_format = ascii\n" +
        "ascii_max_range = 100\n" +
        "bar_delimiter = 59\n" +
        "frame_delimiter = 10\n"

    // Конфіг пишеться атомарно (тимчасовий файл + mv) у $XDG_RUNTIME_DIR: на кількох екранах
    // кілька cava більше не перезаписують один /tmp-файл одночасно.
    Process {
        id: cava
        running: true
        command: ["sh", "-c",
            'dir="${XDG_RUNTIME_DIR:-/tmp}"; f="$dir/cava_qs.conf"; ' +
            't=$(mktemp "$f.XXXXXX") || exit 1; printf "%s" "$1" > "$t" && mv -f "$t" "$f" || exit 1; ' +
            'exec cava -p "$f"',
            "sh", root.cavaConf]

        stdout: SplitParser {
            onRead: line => {
                // у тиші cava шле однакові кадри — не перемальовуємо 256 смуг даремно
                if (line === root.lastLine) return;
                root.lastLine = line;
                const v = line.split(";").filter(s => s.length > 0).map(Number);
                if (v.length > 0) root.levels = v;
            }
        }

        // cava впала (PipeWire ще не готовий після входу тощо) — пробуємо знову; раніше лишалась мертвою
        onRunningChanged: if (!running) {
            restartTimer.interval = root.restartNow ? 300 : 3000;
            root.restartNow = false;
            restartTimer.restart();
        }
    }
    property bool restartNow: false
    Timer {
        id: restartTimer
        onTriggered: cava.running = true
    }
    // змінились налаштування (кількість смуг тощо) — перезапустити cava з новим конфігом
    onCavaConfChanged: if (cava.running) { restartNow = true; cava.running = false; }

    // ===== ПОЗИЦІЯ МІЖ ШАРАМИ + ПАРАЛАКС =====
    z: parallax.zOf(cfg)
    readonly property real depth: parallax.depthOf(cfg)   // без шарів = 0 (раніше було ділення на нуль)
    transform: Translate { x: root.parallax.dx(root.depth); y: root.parallax.dy(root.depth) }

    x: ridgeMode ? 0 : -overflow
    width: ridgeMode ? parent.width : parent.width + 2 * overflow
    anchors.bottom: parent.bottom
    anchors.bottomMargin: ridgeMode ? 0 : -offsetY - (bidirectional ? maxHeight : 0)
    height: ridgeMode ? parent.height : (bidirectional ? maxHeight * 2 : maxHeight)

    // ===== СЯЙВО =====
    MultiEffect {
        visible: root.glowOn
        source: barsContent
        anchors.fill: barsContent
        z: -1
        blurEnabled: true
        blur: root.glowBlur
        blurMax: root.glowRadius
        brightness: 0.25
        saturation: 0.5
        opacity: root.glowOpacity
    }

    // маска «кубиків» (LED) — статична, тож майже нічого не коштує
    Item {
        id: segMask
        anchors.fill: parent
        visible: false
        layer.enabled: root.segment > 0
        Repeater {
            model: root.segment > 0 ? Math.ceil(segMask.height / root.segment) : 0
            Rectangle {
                required property int index
                y: segMask.height - (index + 1) * root.segment
                width: segMask.width
                height: Math.max(1, root.segment - root.segmentGap)
                color: "black"
            }
        }
    }

    // ===== СМУГИ =====
    Item {
        id: barsContent
        anchors.fill: parent
        layer.enabled: root.segment > 0
        layer.effect: MultiEffect { maskEnabled: true; maskSource: segMask; maskThresholdMin: 0.5; maskSpreadAtMin: 0.0 }

        Repeater {
            model: root.barCount

            Rectangle {
                id: barItem
                required property int index
                readonly property real bw: Math.max(0, (barsContent.width - root.spacing * (root.barCount - 1)) / root.barCount)
                readonly property real val: Math.max(0, Math.min(1, (root.levels[index] || 0) / 100 * root.gain))

                x: index * (bw + root.spacing)
                width: bw
                height: root.bidirectional
                    ? Math.max(4, val * root.maxHeight * 2)
                    : Math.max(3, val * root.maxHeight)
                anchors.bottom: root.bidirectional || root.ridgeMode ? undefined : parent.bottom
                anchors.verticalCenter: root.bidirectional ? parent.verticalCenter : undefined
                y: root.ridgeMode ? root.ridgeY(index) - height : 0
                radius: Math.min(bw / 2, root.radiusMax)
                opacity: root.barsOpacity

                gradient: root.fade && !root.bidirectional ? fadeGrad : normGrad
                Gradient {
                    id: fadeGrad
                    GradientStop { position: 0.0; color: root.mix(root.colorBottom, root.colorTop, 0.45 + 0.55 * barItem.val) }
                    GradientStop { position: 0.55; color: root.colorBottom }
                    GradientStop { position: 1.0; color: Qt.rgba(root.colorBottom.r, root.colorBottom.g, root.colorBottom.b, 0) }
                }
                property Gradient normGrad: Gradient {
                    GradientStop {
                        position: 0.0
                        color: root.bidirectional
                            ? root.colorBottom
                            : root.mix(root.colorBottom, root.colorTop, barItem.val)
                    }
                    GradientStop {
                        position: 0.5
                        color: root.bidirectional
                            ? root.mix(root.colorBottom, root.colorTop, barItem.val)
                            : root.mix(root.colorBottom, root.colorTop, barItem.val * 0.5)
                    }
                    GradientStop {
                        position: 1.0
                        color: root.colorBottom
                    }
                }

                Behavior on height { NumberAnimation { duration: 50 } }
            }
        }
    }

    // ===== «ПАДАЮЧІ ПІКИ» =====
    Repeater {
        model: root.peaksOn && !root.bidirectional ? root.barCount : 0
        Rectangle {
            required property int index
            readonly property real bw: Math.max(0, (root.width - root.spacing * (root.barCount - 1)) / root.barCount)
            x: index * (bw + root.spacing)
            width: bw
            height: Math.max(2, Math.min(4, bw * 0.5))
            radius: height / 2
            y: (root.ridgeMode ? root.ridgeY(index) : root.height) - (root.peaks[index] || 0) * root.maxHeight - height - 4
            color: root.colorTop
            opacity: (root.peaks[index] || 0) > 0.02 ? root.barsOpacity : 0
        }
    }

    // ===== ВІДДЗЕРКАЛЕННЯ (під лінією, згасає донизу) =====
    Item {
        visible: root.reflection > 0 && !root.bidirectional
        anchors.top: parent.bottom
        anchors.topMargin: 2
        width: parent.width
        height: root.maxHeight * root.reflectionHeight
        opacity: root.reflection
        clip: true
        layer.enabled: visible
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.25; blurMax: 12 }
        Repeater {
            model: root.reflection > 0 && !root.bidirectional ? root.barCount : 0
            Rectangle {
                required property int index
                readonly property real bw: Math.max(0, (root.width - root.spacing * (root.barCount - 1)) / root.barCount)
                readonly property real val: Math.max(0, Math.min(1, (root.levels[index] || 0) / 100 * root.gain))
                x: index * (bw + root.spacing)
                width: bw
                height: Math.max(2, val * root.maxHeight * root.reflectionHeight)
                radius: Math.min(bw / 2, root.radiusMax)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.mix(root.colorBottom, root.colorTop, 0.4) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                Behavior on height { NumberAnimation { duration: 50 } }
            }
        }
    }
}
