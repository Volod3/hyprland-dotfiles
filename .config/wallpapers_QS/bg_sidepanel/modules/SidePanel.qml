import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick

Scope {
    id: root

    FileView {
        id: cfgFile
        path: Quickshell.shellPath("sidepanel.json")
        blockLoading: true
        watchChanges: true
        onLoaded: root.applyCfg()                         // спрацьовує після кожного (пере)читання файлу
        onFileChanged: reload()                           // зберіг файл -> перечитати
        onLoadFailed: (error) => console.warn("[sidepanel] не вдалося прочитати " + path + ": " + error)
    }

    // Помилка в файлі більше не стирає всю панель до порожньої: лишаються попередні налаштування.
    function applyCfg() {
        const c = readCfg()
        if (c !== null) root.cfg = c
    }

    // У sidepanel.json можна писати коментарі (// та /* */) і кому після останнього елемента.
    function readCfg() {
        const txt = cfgFile.text()
        if (!txt || !txt.trim().length) {
            console.warn("[sidepanel] sidepanel.json порожній або не знайдено: " + cfgFile.path)
            return null
        }
        try {
            const parsed = JSON.parse(stripJsonc(txt))
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
                console.warn("[sidepanel] у sidepanel.json має бути об'єкт { ... }")
                return null
            }
            const c = parsed.sidepanel !== undefined ? parsed.sidepanel : parsed
            return (c !== null && typeof c === "object") ? c : null
        } catch (e) {
            console.warn("[sidepanel] помилка в sidepanel.json (перевір коми/лапки), лишаю попередні налаштування: " + (e.message || e))
            return null
        }
    }

    // JSON з коментарями та зайвими комами -> звичайний JSON (вміст "рядків" не чіпається)
    function stripJsonc(s) {
        let a = ""
        for (let i = 0; i < s.length; i++) {
            const c = s[i]
            if (c === '"') {
                let j = i + 1
                while (j < s.length && s[j] !== '"') j += (s[j] === "\\") ? 2 : 1
                a += s.slice(i, j + 1)
                i = j
            } else if (c === "/" && s[i + 1] === "/") {
                while (i + 1 < s.length && s[i + 1] !== "\n") i++
            } else if (c === "/" && s[i + 1] === "*") {
                const e = s.indexOf("*/", i + 2)
                i = e < 0 ? s.length : e + 1
            } else {
                a += c
            }
        }
        let b = ""
        for (let i = 0; i < a.length; i++) {
            const c = a[i]
            if (c === '"') {
                let j = i + 1
                while (j < a.length && a[j] !== '"') j += (a[j] === "\\") ? 2 : 1
                b += a.slice(i, j + 1)
                i = j
            } else if (c === ",") {
                let j = i + 1
                while (j < a.length && /\s/.test(a[j])) j++
                if (a[j] !== "}" && a[j] !== "]") b += c
            } else {
                b += c
            }
        }
        return b
    }

    // Команда в конфігу: рядок, або { "sh": ["рядок 1", "рядок 2", ...] } — багаторядковий скрипт
    function scriptOf(v) {
        if (v === undefined || v === null) return ""
        if (typeof v === "string") return v
        if (typeof v === "object" && v.sh !== null && typeof v.sh === "object" && typeof v.sh.length === "number")
            return Array.prototype.slice.call(v.sh).join("\n")      // працює і для JS-масивів, і для Qt-списків
        return String(v)
    }

    // шлях: "~/..." -> $HOME/..., відносний — від папки з shell.qml; повертає URL для Image
    function fileUrl(p) {
        if (p === undefined || p === null || p === "") return ""
        p = String(p)
        if (p.indexOf("://") !== -1) return p
        if (p.startsWith("~/")) p = Quickshell.env("HOME") + p.slice(1)
        if (!p.startsWith("/")) p = Quickshell.shellPath(p)
        return "file://" + p.split("/").map(encodeURIComponent).join("/")
    }

    Component.onCompleted: {
        let tiles = 0
        for (let i = 0; i < sectionSpecs.length; i++)
            if (sectionSpecs[i].type === "tiles") tiles += buildGridEntries(sectionSpecs[i]).entries.length
        console.log("[sidepanel] конфіг: " + cfgFile.path + " | name=" + (userName || "-")
            + " tiles=" + tiles + " sections=" + sectionSpecs.length)
    }

    property var cfg: readCfg() || ({})
    property bool open: false

    // ===== ПРОГРАМИ Й ОБРАНЕ =====
    // список програм — tools/apps.py (.desktop-файли з іконками), обране — favorites.json поруч з shell.qml
    property var apps: []
    property var favIds: []
    readonly property var favApps: {
        const out = []
        for (let i = 0; i < favIds.length; i++) {
            const a = apps.find(x => x.id === favIds[i])
            if (a) out.push(a)
        }
        return out
    }
    readonly property bool launcherEnabled: gopt("launcher", "enabled", true)
    readonly property int launcherW: gopt("launcher", "width", 420)

    Process {
        id: appsProc
        command: ["python3", Quickshell.shellPath("tools/apps.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const l = JSON.parse(text); if (Array.isArray(l)) root.apps = l }
                catch (e) { console.warn("[sidepanel] apps.py: " + e) }
            }
        }
    }
    FileView {
        id: favFile
        path: Quickshell.shellPath("favorites.json")
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.loadFavs()
        onFileChanged: reload()
    }
    function loadFavs() {
        try {
            const o = JSON.parse(favFile.text())
            root.favIds = (o && Array.isArray(o.apps)) ? o.apps : []
        } catch (e) { root.favIds = [] }
    }
    function toggleFav(id) {
        const l = root.favIds.slice()
        const i = l.indexOf(id)
        if (i >= 0) l.splice(i, 1); else l.push(id)
        root.favIds = l
        favFile.setText(JSON.stringify({ apps: l }, null, 2) + "\n")
    }
    function launchApp(a) {
        if (!a || !a.exec) return
        const cmd = a.terminal ? "kitty -e sh -c '" + String(a.exec).replace(/'/g, "'\\''") + "'" : String(a.exec)
        // ~/.cache/gpu-env.sh — вибір відеокарти (Win+I → Живлення → Відеокарта), пише tools/powerd
        Quickshell.execDetached(["setsid", "-f", "sh", "-c", ". \"$HOME/.cache/gpu-env.sh\" 2>/dev/null; " + cmd])
        root.open = false
    }

    function opt(k, d) { return cfg[k] !== undefined ? cfg[k] : d }
    // налаштування з групи (напр. "panel"), а якщо там нема — зі старого місця на верхньому рівні
    function gopt(g, k, d, oldKey) {
        const o = cfg[g]
        if (o && typeof o === "object" && o[k] !== undefined) return o[k]
        return opt(oldKey !== undefined ? oldKey : k, d)
    }
    function col(k, d) { const o = cfg.colors; return (o !== undefined && o[k] !== undefined) ? o[k] : d }
    function tint(c, a) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, a) }
    function cap(s) { return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s }

    function parseHmToMinutes(hm) {
        if (typeof hm !== "string") return null
        const m = hm.trim().match(/^(\d{1,2}):(\d{2})$/)
        if (!m) return null
        const hh = parseInt(m[1], 10)
        const mm = parseInt(m[2], 10)
        if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null
        return hh * 60 + mm
    }

    function inTimeRange(rangeStr, curMins) {
        if (typeof rangeStr !== "string") return false
        const parts = rangeStr.trim().split("-")
        if (parts.length !== 2) return false
        const startM = parseHmToMinutes(parts[0])
        const endM = parseHmToMinutes(parts[1])
        if (startM === null || endM === null) return false
        if (startM === endM) return false
        if (startM < endM) return curMins >= startM && curMins <= endM
        return curMins >= startM || curMins <= endM
    }

    function sectionAt(idx) {
        if (idx >= 0 && idx < root.sectionSpecs.length) return root.sectionSpecs[idx]
        return ({})
    }

    function normalizeSliderItems(secSpec) {
        const raw = (secSpec && Array.isArray(secSpec.items))
            ? secSpec.items
            : (Array.isArray(root.cfg.sliders) ? root.cfg.sliders : ["volume", "mic", "brightness"])
        // синоніми зводяться до одного типу — раніше "vol" і "volume" давали два однакові повзунки
        const alias = { vol: "volume", volume: "volume", mic: "mic", microphone: "mic",
                        bri: "brightness", brightness: "brightness", custom: "custom" }
        const out = []
        const seen = ({})
        for (let i = 0; i < raw.length; i++) {
            const item = raw[i]
            const sp = (typeof item === "string") ? ({ type: item }) : (item || ({}))
            const tp = alias[String(sp.type || sp.kind || "").trim().toLowerCase()]
            if (!tp) {
                console.warn("[sidepanel] невідомий повзунок: " + JSON.stringify(item) + " (є volume, mic, brightness, custom)")
                continue
            }
            if (tp !== "custom" && seen[tp]) continue
            seen[tp] = true
            out.push({
                type: tp,
                icon: sp.icon || "",
                max: sp.max,
                min: sp.min,
                getCmd: scriptOf(sp.getCmd),
                setCmd: scriptOf(sp.setCmd)
            })
        }
        return out
    }

    // ---------- Заготовки та сітка кнопок ----------
    function lookupPreset(key) {
        if (!key) return null
        const k = String(key)
        const pObj = root.cfg.presets
        if (pObj && typeof pObj === "object" && !Array.isArray(pObj) && pObj[k] !== undefined) {
            return pObj[k]
        }
        if (Array.isArray(pObj)) {
            for (let i = 0; i < pObj.length; i++) {
                const it = pObj[i]
                if (it && (it.id === k || it.key === k || it.name === k)) return it
            }
        }
        const tArr = root.cfg.tiles
        if (Array.isArray(tArr)) {
            for (let i = 0; i < tArr.length; i++) {
                const it = tArr[i]
                if (it && (it.id === k || it.key === k || it.title === k)) return it
            }
        }
        return null
    }

    function buildGridEntries(secSpec) {
        const gridCfg = (secSpec && secSpec.grid && typeof secSpec.grid === "object")
            ? secSpec.grid
            : ((root.cfg.grid && typeof root.cfg.grid === "object") ? root.cfg.grid : ({}))

        const cols = Math.max(1, parseInt(gridCfg.columns !== undefined ? gridCfg.columns : (gridCfg.cols !== undefined ? gridCfg.cols : 4), 10) || 4)
        const gap = gridCfg.gap !== undefined ? Number(gridCfg.gap) : 8
        const rowH = gridCfg.rowHeight !== undefined ? Number(gridCfg.rowHeight) : 72

        let rawItems = null
        if (secSpec && Array.isArray(secSpec.items)) rawItems = secSpec.items
        else if (Array.isArray(root.cfg.items)) rawItems = root.cfg.items
        else if (Array.isArray(root.cfg.tiles)) rawItems = root.cfg.tiles

        if (!Array.isArray(rawItems)) rawItems = []

        const entries = []
        let autoRow = 1
        let autoCol = 1

        for (let i = 0; i < rawItems.length; i++) {
            const raw = rawItems[i]
            const placement = (typeof raw === "string") ? ({ id: raw }) : (raw || ({}))
            const presetId = placement.id || placement.preset || placement.key || ""
            const base = lookupPreset(presetId) || ({})

            const merged = Object.assign({}, base, placement)
            const rawSpan = placement.span !== undefined ? placement.span
                : (placement.colSpan !== undefined ? placement.colSpan
                : (placement.w !== undefined ? placement.w
                : (base.span !== undefined ? base.span
                : (base.colSpan !== undefined ? base.colSpan : (base.wide === true ? 2 : 1)))))
            const span = Math.max(1, Math.min(cols, parseInt(rawSpan, 10) || 1))

            let rIdx = placement.row !== undefined ? Math.max(1, parseInt(placement.row, 10) || 1) : autoRow
            let cIdx = placement.col !== undefined ? Math.max(1, parseInt(placement.col, 10) || 1) : autoCol

            if (placement.row === undefined && placement.col === undefined) {
                if (autoCol + span - 1 > cols) {
                    autoRow += 1
                    autoCol = 1
                }
                rIdx = autoRow
                cIdx = autoCol
                autoCol += span
                if (autoCol > cols) {
                    autoRow += 1
                    autoCol = 1
                }
            } else {
                if (cIdx + span - 1 > cols) {
                    cIdx = Math.max(1, cols - span + 1)
                }
            }

            entries.push({
                id: presetId || ("tile_" + i),
                row: rIdx,
                col: cIdx,
                span: span,
                spec: merged
            })
        }

        const explicitRows = gridCfg.rows !== undefined ? Math.max(0, parseInt(gridCfg.rows, 10) || 0) : 0
        let maxRow = explicitRows
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].row > maxRow) maxRow = entries[i].row
        }

        return {
            columns: cols,
            rows: maxRow,
            gap: gap,
            rowHeight: rowH,
            entries: entries
        }
    }

    readonly property string side: {
        const raw = String(gopt("panel", "side", opt("position", "left"))).trim().toLowerCase()
        return raw === "right" ? "right" : "left"
    }
    readonly property bool isRight: side === "right"

    readonly property int panelW: gopt("panel", "width", 480)
    readonly property int pad: 14
    readonly property var theme: ({
        iconFont: gopt("fonts", "icon", "JetBrainsMono Nerd Font", "iconFont"),
        textFont: gopt("fonts", "text", "", "font"),
        bg: tint(col("background", "#100d17"), gopt("panel", "opacity", 0.9)),
        border: tint(col("border", "#ffffff"), 0.12),
        tile: tint(col("tile", "#ffffff"), 0.06),
        tileHover: tint(col("tile", "#ffffff"), 0.12),
        track: tint(col("tile", "#ffffff"), 0.12),
        accent: Qt.color(col("accent", "#cdb6ff")),
        accent2: Qt.color(col("accent2", "#f2b8d4")),
        onAccent: Qt.color(col("onAccent", "#2a1650")),
        text: Qt.color(col("text", "#ece6f6")),
        subtext: tint(col("text", "#ece6f6"), 0.62)
    })

    readonly property var sectionSpecs: {
        const raw = cfg.sections
        if (Array.isArray(raw)) {
            return raw.map((item, idx) => {
                if (typeof item === "string") return { id: item + "_" + idx, type: item }
                const copy = Object.assign({}, item || ({}))
                if (["tiles", "player", "sliders", "apps", "keyboard", "transfers"].indexOf(copy.type) < 0)
                    console.warn("[sidepanel] невідома секція: " + JSON.stringify(copy.type) + " (є tiles, apps, player, sliders, keyboard, transfers)")
                if (!copy.id) copy.id = (copy.type || "section") + "_" + idx
                return copy
            })
        }
        return [
            { id: "tiles_0", type: "tiles" },
            { id: "player_1", type: "player" },
            { id: "sliders_2", type: "sliders" }
        ]
    }

    property real volume: 0
    property bool volMuted: false
    // коли востаннє щось міняли повзунком: свіжі зміни не перезаписуються застарілим читанням
    // (раніше після відпускання повзунок міг відскочити на старе значення до наступного оновлення)
    property var lastSet: ({})
    function recentlySet(kind) { return lastSet[kind] !== undefined && Date.now() - lastSet[kind] < 700 }
    property real micVolume: 0
    property real brightness: 0
    property var infoValues: ({})
    property string infoLine: ""
    property var player: null
    property var visiblePlayers: []      // плеєри без дублів (див. computeVisiblePlayers)
    property date now: new Date()
    property string openScreenName: ""

    readonly property var infoSpecs: {
        const raw = cfg.info
        if (Array.isArray(raw)) {
            return raw.map((item, idx) => {
                if (typeof item === "string") {
                    return { id: item + "_" + idx, preset: item, label: "", prefix: "", suffix: "", cmd: "" }
                }
                item = item || ({})
                return {
                    id: item.id || ("item_" + idx),
                    preset: item.preset || item.type || "",
                    label: item.label || "",
                    prefix: item.prefix || "",
                    suffix: item.suffix || "",
                    cmd: scriptOf(item.cmd)
                }
            })
        }
        return [
            { id: "uptime", preset: "uptime", label: "", prefix: "", suffix: "", cmd: "" },
            { id: "battery", preset: "battery", label: "", prefix: "", suffix: "", cmd: "" },
            { id: "powerprofile", preset: "powerprofile", label: "", prefix: "", suffix: "", cmd: "" }
        ]
    }

    readonly property string userName: String(gopt("user", "name", Quickshell.env("USER") || "", "name"))
    // шлях з пробілами, кирилицею чи # тепер правильно перетворюється на URL
    readonly property string avatarUrl: fileUrl(gopt("user", "avatar", "~/.face", "avatar"))

    // Привітання: "greeting": { "times": [ { "from": "06:00", "to": "11:59", "text": "..." }, ... ] }
    // (старі ключі morningTime / greetMorning / ... теж розуміються)
    readonly property var greetTimes: {
        const g = cfg.greeting
        if (g && Array.isArray(g.times)) return g.times
        return [
            { range: opt("morningTime", "05:00-11:59"), text: opt("greetMorning", "Доброго ранку") },
            { range: opt("dayTime", "12:00-17:59"), text: opt("greetDay", "Добрий день") },
            { range: opt("eveningTime", "18:00-22:59"), text: opt("greetEvening", "Добрий вечір") },
            { range: opt("nightTime", "23:00-04:59"), text: opt("greetNight", "Тихої ночі") }
        ]
    }
    readonly property string greetingWord: {
        const curMins = now.getHours() * 60 + now.getMinutes()
        for (let i = 0; i < greetTimes.length; i++) {
            const t = greetTimes[i] || ({})
            const range = t.range !== undefined ? t.range : (t.from + "-" + t.to)
            if (inTimeRange(range, curMins)) return String(t.text || "")
        }
        return String(gopt("greeting", "fallback", opt("greetFallback", "Привіт")))
    }
    readonly property string greeting: {
        const tpl = String(gopt("greeting", "format", "{greeting}, {name}", "greetFormat"))
        // split/join замінює всі входження (replace міняв лише перше)
        return tpl.split("{greeting}").join(greetingWord).split("{name}").join(userName)
    }

    function pickScreen() {
        const n = openScreenName
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === n) return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    function pickPlayer(filterName) {
        const ps = Mpris.players.values
        if (filterName && String(filterName).trim().length > 0) {
            const needle = String(filterName).trim().toLowerCase()
            for (let i = 0; i < ps.length; i++) {
                const idn = (ps[i].identity || "").toLowerCase()
                const dn = (ps[i].desktopEntry || "").toLowerCase()
                if (idn.indexOf(needle) >= 0 || dn.indexOf(needle) >= 0) return ps[i]
            }
            return null
        }
        let first = null
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].playbackState === MprisPlaybackState.Playing) return ps[i]
            if (first === null) first = ps[i]
        }
        return first
    }

    function buildInfoScript() {
        const parts = []
        for (let i = 0; i < infoSpecs.length; i++) {
            const sp = infoSpecs[i]
            const key = "k" + i
            if (sp.cmd && sp.cmd.length > 0) {
                // { ...; } — щоб 2>/dev/null і head діяли на всю команду, а не лише на її останню частину
                parts.push("printf '" + key + "=%s\\n' \"$( { " + sp.cmd + "\n} 2>/dev/null | head -n1 | tr -d '\\r')\"")
                continue
            }
            switch (sp.preset) {
                case "uptime":
                    parts.push("printf '" + key + "=%s\\n' \"$(cut -d. -f1 /proc/uptime 2>/dev/null)\"")
                    break
                case "battery":
                    parts.push("printf '" + key + "=%s\\n' \"$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)\"")
                    break
                case "powerprofile":
                    parts.push("printf '" + key + "=%s\\n' \"$(powerprofilesctl get 2>/dev/null)\"")
                    break
                case "load":
                    parts.push("printf '" + key + "=%s\\n' \"$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)\"")
                    break
                case "memory":
                    parts.push("printf '" + key + "=%s\\n' \"$(awk '/MemAvailable/{a=$2} /MemTotal/{t=$2} END{if(t>0) printf \"%d\", (t-a)*100/t}' /proc/meminfo 2>/dev/null)\"")
                    break
                case "kernel":
                    parts.push("printf '" + key + "=%s\\n' \"$(uname -r 2>/dev/null)\"")
                    break
                case "date":
                    parts.push("printf '" + key + "=%s\\n' \"$(date '+%d.%m.%Y' 2>/dev/null)\"")
                    break
                case "time":
                    parts.push("printf '" + key + "=%s\\n' \"$(date '+%H:%M' 2>/dev/null)\"")
                    break
                default:
                    break
            }
        }
        return parts.join("; ")
    }

    function formatInfoEntry(sp, rawVal) {
        if (rawVal === undefined || rawVal === null) return ""
        let v = String(rawVal).trim()
        if (!v.length) return ""

        if (!sp.cmd || !sp.cmd.length) {
            if (sp.preset === "uptime") {
                const s = parseInt(v)
                if (isNaN(s)) return ""
                const d = Math.floor(s / 86400)
                v = (d > 0 ? d + "д " : "") + Math.floor((s % 86400) / 3600) + "г " + Math.floor((s % 3600) / 60) + "хв"
            } else if (sp.preset === "battery") {
                v = v.endsWith("%") ? v : v + "%"
            } else if (sp.preset === "powerprofile") {
                v = cap(v)
            } else if (sp.preset === "memory") {
                v = v.endsWith("%") ? v : v + "%"
            }
        }

        const labelPart = sp.label && sp.label.length ? sp.label + ": " : ""
        return (sp.prefix || "") + labelPart + v + (sp.suffix || "")
    }

    function recomputeInfoLine() {
        const out = []
        for (let i = 0; i < infoSpecs.length; i++) {
            const sp = infoSpecs[i]
            const txt = formatInfoEntry(sp, infoValues["k" + i])
            if (txt.length > 0) out.push(txt)
        }
        infoLine = out.join("  ·  ")
    }

    signal refreshSections()

    // ── браузерні джерела: Chrome дає трек без обкладинки («(154) … - YouTube»), а plasma-browser-integration —
    //    з обкладинкою й виконавцем. Показуємо друге, поки браузер працює (після закриття воно «висить»). ──
    function normTitle(t) {
        return String(t || "").replace(/^\(\d+\)\s*/, "").replace(/\s+[-–—]\s+(YouTube|YouTube Music|SoundCloud|Spotify)$/i, "").trim().toLowerCase()
    }
    function sameTrack(a, b) {
        const x = normTitle(a.trackTitle), y = normTitle(b.trackTitle)
        return x.length > 0 && y.length > 0 && (x === y || x.indexOf(y) !== -1 || y.indexOf(x) !== -1)
    }
    function isPlasma(p) { return !!p && (p.dbusName || "").indexOf("plasma-browser-integration") !== -1 }
    function browserAlive() {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) {
            const n = ((ps[i].dbusName || "") + " " + (ps[i].identity || "")).toLowerCase()
            if (!isPlasma(ps[i]) && /chrom|firefox|brave|vivaldi|opera|edge|zen/.test(n)) return true
        }
        return false
    }
    function artOf(p) {
        if (!p) return ""
        if (p.trackArtUrl) return p.trackArtUrl
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++)
            if (ps[i] !== p && ps[i].trackArtUrl && sameTrack(p, ps[i])) return ps[i].trackArtUrl
        for (let i = 0; i < ps.length; i++) {
            if (ps[i] !== p && !sameTrack(p, ps[i])) continue
            let u = ""
            try { u = String((ps[i].metadata || {})["xesam:url"] || "") } catch (e) {}
            const m = u.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]{11})/)
            if (m) return "https://i.ytimg.com/vi/" + m[1] + "/hqdefault.jpg"
        }
        return ""
    }
    function titleOf(p) {
        return p ? String(p.trackTitle || "").replace(/^\(\d+\)\s*/, "").replace(/\s+[-–—]\s+YouTube$/i, "") : ""
    }

    // ===== ДЕДУПЛІКАЦІЯ ДЖЕРЕЛ (як у Player.qml шпалер) =====
    // Chrome часто віддає ОДНЕ відео як ДВА MPRIS-джерела. Опції беруться з секції плеєра у sidepanel.json:
    //   "dedupe": true, "ignore": ["назва"], "hideStopped": true, "maxCards": 0 (0 = без обмеження)
    function playerOpts() {
        const specs = sectionSpecs
        for (let i = 0; i < specs.length; i++) if (specs[i].type === "player") return specs[i]
        return ({})
    }

    // "вага" джерела: з виконавцем і обкладинкою краще, ніж без них
    function playerScore(p) { return (p.trackArtist ? 2 : 0) + (p.trackArtUrl ? 1 : 0) + (isPlasma(p) ? 1 : 0) }

    function playerIgnored(p, ignore) {
        if (!p || !ignore || ignore.length === 0) return false
        const name = ((p.dbusName || "") + " " + (p.identity || "")).toLowerCase()
        for (let i = 0; i < ignore.length; i++)
            if (name.indexOf(String(ignore[i]).toLowerCase()) !== -1) return true
        return false
    }

    // Дубль: тривалість збігається (±2 с) і (збігається назва АБО однаковий момент: ±5 с і той самий стан).
    function playerIsDup(p, ps, o) {
        if (!p) return false
        const ignore = Array.isArray(o.ignore) ? o.ignore : []
        if (playerIgnored(p, ignore)) return true
        if (isPlasma(p) && !browserAlive()) return true
        let ip = -1
        for (let i = 0; i < ps.length; i++) if (ps[i] === p) ip = i
        const hideStopped = o.hideStopped !== false

        // зупинене джерело ховаємо, якщо є хоч одне активне; якщо зупинені всі — лишаємо першу НЕігноровану
        // (раніше, якщо першим стояло ігнороване джерело, зникала навіть остання картка)
        if (hideStopped && p.playbackState === MprisPlaybackState.Stopped) {
            let firstStopped = null
            for (let i = 0; i < ps.length; i++) {
                const q = ps[i]
                if (playerIgnored(q, ignore)) continue
                if (q.playbackState !== MprisPlaybackState.Stopped) return true
                if (firstStopped === null) firstStopped = q
            }
            return firstStopped !== p
        }

        if (o.dedupe === false) return false
        for (let i = 0; i < ps.length; i++) {
            const q = ps[i]
            if (q === p || playerIgnored(q, ignore)) continue
            if (hideStopped && q.playbackState === MprisPlaybackState.Stopped) continue   // воно й так сховане
            const lp = p.length || 0
            const lq = q.length || 0
            if (lp <= 0 || lq <= 0 || Math.abs(lp - lq) > 2) continue
            const sameTitle = sameTrack(p, q)
            const sameMoment = p.isPlaying === q.isPlaying && Math.abs(p.position - q.position) <= 5
            if (!sameTitle && !sameMoment) continue
            if (playerScore(q) > playerScore(p) || (playerScore(q) === playerScore(p) && i < ip)) return true
        }
        return false
    }

    function computeVisiblePlayers() {
        const ps = Mpris.players.values
        const o = playerOpts()
        const out = []
        for (let i = 0; i < ps.length; i++)
            if (!playerIsDup(ps[i], ps, o)) out.push(ps[i])
        return (o.maxCards > 0) ? out.slice(0, o.maxCards) : out
    }

    function refreshAll() {
        now = new Date()
        player = pickPlayer()
        visiblePlayers = computeVisiblePlayers()
        if (!volProc.running) volProc.running = true
        if (!micProc.running) micProc.running = true
        if (!briProc.running) briProc.running = true
        const script = buildInfoScript()
        if (script.length > 0 && !infoProc.running) {
            infoProc.command = ["sh", "-c", script]
            infoProc.running = true
        } else if (!script.length) {
            infoValues = ({})
            infoLine = ""
        }
        root.refreshSections()
    }

    // фокус-граб вмикається, коли обидва вікна (панель і пошук) уже показані,
    // інакше Hyprland одразу «скидає» його і панель закривається
    Timer {
        id: afterOpen
        interval: 340
        onTriggered: {
            if (!root.open) return
            root.refreshAll()
            if (!appsProc.running) appsProc.running = true
        }
    }
    property bool grabReady: false
    Timer { id: grabDelay; interval: 200; onTriggered: root.grabReady = root.open }

    onOpenChanged: {
        grabReady = false
        if (open) grabDelay.restart()
        if (open) {
            const m = Hyprland.focusedMonitor
            openScreenName = m ? m.name : ""
            flick.contentY = 0
            // важкі оновлення (процеси для плиток, гучність, список програм) — після анімації виїзду,
            // щоб вона йшла плавно, без ривків
            afterOpen.restart()
            if (root.launcherEnabled) appSearch.reset()
            else content.forceActiveFocus()
        }
    }

    IpcHandler {
        target: "sidepanel"
        function toggle(): void { root.open = !root.open }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
    }

    Timer {
        interval: 2500
        repeat: true
        running: root.open
        onTriggered: root.refreshAll()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.open && root.visiblePlayers.length > 0
        onTriggered: {
            const ps = Mpris.players.values
            for (let i = 0; i < ps.length; i++) {
                if (ps[i] && ps[i].playbackState === MprisPlaybackState.Playing) {
                    ps[i].positionChanged()
                }
            }
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.player = root.pickPlayer()
            root.visiblePlayers = root.computeVisiblePlayers()
            root.refreshSections()
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim().length) return             // wpctl не відповів — не скидаємо в 0
                root.volMuted = text.indexOf("MUTED") >= 0
                if (root.recentlySet("vol")) return
                const m = text.match(/([0-9]*\.?[0-9]+)/)
                if (m) root.volume = parseFloat(m[1])
            }
        }
    }
    Process {
        id: micProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.recentlySet("mic")) return
                const m = text.match(/([0-9]*\.?[0-9]+)/)
                if (m) root.micVolume = parseFloat(m[1])
            }
        }
    }
    Process {
        id: briProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.recentlySet("bri")) return
                const f = text.trim().split(",")
                const pct = f.length >= 4 ? parseInt(f[3]) : NaN
                if (isFinite(pct)) root.brightness = pct / 100
            }
        }
    }
    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                const nextVals = ({})
                for (let i = 0; i < lines.length; i++) {
                    const l = lines[i]
                    const eq = l.indexOf("=")
                    if (eq > 0) nextVals[l.slice(0, eq)] = l.slice(eq + 1)
                }
                root.infoValues = nextVals
                root.recomputeInfoLine()
            }
        }
    }

    property var pending: ({})
    function queueSet(kind, v) {
        const p = pending
        p[kind] = v
        pending = p
        const ls = lastSet
        ls[kind] = Date.now()
        lastSet = ls
        if (!sendTimer.running) sendTimer.start()
    }
    Timer {
        id: sendTimer
        interval: 70
        onTriggered: {
            const p = root.pending
            root.pending = ({})
            const ls = root.lastSet
            for (const k in p) ls[k] = Date.now()     // відлік «свіжості» — від реальної відправки
            if (p.vol !== undefined) {
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", p.vol.toFixed(2)])
                volSfx.restart()
            }
            if (p.mic !== undefined)
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", p.mic.toFixed(2)])
            if (p.bri !== undefined)
                Quickshell.execDetached(["brightnessctl", "-n2", "set", Math.round(p.bri * 100) + "%"])
        }
    }

    Timer {      // «тук» на новій гучності, коли повзунок зупинився (як у KDE)
        id: volSfx
        interval: 260
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/sfx", "volume"])
    }

    HyprlandFocusGrab {
        windows: [win, appsWin]
        active: root.open && root.grabReady
        onCleared: root.open = false
    }

    PanelWindow {
        id: appsWin

        screen: root.pickScreen()
        visible: root.launcherEnabled && win.visible
        color: "transparent"
        anchors { top: true; left: !root.isRight; right: root.isRight }
        margins {
            top: root.gopt("panel", "marginTop", 56, "top")
            left: root.isRight ? 0 : root.panelW + 22
            right: root.isRight ? root.panelW + 22 : 0
        }
        implicitWidth: root.launcherW
        implicitHeight: Math.min(640, (win.screen ? win.screen.height : 1080) - root.gopt("panel", "marginTop", 56, "top") - 40)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sidepanel-apps"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        AppSearch {
            id: appSearch
            width: parent.width
            height: parent.height
            theme: root.theme
            apps: root.apps
            favIds: root.favIds
            onLaunch: (a) => root.launchApp(a)
            onToggleFav: (id) => root.toggleFav(id)
            onCloseRequested: root.open = false
            // виїжджає разом з панеллю, трохи із затримкою
            opacity: root.open ? 1 : 0
            layer.enabled: searchSlide.running
            layer.smooth: true
            transform: Translate { x: root.open ? 0 : (root.isRight ? 50 : -50) ; Behavior on x { NumberAnimation { id: searchSlide; duration: 420; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    PanelWindow {
        id: win

        screen: root.pickScreen()
        visible: root.open || (root.isRight ? content.x < content.closedX - 1 : content.x > content.closedX + 1)
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: !root.isRight
            right: root.isRight
        }
        margins {
            top: root.gopt("panel", "marginTop", 56, "top")
            bottom: root.gopt("panel", "marginBottom", 10, "bottom")
            left: 0
            right: 0
        }
        implicitWidth: root.panelW + 10
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sidepanel"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Item {
            id: content
            width: win.width
            height: win.height
            readonly property real closedX: root.isRight ? (width + 30) : -(width + 30)
            x: root.open ? 0 : closedX
            opacity: root.open ? 1 : 0
            focus: true
            // під час руху панель малюється як готова текстура — рух рівний на будь-якій частоті екрана
            layer.enabled: xAnim.running
            layer.smooth: true

            Behavior on x { NumberAnimation { id: xAnim; duration: root.gopt("panel", "slideMs", 380); easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Keys.onEscapePressed: root.open = false

            Rectangle {
                id: body
                x: root.isRight ? 0 : 10
                width: root.panelW
                height: parent.height
                radius: 28
                color: root.theme.bg
                border.width: 1
                border.color: root.theme.border
                clip: true

                // ледь помітний рожевий відтінок унизу + рожевий відблиск угорі
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.55; color: "transparent" }
                        GradientStop { position: 1.0; color: root.tint(root.theme.accent2, 0.16) }
                    }
                }
                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.tint(root.theme.accent2, 0.7) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: root.pad
                    contentWidth: width
                    contentHeight: column.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: column
                        width: flick.width
                        spacing: 10

                        Item {
                            width: column.width
                            height: 58

                            RoundImage {
                                id: avatar
                                width: 52; height: 52
                                radius: 26
                                maxSide: 256
                                animated: root.gopt("user", "avatarAnimated", true, "avatarAnimated")   // false — показувати лише перший кадр GIF
                                playing: root.open                           // закрита панель = пауза
                                anchors.verticalCenter: parent.verticalCenter
                                source: root.avatarUrl
                                visible: status === Image.Ready
                            }
                            Rectangle {
                                visible: !avatar.visible
                                width: 52; height: 52
                                radius: 26
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: root.userName.length ? root.userName.charAt(0).toUpperCase() : "?"
                                    font.family: root.theme.textFont
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: root.theme.onAccent
                                }
                            }

                            Column {
                                x: 66
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 66 - actionsRow.width - 8
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: root.greeting
                                    elide: Text.ElideRight
                                    font.family: root.theme.textFont
                                    font.pixelSize: 17
                                    font.bold: true
                                    color: root.theme.text
                                }
                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    elide: Text.ElideRight
                                    text: root.infoLine
                                    font.family: root.theme.textFont
                                    font.pixelSize: 12
                                    color: root.theme.subtext
                                }
                            }

                            Row {
                                id: actionsRow
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Repeater {
                                    model: Array.isArray(root.cfg.actions) ? root.cfg.actions : []
                                    SideIconBtn {
                                        required property var modelData
                                        theme: root.theme
                                        icon: modelData.icon || ""
                                        onClicked: {
                                            const cmd = root.scriptOf(modelData.cmd)
                                            if (cmd.length) Quickshell.execDetached(["sh", "-c", cmd])
                                            if (modelData.close !== false) root.open = false
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            id: sectionsRepeater
                            model: root.sectionSpecs

                            Item {
                                id: secHost
                                required property int index
                                required property var modelData
                                width: column.width
                                readonly property bool secEnabled: modelData.enabled !== false
                                // розділ може сам сховатись (висота 0): немає підсвітки / нічого не копіюється
                                visible: secEnabled && innerLoader.active && (!innerLoader.item || innerLoader.item.height > 0)
                                height: visible ? innerLoader.height : 0

                                Loader {
                                    id: innerLoader
                                    width: parent.width
                                    active: secHost.secEnabled
                                    sourceComponent: {
                                        if (secHost.modelData.type === "tiles") return tilesComp
                                        if (secHost.modelData.type === "player") return playerComp
                                        if (secHost.modelData.type === "sliders") return slidersComp
                                        if (secHost.modelData.type === "apps") return appsComp
                                        if (secHost.modelData.type === "keyboard") return keyboardComp
                                        if (secHost.modelData.type === "transfers") return transfersComp
                                        return null
                                    }
                                    onLoaded: {
                                        if (item) item.secIndex = secHost.index
                                    }
                                }
                            }
                        }

                        // ----- Копіювання на флешки: прогрес запису (видно лише під час запису) -----
                        Component {
                            id: transfersComp
                            Rectangle {
                                id: trBox
                                property int secIndex: -1
                                property var drives: []
                                readonly property var active: drives.filter(d => d.busy || (d.eject && (d.eject.stage === "sync" || d.eject.stage === "unmount")))
                                width: parent ? parent.width : column.width
                                height: active.length ? trCol.implicitHeight + 24 : 0
                                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                clip: true
                                radius: 20
                                color: root.theme.tile
                                border.width: active.length ? 1 : 0
                                border.color: root.theme.border
                                function human(n) { n = Number(n || 0); const u = ["Б", "КБ", "МБ", "ГБ"]; let i = 0; while (n >= 1024 && i < 3) { n /= 1024; i++ } return (i < 2 || n >= 100 ? n.toFixed(0) : n.toFixed(1)) + " " + u[i] }
                                Process {
                                    id: trP
                                    command: [Quickshell.env("HOME") + "/.config/wallpapers_QS/tools/devices", "list"]
                                    stdout: StdioCollector { onStreamFinished: { try { trBox.drives = JSON.parse(text).drives || [] } catch (e) {} } }
                                }
                                Timer { interval: 1000; repeat: true; running: root.open; triggeredOnStart: true; onTriggered: if (!trP.running) trP.running = true }
                                Column {
                                    id: trCol
                                    x: 14; y: 12; width: parent.width - 28
                                    spacing: 8
                                    Repeater {
                                        model: trBox.active
                                        Column {
                                            required property var modelData
                                            readonly property var d: modelData
                                            readonly property var ej: d.eject || ({})
                                            readonly property bool ejecting: ej.stage === "sync" || ej.stage === "unmount"
                                            width: trCol.width; spacing: 6
                                            Text {
                                                width: parent.width; elide: Text.ElideRight
                                                text: (ejecting ? "Дописую на «" : "Запис на «") + d.label + "»" + (d.write > 1024 ? "  ·  " + trBox.human(d.write) + "/с" : "")
                                                color: root.theme.text; font.pixelSize: 13; font.family: root.theme.textFont
                                            }
                                            Rectangle {
                                                width: parent.width; height: 6; radius: 3; clip: true
                                                color: root.theme.track
                                                Rectangle {
                                                    readonly property bool known: parent.parent.ejecting
                                                    height: parent.height; radius: 3
                                                    width: known ? parent.width * Math.max(0.04, (parent.parent.ej.pct || 0) / 100) : parent.width * 0.3
                                                    color: root.theme.accent
                                                    SequentialAnimation on x { running: !parent.known; loops: Animation.Infinite
                                                        NumberAnimation { from: -80; to: 420; duration: 1300; easing.type: Easing.InOutSine } }
                                                }
                                            }
                                            Text {
                                                text: ejecting ? ("після запису диск від'єднається сам · " + (ej.pct || 0) + "%") : ("ще не записано: " + trBox.human(d.pending))
                                                color: root.theme.subtext; font.pixelSize: 11; font.family: root.theme.textFont
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ----- Підсвітка клавіатури — спільний компонент ../../shared/KbdLight.qml (той самий, що в «Налаштуваннях») -----
                        Component {
                            id: keyboardComp
                            Rectangle {
                                id: kbBox
                                property int secIndex: -1
                                width: parent ? parent.width : column.width
                                height: kbl.present ? kbl.height + 28 : 0
                                radius: 20
                                color: root.theme.tile
                                border.width: kbl.present ? 1 : 0
                                border.color: root.theme.border
                                clip: true
                                KbdLight {
                                    id: kbl
                                    x: 14; y: 14; width: parent.width - 28
                                    cAccent: root.theme.accent; cText: root.theme.text; cSub: root.theme.subtext
                                    cTrack: root.theme.track; cHover: root.theme.tileHover; cOnAccent: root.theme.onAccent
                                    font: root.theme.textFont; iconFont: root.theme.iconFont
                                }
                                Connections { target: root; function onRefreshSections() { kbl.refresh() } }
                            }
                        }

                        // ----- Сітка кнопок за координатами row / col / span -----
                        Component {
                            id: tilesComp
                            Item {
                                id: tilesGridBox
                                property int secIndex: -1
                                width: parent ? parent.width : column.width

                                readonly property var secCfg: root.sectionAt(secIndex)
                                readonly property var layoutData: root.buildGridEntries(secCfg)
                                readonly property int cols: layoutData.columns
                                readonly property real gap: layoutData.gap
                                readonly property real rowH: layoutData.rowHeight
                                readonly property real colW: (width - (cols - 1) * gap) / cols

                                height: layoutData.rows > 0
                                    ? (layoutData.rows * rowH + Math.max(0, layoutData.rows - 1) * gap)
                                    : 0
                                visible: height > 0

                                Connections {
                                    target: root
                                    function onRefreshSections() {
                                        for (let i = 0; i < gridTiles.count; i++) {
                                            const t = gridTiles.itemAt(i)
                                            if (t) t.refresh()
                                        }
                                    }
                                }

                                Repeater {
                                    id: gridTiles
                                    model: tilesGridBox.layoutData.entries

                                    SideTile {
                                        required property int index
                                        required property var modelData

                                        readonly property int r1: Math.max(1, modelData.row || 1)
                                        readonly property int c1: Math.max(1, modelData.col || 1)
                                        readonly property int sp: Math.max(1, modelData.span || 1)

                                        x: (c1 - 1) * (tilesGridBox.colW + tilesGridBox.gap)
                                        y: (r1 - 1) * (tilesGridBox.rowH + tilesGridBox.gap)
                                        width: Math.max(1, sp * tilesGridBox.colW + (sp - 1) * tilesGridBox.gap)
                                        height: tilesGridBox.rowH

                                        spec: modelData.spec
                                        theme: root.theme
                                        onCloseRequested: root.open = false
                                    }
                                }
                            }
                        }

                        Component {
                            id: appsComp
                            FavGrid {
                                property int secIndex: -1
                                width: parent ? parent.width : column.width
                                theme: root.theme
                                apps: root.favApps
                                columns: root.sectionAt(secIndex).columns || 4
                                onLaunch: (a) => root.launchApp(a)
                                onRemove: (id) => root.toggleFav(id)
                            }
                        }

                        Component {
                            id: playerComp
                            Item {
                                id: playerSec
                                property int secIndex: -1
                                width: parent ? parent.width : column.width
                                readonly property var secCfg: root.sectionAt(secIndex)
                                readonly property string playerFilter: secCfg.player || ""
                                readonly property bool hideWhenIdle: secCfg.hideWhenIdle === true
                                // джерела для карток: один плеєр за фільтром, або всі без дублів (див. playerIsDup)
                                readonly property var list: {
                                    if (playerFilter.length > 0) {
                                        const one = root.pickPlayer(playerFilter)
                                        return one !== null ? [one] : []
                                    }
                                    return root.visiblePlayers
                                }

                                visible: !hideWhenIdle || list.length > 0
                                height: visible ? stack.height : 0

                                Column {
                                    id: stack
                                    width: parent.width
                                    spacing: 10

                                    Rectangle {
                                        id: emptyCard
                                        visible: playerSec.list.length === 0
                                        width: parent.width
                                        height: 64
                                        radius: 24
                                        color: root.theme.tile
                                        border.width: 1
                                        border.color: root.theme.border
                                        Text {
                                            anchors.centerIn: parent
                                            text: playerSec.secCfg.emptyText || "♪  Нічого не грає"
                                            font.family: root.theme.textFont
                                            font.pixelSize: 14
                                            color: root.theme.subtext
                                        }
                                    }

                                    Repeater {
                                        model: playerSec.list
                                        PlayerCard {
                                            required property var modelData
                                            width: stack.width
                                            player: modelData
                                            theme: root.theme
                                            active: root.open
                                            showVolume: playerSec.secCfg.volume === true
                                            // обкладинка/назва — з будь-якого джерела цього треку (див. artOf)
                                            artUrl: { root.visiblePlayers; return root.artOf(modelData) }
                                            title: root.titleOf(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: slidersComp
                            Rectangle {
                                id: sliderBox
                                property int secIndex: -1
                                width: parent ? parent.width : column.width
                                height: slidersCol.implicitHeight + 28
                                radius: 24
                                color: root.theme.tile
                                border.width: 1
                                border.color: root.theme.border

                                readonly property var secCfg: root.sectionAt(secIndex)
                                readonly property var currentItems: root.normalizeSliderItems(secCfg)

                                Column {
                                    id: slidersCol
                                    x: 14
                                    y: 14
                                    width: parent.width - 28
                                    spacing: 10

                                    Repeater {
                                        model: sliderBox.currentItems

                                        Item {
                                            id: slRow
                                            required property int index
                                            required property var modelData
                                            width: slidersCol.width
                                            readonly property string t: String(modelData.type || "").toLowerCase()
                                            readonly property bool validType: t === "volume" || t === "mic" || t === "brightness" || t === "custom"

                                            visible: validType
                                            height: !validType ? 0 : (t === "custom" ? cInner.height : 38)

                                            SideSlider {
                                                visible: slRow.t === "volume"
                                                width: parent.width
                                                theme: root.theme
                                                icon: slRow.modelData.icon || (root.volMuted ? "\uf026" : "\uf028")
                                                maxValue: slRow.modelData.max !== undefined ? Number(slRow.modelData.max) : 1.5
                                                value: root.volume
                                                onMoved: (v) => { root.volume = v; root.queueSet("vol", v) }
                                            }

                                            SideSlider {
                                                visible: slRow.t === "mic"
                                                width: parent.width
                                                theme: root.theme
                                                icon: slRow.modelData.icon || "\uf130"
                                                maxValue: slRow.modelData.max !== undefined ? Number(slRow.modelData.max) : 1.0
                                                value: root.micVolume
                                                onMoved: (v) => { root.micVolume = v; root.queueSet("mic", v) }
                                            }

                                            SideSlider {
                                                visible: slRow.t === "brightness"
                                                width: parent.width
                                                theme: root.theme
                                                icon: slRow.modelData.icon || "\uf185"
                                                maxValue: slRow.modelData.max !== undefined ? Number(slRow.modelData.max) : 1.0
                                                value: root.brightness
                                                onMoved: (v) => { root.brightness = v; root.queueSet("bri", v) }
                                            }

                                            Item {
                                                id: cWrap
                                                visible: slRow.t === "custom"
                                                width: parent.width
                                                height: cInner.height

                                                readonly property real minV: slRow.modelData.min !== undefined ? Number(slRow.modelData.min) : 0
                                                readonly property real maxV: slRow.modelData.max !== undefined ? Number(slRow.modelData.max) : 1.0
                                                property real curVal: minV
                                                property real setAt: 0          // коли востаннє тягнули (свіже значення не перезаписуємо)
                                                property real pendingVal: NaN

                                                function reloadVal() {
                                                    if (slRow.t !== "custom" || !slRow.modelData.getCmd || getP.running) return
                                                    if (Date.now() - setAt < 700) return
                                                    getP.command = ["sh", "-c", String(slRow.modelData.getCmd)]
                                                    getP.running = true
                                                }

                                                Connections {
                                                    target: root
                                                    function onRefreshSections() { cWrap.reloadVal() }
                                                }
                                                Component.onCompleted: cWrap.reloadVal()

                                                Process {
                                                    id: getP
                                                    stdout: StdioCollector {
                                                        onStreamFinished: {
                                                            if (Date.now() - cWrap.setAt < 700) return
                                                            const m = text.trim().match(/-?[0-9]*\.?[0-9]+/)
                                                            if (m) cWrap.curVal = parseFloat(m[0])
                                                        }
                                                    }
                                                }

                                                // команда відправляється не частіше ніж раз на 70 мс (раніше — на кожен рух миші)
                                                Timer {
                                                    id: cSend
                                                    interval: 70
                                                    onTriggered: {
                                                        const v = cWrap.pendingVal
                                                        if (isNaN(v) || !slRow.modelData.setCmd) return
                                                        cWrap.pendingVal = NaN
                                                        cWrap.setAt = Date.now()
                                                        const pct = cWrap.maxV > cWrap.minV ? (v - cWrap.minV) / (cWrap.maxV - cWrap.minV) : 0
                                                        const cmdStr = String(slRow.modelData.setCmd)
                                                            .replace(/\{value\}/g, String(Math.round(v * 1000) / 1000))
                                                            .replace(/\{pct\}/g, String(Math.round(pct * 100)))
                                                        Quickshell.execDetached(["sh", "-c", cmdStr])
                                                    }
                                                }

                                                SideSlider {
                                                    id: cInner
                                                    width: parent.width
                                                    theme: root.theme
                                                    icon: slRow.modelData.icon || "\uf0e4"
                                                    minValue: cWrap.minV
                                                    maxValue: cWrap.maxV
                                                    percentOfRange: true
                                                    value: cWrap.curVal
                                                    onMoved: (v) => {
                                                        cWrap.curVal = v
                                                        cWrap.setAt = Date.now()
                                                        cWrap.pendingVal = v
                                                        if (!cSend.running) cSend.start()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
