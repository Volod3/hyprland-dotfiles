import Quickshell
import QtQuick

// ===== PARALLAX =====
// Шари картинок, що рухаються за курсором, і спільні функції для модулів:
// де модуль стоїть між шарами (zOf), наскільки рухається (depthOf, dx, dy), шлях до файлу (url).
Item {
    id: root

    required property var cfg   // settings.json -> parallax
    required property var win   // PanelWindow поточного екрана

    // глобальна позиція курсора (її дає shell.qml — один hyprctl на всі екрани)
    property real cx: 0
    property real cy: 0

    anchors.fill: parent
    clip: true

    // ===== НАЛАШТУВАННЯ =====
    // шари: від найдальшого (перший, номер 0) до найближчого (останній); кількість не обмежена (0 теж можна)
    readonly property var layers: Array.isArray(cfg.layers) ? cfg.layers : []
    readonly property real strength: num(cfg.strength, 20)   // макс. зсув (px) найближчого шару
    readonly property bool invert: cfg.invert === true      // true = шари рухаються в бік курсора
    readonly property int smoothMs: num(cfg.smoothMs, 150)  // плавність руху

    // позиція курсора відносно цього екрана (-1..1)
    property real nx: Math.max(-1, Math.min(1, ((cx - win.screen.x) / Math.max(1, win.screen.width)) * 2 - 1))
    property real ny: Math.max(-1, Math.min(1, ((cy - win.screen.y) / Math.max(1, win.screen.height)) * 2 - 1))
    Behavior on nx { NumberAnimation { duration: root.smoothMs; easing.type: Easing.OutCubic } }
    Behavior on ny { NumberAnimation { duration: root.smoothMs; easing.type: Easing.OutCubic } }

    // ===== СПІЛЬНЕ ДЛЯ МОДУЛІВ =====
    function num(v, d) { return (typeof v === "number" && isFinite(v)) ? v : d; }

    // шлях: відносний (від папки з shell.qml), ~/..., /абсолютний, або готовий URL (file://, http(s)://, qrc:)
    function url(p) {
        if (p === undefined || p === null || p === "") return "";
        p = String(p);
        if (p.indexOf("://") !== -1 || p.startsWith("qrc:")) return p;
        if (p.startsWith("~/")) p = Quickshell.env("HOME") + p.slice(1);
        if (!p.startsWith("/")) p = Quickshell.shellPath(p);
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    // "atLayer": N    — у площині шару N (над його картинкою), рухається точно як він
    // "afterLayer": N — між шарами N і N+1, рухається посередині між ними
    // "followLayer": N — переозначити, за яким шаром рухатись (можна дробове, 6.5)
    // "zOffset": x    — підняти/опустити серед сусідів на тому ж шарі
    // "parallax": false — стояти на місці
    function hasAt(c) { return !!c && c.atLayer !== undefined; }
    function placeOf(c) { return hasAt(c) ? num(c.atLayer, 0) : num(c ? c.afterLayer : undefined, 0); }
    function zOf(c) { return placeOf(c) + (hasAt(c) ? 0.25 : 0.5) + num(c ? c.zOffset : undefined, 0); }
    // глибина шару i: поле "depth" (0 = нерухомий горизонт, 1 = найближче; його пише tools/parallax/parallax.py),
    // а якщо нема — як раніше, (i + 1) / кількість
    function layerDepth(i) {
        const n = layers.length;
        if (n === 0) return 0;
        i = Math.max(0, Math.min(n - 1, i));
        const l = layers[i];
        const d = (l && typeof l === "object") ? l.depth : undefined;
        return num(d, (i + 1) / n);
    }
    function depthOf(c) {
        if (!c || c.parallax === false || layers.length === 0) return 0;
        const follow = num(c.followLayer, placeOf(c) + (hasAt(c) ? 0 : 0.5));
        // дробовий шар (6.5) — посередині між глибинами сусідніх шарів
        const lo = Math.floor(follow), t = follow - lo;
        return layerDepth(lo) * (1 - t) + layerDepth(lo + 1) * t;
    }
    function dx(depth) { return (invert ? 1 : -1) * nx * strength * depth; }
    function dy(depth) { return (invert ? 1 : -1) * ny * strength * depth; }

    // ===== ШАРИ =====
    // Параметри шару (усі необов'язкові): x, y (зсув, px), scale, opacity,
    // crop: true (заповнити екран), speed: px/с (самоплив по колу, мінус = в інший бік)
    Repeater {
        model: root.layers.length

        Item {
            id: lay

            required property int index
            readonly property var opts: {
                const l = root.layers[index];
                return (typeof l === "string") ? ({ file: l }) : (l || ({}));
            }
            readonly property real depth: root.layerDepth(index)
            readonly property real speed: root.num(opts.speed, 0)
            property real scroll: 0

            z: index
            width: root.width + 2 * root.strength
            height: root.height + 2 * root.strength
            x: -root.strength + root.num(opts.x, 0) + root.dx(depth)
            y: -root.strength + root.num(opts.y, 0) + root.dy(depth)
            scale: root.num(opts.scale, 1)
            opacity: root.num(opts.opacity, 1)

            // самоплив: анімація крутиться лише там, де speed != 0
            // (раніше таймер працював завжди і змушував перемальовувати весь екран 60 разів/с навіть без руху)
            NumberAnimation on scroll {
                id: scrollAnim
                running: lay.speed !== 0 && lay.width > 0
                from: lay.speed > 0 ? 0 : lay.width
                to: lay.speed > 0 ? lay.width : 0
                duration: Math.max(1, Math.abs(lay.width / (lay.speed || 1)) * 1000)
                loops: Animation.Infinite
            }
            onSpeedChanged: { scroll = 0; if (scrollAnim.running) scrollAnim.restart(); }
            onWidthChanged: if (scrollAnim.running) scrollAnim.restart()

            // 2 копії поруч, щоб шар прокручувався по колу без шва (якщо картинка тайлиться по горизонталі)
            Repeater {
                model: lay.speed === 0 ? 1 : 2

                Image {
                    required property int index
                    x: lay.scroll - index * lay.width
                    width: lay.width
                    height: lay.height

                    source: root.url(lay.opts.file)
                    fillMode: lay.opts.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: true
                }
            }
        }
    }
}
