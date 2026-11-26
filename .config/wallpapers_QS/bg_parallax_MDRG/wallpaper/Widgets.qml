import Quickshell
import QtQuick
import QtQuick.Effects

// ===== WIDGETS: картинки, гіфки, відео — скільки завгодно штук (settings.json -> widgets.items) =====
// Один блок у shell.qml, а самі віджети додаються в JSON: кожен елемент списку = один віджет.
Repeater {
    id: widgets

    required property var cfg        // settings.json -> widgets
    required property var parallax   // модуль Parallax

    // ===== КЛІК (onClick: left / right / middle) =====
    // У віджеті в settings.json:  "onClick": { "left": "команда", "right": ["програма","арг"], "middle": "команда" }
    //   рядок = shell-команда (виконується з папки з shell.qml), масив = програма + аргументи;
    //   рядок/масив замість об'єкта = лише лівий клік; кнопка, якої нема в onClick, не перехоплюється
    //   "hit": "alpha" | "box"  — alpha: клікабельні лише непрозорі пікселі (за замовчуванням для png), box: весь віджет
    //   "hitAlpha": 20 — поріг прозорості 0..255;  "pointer": false — без «руки» над віджетом
    component ClickArea: MouseArea {
        id: root

        property var actions: undefined        // значення onClick з settings.json
        property var owner: null               // Widgets (там runClick)
        property string source: ""             // повний URL картинки (для hit: "alpha"); "" = лише box
        property int fillMode: Image.PreserveAspectFit
        property string hit: "alpha"           // alpha | box
        property int alphaMin: 20
        property bool pointer: true
        property int maskSide: 512             // найбільша сторона маски прозорості, px (менше = менше пам'яті)

        // нормалізація onClick: рядок/масив = лише left
        readonly property var acts: {
            const a = actions;
            if (a === undefined || a === null) return ({});
            if (typeof a === "string" || Array.isArray(a) || typeof a.length === "number") return ({ left: a });
            return a;
        }
        readonly property bool hasLeft: acts.left !== undefined && acts.left !== ""
        readonly property bool hasRight: acts.right !== undefined && acts.right !== ""
        readonly property bool hasMiddle: acts.middle !== undefined && acts.middle !== ""

        enabled: hasLeft || hasRight || hasMiddle
        acceptedButtons: (hasLeft ? Qt.LeftButton : 0) | (hasRight ? Qt.RightButton : 0) | (hasMiddle ? Qt.MiddleButton : 0)
        cursorShape: pointer ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: mouse => { if (owner) owner.runClick(acts, mouse.button); }

        // ===== МАСКА ПРОЗОРОСТІ =====
        property var maskData: null    // RGBA-байти зменшеної копії картинки
        property int maskW: 0
        property int maskH: 0
        property real imgW: 0          // розмір оригіналу
        property real imgH: 0
        readonly property bool maskReady: maskData !== null && maskW > 0 && imgW > 0 && imgH > 0

        // перевірка точки (координати цього елемента) — викликається з containmentMask
        function hitTest(px, py) {
            if (px < 0 || py < 0 || px >= width || py >= height) return false;
            if (hit !== "alpha" || !maskReady) return true;    // поки маска не готова — працює як box

            // де саме картинка лежить в елементі (з урахуванням fit / crop / pad)
            let pw = width, ph = height;
            if (fillMode !== Image.Stretch) {
                let s = 1;
                if (fillMode === Image.PreserveAspectFit) s = Math.min(width / imgW, height / imgH);
                else if (fillMode === Image.PreserveAspectCrop) s = Math.max(width / imgW, height / imgH);
                pw = imgW * s; ph = imgH * s;
            }
            const u = (px - (width - pw) / 2) / pw;
            const v = (py - (height - ph) / 2) / ph;
            if (!(u >= 0 && u < 1 && v >= 0 && v < 1)) return false;
            const mx = Math.min(maskW - 1, Math.floor(u * maskW));
            const my = Math.min(maskH - 1, Math.floor(v * maskH));
            return maskData[(my * maskW + mx) * 4 + 3] >= alphaMin;
        }

        containmentMask: QtObject {
            function contains(point: point) : bool { return root.hitTest(point.x, point.y); }
        }

        // маска створюється лише коли треба (є onClick, hit: "alpha" і є картинка)
        Loader {
            active: root.enabled && root.hit === "alpha" && root.source !== ""
            sourceComponent: Item {
                Image {
                    id: probe
                    source: root.source
                    visible: false
                    asynchronous: true
                    cache: true
                    onStatusChanged: if (status === Image.Ready) {
                        root.imgW = implicitWidth;
                        root.imgH = implicitHeight;
                        cv.requestPaint();
                    }
                }

                Canvas {
                    id: cv
                    opacity: 0.01
                    renderTarget: Canvas.Image
                    readonly property real k: Math.min(1, root.maskSide / Math.max(1, probe.implicitWidth, probe.implicitHeight))
                    width: Math.max(1, Math.round(probe.implicitWidth * k))
                    height: Math.max(1, Math.round(probe.implicitHeight * k))

                    onAvailableChanged: if (available) loadImage(root.source)
                    onImageLoaded: requestPaint()
                    onPaint: {
                        if (probe.status !== Image.Ready || !isImageLoaded(root.source)) return;
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.drawImage(root.source, 0, 0, width, height);
                        root.maskData = ctx.getImageData(0, 0, width, height).data;
                        root.maskW = width;
                        root.maskH = height;
                    }
                }
            }
        }
    }


    function runAction(a) {
        if (a === undefined || a === null || a === "") return;
        if (typeof a !== "string") Quickshell.execDetached(Array.prototype.slice.call(a).map(String));
        else Quickshell.execDetached(["sh", "-c", "cd \"$1\" 2>/dev/null; eval \"$2\"", "sh", Quickshell.shellDir, a]);
    }
    function runClick(acts, button) {
        if (!acts) return;
        const key = button === Qt.RightButton ? "right" : (button === Qt.MiddleButton ? "middle" : "left");
        runAction(acts[key]);
    }

    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    model: (cfg.enabled === false || !Array.isArray(cfg.items)) ? [] : cfg.items

    delegate: Item {
        id: w

        required property var modelData
        required property int index

        // читання параметра віджета: opt("x", 0) — якщо ключа нема, береться значення за замовчуванням
        function opt(k, d) { return (modelData && modelData[k] !== undefined) ? modelData[k] : d; }

//////// ЗАГАЛЬНЕ
        readonly property bool on: opt("enabled", true)
        readonly property string type: opt("type", "image")          // image (png, jpg, gif...) або video
        readonly property string resolved: widgets.parallax.url(opt("source", ""))
        readonly property bool isVideo: type === "video"
        readonly property bool animated: opt("animated", /\.(gif|apng|webp)$/i.test(String(opt("source", "")).split("?")[0]))

//////// ПОЗИЦІЯ І РОЗМІР
        readonly property bool centered: opt("anchor", "top-left") === "center"   // true = x/y це центр віджета
        readonly property real cfgW: opt("width", 0)                  // 0 = авто (розмір файлу)
        readonly property real cfgH: opt("height", 0)                 // 0 = авто (зберігає пропорції)
        readonly property real natW: isVideo ? (videoLoader.item ? videoLoader.item.natW : 0) : (animated ? anim.implicitWidth : still.implicitWidth)
        readonly property real natH: isVideo ? (videoLoader.item ? videoLoader.item.natH : 0) : (animated ? anim.implicitHeight : still.implicitHeight)

//////// ШАР І ПАРАЛАКС (atLayer / afterLayer / followLayer / zOffset / parallax — див. Parallax.qml)
        z: widgets.parallax.zOf(modelData)
        readonly property real depth: widgets.parallax.depthOf(modelData)   // без шарів = 0 (раніше ділення на нуль)

//////// ВИГЛЯД
        readonly property real radius: opt("radius", 0)               // заокруглення кутів
        readonly property int fill: {
            const f = opt("fit", "contain");   // contain / cover / stretch / none
            return f === "cover" ? Image.PreserveAspectCrop
                 : (f === "stretch" ? Image.Stretch
                 : (f === "none" ? Image.Pad : Image.PreserveAspectFit));
        }

        visible: on && resolved !== ""

        width: cfgW > 0 ? cfgW : ((cfgH > 0 && natH > 0) ? cfgH * natW / natH : natW)
        height: cfgH > 0 ? cfgH : ((cfgW > 0 && natW > 0) ? cfgW * natH / natW : natH)
        x: opt("x", 0) - (centered ? width / 2 : 0)
        y: opt("y", 0) - (centered ? height / 2 : 0)

        opacity: opt("opacity", 1.0)
        rotation: opt("rotation", 0)
        scale: opt("scale", 1.0)

        transform: [
            Scale { origin.x: w.width / 2; xScale: w.opt("mirror", false) ? -1 : 1 },   // віддзеркалення
            Translate { x: widgets.parallax.dx(w.depth); y: widgets.parallax.dy(w.depth) }
        ]

        Item {
            id: box
            anchors.fill: parent
            layer.enabled: w.radius > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskItem
            }

            // звичайна картинка (PNG з прозорістю, JPG, ...)
            Image {
                id: still
                anchors.fill: parent
                visible: !w.isVideo && !w.animated
                source: (!w.isVideo && !w.animated) ? w.resolved : ""
                fillMode: w.fill
                smooth: w.opt("smooth", true)
                mipmap: w.opt("smooth", true)
                asynchronous: true
                cache: true
            }

            // анімована (GIF та ін.)
            AnimatedImage {
                id: anim
                anchors.fill: parent
                visible: !w.isVideo && w.animated
                source: (!w.isVideo && w.animated) ? w.resolved : ""
                fillMode: w.fill
                smooth: w.opt("smooth", true)
                playing: w.opt("playing", true)
                asynchronous: true
                cache: true
            }

            // відео: в окремому файлі, щоб відсутній QtMultimedia не ламав решту конфігу
            Loader {
                id: videoLoader
                anchors.fill: parent
                active: w.isVideo && w.on
                source: "VideoWidget.qml"
                onLoaded: {
                    item.cfg = Qt.binding(() => w.modelData);
                    item.src = Qt.binding(() => w.resolved);
                }
                onStatusChanged: if (status === Loader.Error)
                    console.warn("widgets: не вдалося завантажити VideoWidget.qml (потрібен qt6-multimedia)")
            }
        }

        // клік по віджету; лежить під елементами керування відео (z: -1), тож вони не страждають
        ClickArea {
            z: -1
            anchors.fill: parent
            owner: widgets
            actions: w.modelData.onClick
            source: (w.modelData.onClick !== undefined && !w.isVideo) ? w.resolved : ""
            fillMode: w.fill
            hit: w.opt("hit", (w.isVideo || w.animated) ? "box" : "alpha")
            alphaMin: w.opt("hitAlpha", 20)
            pointer: w.opt("pointer", true)
        }

        // маска для заокруглення (потрібна лише якщо radius > 0)
        Rectangle {
            id: maskItem
            anchors.fill: parent
            radius: w.radius
            visible: false
            layer.enabled: true
        }

        // рамка
        Rectangle {
            anchors.fill: parent
            visible: w.opt("borderWidth", 0) > 0
            color: "transparent"
            radius: w.radius
            border.width: w.opt("borderWidth", 0)
            border.color: widgets.tint(w.opt("borderColor", "#ffffff"), w.opt("borderAlpha", 1.0))
        }
    }
}
