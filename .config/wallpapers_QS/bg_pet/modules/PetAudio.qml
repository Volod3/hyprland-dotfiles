import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: audioRoot

    property var cfg: ({})

    // Запущені зараз звуки (щоб можна було обірвати старий голос новим)
    property var running: []
    readonly property bool isPlaying: running.length > 0

    readonly property var sndCfg: (cfg && cfg.sounds && typeof cfg.sounds === "object") ? cfg.sounds : ({})
    readonly property int maxVoices: {
        const v = Number(sndCfg.maxVoices)
        return isNaN(v) || v < 1 ? 4 : Math.floor(v)
    }
    readonly property bool interruptOld: sndCfg.interrupt !== false

    readonly property real soundVolume: {
        const raw = sndCfg.volume !== undefined ? sndCfg.volume : (sndCfg.gain !== undefined ? sndCfg.gain : 1.0)
        const num = Number(raw)
        if (isNaN(num)) return 1.0
        return Math.max(0.0, Math.min(2.0, num))
    }

    function isList(val) {
        if (!val || typeof val === "string") return false
        return Array.isArray(val) || (typeof val === "object" && typeof val.length === "number")
    }

    function toArray(val) {
        if (!isList(val)) return []
        const arr = []
        for (let i = 0; i < val.length; i++) arr.push(val[i])
        return arr
    }

    function resolveSoundPath(filePath) {
        if (!filePath) return ""
        const p = String(filePath).trim()
        if (p.length === 0) return ""
        if (p.startsWith("file://")) return p.replace(/^file:\/\//, "")
        if (p.startsWith("/")) return p
        if (p.startsWith("~")) return Quickshell.env("HOME") + p.slice(1)
        return Quickshell.shellPath(p.replace(/^\.\//, ""))
    }

    function forget(proc) {
        const i = running.indexOf(proc)
        if (i >= 0) {
            const copy = running.slice()
            copy.splice(i, 1)
            running = copy
        }
    }

    function stopAll() {
        const copy = running.slice()
        running = []
        for (let i = 0; i < copy.length; i++) {
            try { copy[i].running = false } catch (e) {}
        }
    }

    // Шлях і гучності передаються як аргументи (а не вклеюються в текст команди),
    // тому пробіли, лапки, "$" та "…" у назвах файлів більше нічого не ламають.
    // trap потрібен, щоб SIGTERM прибивав і сам програвач.
    readonly property string playerScript:
        'f="$1"; pid=\n' +
        'trap \'test -n "$pid" && kill "$pid" 2>/dev/null; exit 0\' TERM INT\n' +
        'try() { "$@" >/dev/null 2>&1 & pid=$!; wait "$pid"; }\n' +
        'if command -v pw-play >/dev/null 2>&1 && try pw-play --volume="$2" "$f"; then exit 0; fi\n' +
        'if command -v ffplay >/dev/null 2>&1 && try ffplay -nodisp -autoexit -loglevel quiet -volume "$3" "$f"; then exit 0; fi\n' +
        'if command -v paplay >/dev/null 2>&1 && try paplay --volume="$4" "$f"; then exit 0; fi\n' +
        'if command -v mpv >/dev/null 2>&1 && try mpv --no-video --really-quiet --volume="$3" "$f"; then exit 0; fi\n' +
        'exit 0\n'

    function playSingleFile(filePath, customVolume) {
        const resolved = resolveSoundPath(filePath)
        if (!resolved || resolved.length === 0) return
        if (running.length >= maxVoices) return

        const volRaw = customVolume !== undefined ? Number(customVolume) : soundVolume
        const vol = isNaN(volRaw) ? 1.0 : Math.max(0.0, Math.min(2.0, volRaw))
        if (vol <= 0) return

        const proc = soundProcComp.createObject(audioRoot, {
            "command": [
                "sh", "-c", playerScript, "sh",
                resolved,
                vol.toFixed(3),
                String(Math.round(vol * 100)),
                String(Math.max(0, Math.min(65536, Math.round(vol * 65536))))
            ]
        })
        if (proc) {
            running = running.concat([proc])
            proc.running = true
        }
    }

    function playSequentialList(files, delayMs, index, vol) {
        const arr = toArray(files)
        if (index >= arr.length) return
        playSingleFile(arr[index], vol)

        if (index + 1 < arr.length) {
            const stepDelay = Math.max(50, Number(delayMs !== undefined ? delayMs : 250))
            const t = seqTimerComp.createObject(audioRoot, {
                "interval": stepDelay,
                "filesQueue": arr,
                "stepDelayMs": stepDelay,
                "nextIdx": index + 1,
                "vol": vol
            })
            if (t) t.running = true
        }
    }

    // Повертає { files: [...], mode: "random" | "all" | null }
    function parseArrayWithSuffix(rawList) {
        const arr = toArray(rawList)
        if (arr.length === 0) return { files: [], mode: null }
        const last = arr[arr.length - 1]
        if (typeof last === "string") {
            const flag = last.trim().toLowerCase()
            if (flag === "random" || flag === "all") {
                return { files: arr.slice(0, arr.length - 1), mode: flag }
            }
        }
        return { files: arr, mode: null }
    }

    function playArraySpec(rawList, fallbackMode, delayMs, vol) {
        const parsed = parseArrayWithSuffix(rawList)
        if (parsed.files.length === 0) return

        if (parsed.mode === "random") {
            playSingleFile(parsed.files[Math.floor(Math.random() * parsed.files.length)], vol)
            return
        }
        if (parsed.mode === "all") {
            for (let i = 0; i < parsed.files.length; i++) playSingleFile(parsed.files[i], vol)
            return
        }

        const mode = fallbackMode ? String(fallbackMode).toLowerCase() : "simultaneous"
        if (mode === "sequential" || mode === "queue" || mode === "serial") {
            playSequentialList(parsed.files, delayMs, 0, vol)
        } else {
            for (let j = 0; j < parsed.files.length; j++) playSingleFile(parsed.files[j], vol)
        }
    }

    function dispatch(spec) {
        if (!spec) return
        const vol = soundVolume

        if (typeof spec === "string") {
            playSingleFile(spec, vol)
            return
        }
        if (isList(spec)) {
            playArraySpec(spec, "simultaneous", 250, vol)
            return
        }
        if (typeof spec === "object") {
            const itemVol = spec.volume !== undefined ? Number(spec.volume) : vol
            const rawList = isList(spec.files) ? spec.files : (isList(spec.sounds) ? spec.sounds : null)
            if (!rawList) return
            const mode = spec.mode ? String(spec.mode).toLowerCase() : "simultaneous"
            const delayMs = spec.delayMs !== undefined ? Number(spec.delayMs) : 250
            playArraySpec(rawList, mode, delayMs, itemVol)
        }
    }

    // Подія (підхопили, кинули, розбилась...): новий голос перебиває старий
    function play(spec) {
        if (!spec) return
        if (interruptOld) stopAll()
        dispatch(spec)
    }

    // Фонова фраза: не перебиває того, що вже лунає
    function playIfIdle(spec) {
        if (!spec || isPlaying) return
        dispatch(spec)
    }

    Component {
        id: soundProcComp
        Process {
            id: proc
            onExited: {
                audioRoot.forget(proc)
                proc.destroy()
            }
        }
    }

    Component {
        id: seqTimerComp
        Timer {
            property var filesQueue: []
            property int stepDelayMs: 250
            property int nextIdx: 0
            property real vol: 1.0
            repeat: false
            onTriggered: {
                audioRoot.playSequentialList(filesQueue, stepDelayMs, nextIdx, vol)
                destroy()
            }
        }
    }
}
