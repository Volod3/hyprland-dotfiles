import Quickshell
import QtQuick

// Спрайти всіх станів завантажуються ОДИН раз і лише перемикаються —
// ніяких перезавантажень gif і блимання при зміні idle <-> walk <-> fly.
Item {
    id: spriteView

    property var cfg: ({})
    property string stateName: "idle"
    property bool active: true
    property bool flipX: false

    readonly property var sprites: (cfg && cfg.sprites && typeof cfg.sprites === "object") ? cfg.sprites : ({})
    readonly property var stateKeys: Object.keys(sprites)
    // Якщо потрібного стану нема в конфігу — падаємо назад на idle
    readonly property string resolvedState: sprites[stateName] ? stateName : (sprites.idle ? "idle" : "")
    readonly property bool smoothScaling: !(cfg && cfg.pixelArt === true)

    // шлях з пробілами, кирилицею чи # тепер правильно перетворюється на URL
    function resolveUrl(p) {
        if (!p || typeof p !== "string" || !p.trim().length) return ""
        let s = p.trim()
        if (s.indexOf("://") !== -1) return s
        if (s.startsWith("~/")) s = Quickshell.env("HOME") + s.slice(1)
        else if (!s.startsWith("/")) s = Quickshell.shellPath(s.replace(/^\.\//, ""))
        return "file://" + s.split("/").map(encodeURIComponent).join("/")
    }

    function isList(v) { return v !== null && typeof v === "object" && typeof v.length === "number" }

    function gifOf(spec) {
        if (!spec) return ""
        if (typeof spec.gif === "string" && spec.gif.trim().length) return resolveUrl(spec.gif)
        if (isList(spec.frames) && spec.frames.length === 1) {
            const one = String(spec.frames[0] || "")
            if (one.toLowerCase().endsWith(".gif")) return resolveUrl(one)
        }
        return ""
    }

    function framesOf(spec) {
        if (!spec || gifOf(spec).length > 0) return []
        return isList(spec.frames) ? Array.prototype.slice.call(spec.frames) : []
    }

    readonly property bool hasSprite: {
        for (let i = 0; i < stateKeys.length; i++) {
            const sp = sprites[stateKeys[i]]
            if (gifOf(sp).length > 0 || framesOf(sp).length > 0) return true
        }
        return false
    }

    // Усі картинки спрайтів (для прогріву кешу перед розльотом)
    readonly property var allSources: {
        const out = []
        for (let i = 0; i < stateKeys.length; i++) {
            const sp = sprites[stateKeys[i]]
            let u = gifOf(sp)
            if (u.length === 0) {
                const fr = framesOf(sp)
                if (fr.length > 0) u = resolveUrl(fr[0])
            }
            if (u.length > 0 && out.indexOf(u) < 0) out.push(u)
        }
        return out
    }

    // Шлях до картинки, яка показується просто зараз (для розліту на шматочки)
    function sourceNow() {
        const idx = stateKeys.indexOf(resolvedState)
        if (idx < 0) return ""
        const it = layerRep.itemAt(idx)
        return it ? it.src : ""
    }

    Item {
        id: flipper
        anchors.fill: parent
        transform: Scale {
            origin.x: flipper.width / 2
            origin.y: flipper.height / 2
            xScale: spriteView.flipX ? -1 : 1
            yScale: 1
        }

        Repeater {
            id: layerRep
            model: spriteView.stateKeys

            delegate: Item {
                id: lay
                required property string modelData

                readonly property var spec: spriteView.sprites[modelData] || ({})
                readonly property bool current: modelData === spriteView.resolvedState
                readonly property string gif: spriteView.gifOf(spec)
                readonly property var frames: spriteView.framesOf(spec)
                readonly property int fps: Math.max(1, parseInt(spec.fps || 4, 10) || 4)
                property int frameIndex: 0
                readonly property string src: gif.length > 0
                    ? gif
                    : (frames.length > 0 ? spriteView.resolveUrl(frames[frameIndex % frames.length]) : "")

                anchors.fill: parent
                visible: current
                onCurrentChanged: if (current) frameIndex = 0

                AnimatedImage {
                    anchors.fill: parent
                    visible: lay.gif.length > 0
                    source: lay.gif
                    fillMode: Image.PreserveAspectFit
                    smooth: spriteView.smoothScaling
                    cache: true
                    playing: lay.current && spriteView.active && lay.spec.playing !== false
                }

                Image {
                    anchors.fill: parent
                    visible: lay.gif.length === 0 && lay.frames.length > 0
                    source: (lay.gif.length === 0 && lay.frames.length > 0) ? lay.src : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: spriteView.smoothScaling
                    cache: true
                }

                Timer {
                    interval: Math.round(1000 / lay.fps)
                    repeat: true
                    running: lay.current && spriteView.active && lay.frames.length > 1
                    onTriggered: lay.frameIndex = (lay.frameIndex + 1) % lay.frames.length
                }
            }
        }
    }
}
