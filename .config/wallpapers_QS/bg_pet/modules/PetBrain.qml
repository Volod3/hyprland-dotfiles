import QtQuick
import Quickshell
import Quickshell.Io

// ===== МОЗОК ПЕТА: локальна LLM через Ollama =====
// Усе налаштування — pet.json -> "brain". Якщо "enabled": false — мозку просто нема:
// ні чату, ні журналу подій, ні вільної волі, ні скрінів, ні файлу історії
// (пет поводиться рівно як до появи мозку).
//
// Промпти — англійською (дрібні моделі англійську розуміють найкраще);
// відповідає вона тією мовою, якою пишеш їй ти.
//
//   sudo pacman -S ollama-cuda && sudo systemctl enable --now ollama
//   ollama pull ifm/k2-horizon:0.9b
Item {
    id: brain

    property var cfg: ({})

    function obj(v) { return (v && typeof v === "object" && typeof v.length !== "number") ? v : ({}) }
    function isList(v) { return v !== null && typeof v === "object" && typeof v.length === "number" }

    readonly property var bc: obj(cfg ? cfg.brain : null)
    readonly property bool enabled: bc.enabled === true                     // ГОЛОВНИЙ вимикач усього нижче
    readonly property string url: String(bc.url || "http://127.0.0.1:11434").replace(/\/+$/, "")
    readonly property string model: String(bc.model || "ifm/k2-horizon:0.9b")
    readonly property string petName: (cfg && cfg.name) ? String(cfg.name) : "Mimi"
    readonly property int maxTokens: bc.maxTokens !== undefined ? Number(bc.maxTokens) : 120
    readonly property real temperature: bc.temperature !== undefined ? Number(bc.temperature) : 0.8
    readonly property int historyTurns: bc.history !== undefined ? Number(bc.history) : 6
    readonly property bool think: bc.think === true
    // brain.tools: true — скрін і програми через tool calling Ollama (надійніше за теги);
    // якщо модель tools не вміє — сама перемкнеться на теги
    readonly property bool toolsWanted: bc.tools !== false
    property bool toolsBroken: false
    // brain.toolSteps — скільки разів поспіль вона може викликати інструменти за одну відповідь (як engineLoop)
    readonly property int toolSteps: bc.toolSteps !== undefined ? Math.max(1, Number(bc.toolSteps)) : 5
    // PetWindow підставляє перевірку «чи можна зараз це зробити» (лежить, спить тощо)
    property var canDo: null
    readonly property var toolActions: actionsInChat ? chatTagActions.filter(a => a !== "look") : []
    readonly property bool useTools: toolsWanted && !toolsBroken
                                     && (lookTool || commandNames.length > 0 || toolActions.length > 0)
    readonly property int timeoutMs: bc.timeoutMs !== undefined ? Number(bc.timeoutMs) : 90000
    readonly property var keepAlive: bc.keepAlive !== undefined ? bc.keepAlive : "10m"
    // що сказати, якщо відповідь вийшла порожня (напр. був лише тег [run:htop]):
    // "emptyReply": "…meow?"  або  ["…meow?", "Nya!", "Done~"] — тоді випадкова
    readonly property var emptyReplies: {
        const v = bc.emptyReply
        const list = isList(v) ? Array.prototype.slice.call(v).map(String) : (typeof v === "string" ? [v] : ["…meow?"])
        return list.map(s => s.trim()).filter(s => s.length)
    }
    function emptyReply() {
        const l = emptyReplies
        return l.length ? l[Math.floor(Math.random() * l.length)] : ""
    }

    // ── історія й події ──
    readonly property string historyFile: bc.historyFile !== undefined ? String(bc.historyFile) : "chat_history.json"
    readonly property int historyKeep: bc.historyKeep !== undefined ? Number(bc.historyKeep) : 500
    readonly property bool logEvents: enabled && bc.logEvents === true
    readonly property bool eventsInContext: bc.eventsInContext !== false
    readonly property int eventsContext: bc.eventsContext !== undefined ? Number(bc.eventsContext) : 5
    readonly property string historyPath: {
        const f = historyFile.trim()
        if (!enabled || !f.length) return ""
        if (f.startsWith("/")) return f
        if (f.startsWith("~/")) return Quickshell.env("HOME") + f.slice(1)
        return Quickshell.shellPath(f.replace(/^\.\//, ""))
    }

    // ── програми, які їй дозволено запускати: brain.commands ──
    //   "htop": ["kitty", "-e", "htop"]                     — масив = програма + аргументи
    //   "browser": "xdg-open https://duckduckgo.com"        — рядок = shell-команда
    //   "files": { "cmd": "dolphin", "desc": "file manager" } — з описом для моделі
    readonly property var commands: {
        const src = obj(bc.commands)
        const out = ({})
        for (const k in src) {
            const v = src[k]
            const name = String(k).trim().toLowerCase()
            if (!name.length || !/^[a-z0-9_-]+$/.test(name)) continue
            if (typeof v === "string" || isList(v)) out[name] = { cmd: v, desc: "", aliases: [] }
            else if (v && typeof v === "object" && v.cmd !== undefined)
                out[name] = { cmd: v.cmd, desc: String(v.desc || ""),
                              aliases: isList(v.aliases) ? Array.prototype.slice.call(v.aliases).map(x => String(x).toLowerCase()) : [] }
        }
        return out
    }
    readonly property var commandNames: Object.keys(commands)

    // brain.terminal: false — вимкнути термінал і статус системи (за замовчуванням увімкнено)
    readonly property bool terminalTool: bc.terminal !== false
    // інтернет: пошук і читання сторінок (tools/pet-web). Вимкнути — "web": false у brain в pet.json
    readonly property bool webTool: bc.web !== false
    readonly property string toolsDir: Quickshell.env("HOME") + "/.config/wallpapers_QS/tools"

    // «відкрий хром», а модель лише відповіла текстом — знайти програму самим (за назвою чи синонімом)
    function guessCommand(q) {
        const t = String(q || "").toLowerCase()
        if (!/(відкр|запуст|увімкн|включ|покаж|зроби|постав|open|launch|start|run|turn)/.test(t)) return ""
        for (let i = 0; i < commandNames.length; i++) {
            const n = commandNames[i]
            const words = [n.replace(/_/g, " ")].concat(commands[n].aliases || [])
            for (let j = 0; j < words.length; j++)
                if (words[j].length > 2 && t.indexOf(words[j]) >= 0) return n
        }
        return ""
    }

    // асинхронні інструменти (статус системи, термінал): один процес за раз
    property var shellCb: null
    Process {
        id: shellProc
        stdout: StdioCollector {
            onStreamFinished: {
                const cb = brain.shellCb
                brain.shellCb = null
                if (cb) cb(text.trim())
            }
        }
    }
    function runShell(argv, cb) {
        if (shellProc.running) { cb("Error: busy"); return }
        shellCb = cb
        shellProc.command = argv
        shellProc.running = true
    }
    function sysSummary(t) {
        let j
        try { j = JSON.parse(t) } catch (e) { return t.slice(0, 600) }
        const p = []
        if (j.ram) p.push("RAM used " + j.ram.used + " of " + j.ram.total + " GB")
        p.push("CPU load " + j.cpu + "%", "CPU temperature " + j.temp + "°C")
        if (j.gpu) p.push("GPU " + j.gpu.name + " " + j.gpu.util + "% load, " + j.gpu.temp + "°C, VRAM " + j.gpu.memUsed + "/" + j.gpu.memTotal + " MB")
        if (j.battery) p.push("battery " + j.battery.pct + "% (" + j.battery.status + (j.battery.eta ? ", " + j.battery.eta + " left" : "") + "), battery health " + j.battery.health + "%")
        if (j.disk) p.push("disk / used " + j.disk.used + " of " + j.disk.total + " GB")
        p.push("power profile " + j.profile, "uptime " + j.uptime)
        if (j.procs && j.procs.length) p.push("top processes: " + j.procs.slice(0, 5).map(x => x.name + " " + x.cpu + "% CPU " + x.mem + " MB").join(", "))
        return p.join("; ")
    }

    // ── скріншот: brain.look ──
    readonly property var lookCfg: obj(bc.look)
    readonly property bool lookEnabled: enabled && lookCfg.enabled === true
    readonly property real lookScale: lookCfg.scale !== undefined ? Number(lookCfg.scale) : 0.5
    readonly property int lookQuality: lookCfg.quality !== undefined ? Number(lookCfg.quality) : 70
    readonly property var lookOnEvents: isList(lookCfg.onEvents) ? Array.prototype.slice.call(lookCfg.onEvents).map(String) : []
    // look.inChat: true — до кожного твого повідомлення в чаті одразу чіпляється свіжий скрін
    readonly property bool lookInChat: lookEnabled && lookCfg.inChat !== false
    // окремий «глянь» (тег/інструмент) потрібен лише коли скрін не йде з кожним повідомленням
    readonly property bool lookTool: lookEnabled && !lookInChat
    readonly property int lookCooldownMs: lookCfg.cooldownMs !== undefined ? Number(lookCfg.cooldownMs) : 120000
    property real lastLook: 0

    // ── вільна воля: brain.autonomy ──
    readonly property var autoCfg: obj(bc.autonomy)
    readonly property bool autoEnabled: enabled && autoCfg.enabled === true
    readonly property var allowedActions: {
        const a = autoCfg.actions
        const list = isList(a) ? Array.prototype.slice.call(a).map(String)
                               : ["dance", "sleep", "wake", "hop", "flip", "travel", "look", "say", "nothing"]
        return list.map(s => s.trim().toLowerCase()).filter(s => s.length)
    }
    readonly property bool actionsInChat: autoEnabled && autoCfg.inChat !== false
    // опис дій для моделі (англійською)
    readonly property var actionDesc: ({
        dance: "dance", sleep: "take a nap", wake: "wake up", hop: "jump", flip: "do a backflip",
        travel: "run to another workspace", look: "look at the user's screen", say: "just say something",
        nothing: "do nothing", poke: "be happy", shatter: "shatter into pieces", hide: "hide"
    })
    // що вона каже, коли робить дію, а слів у відповіді нема (замість «…meow?»)
    function actionLine(action, arg) {
        const a = String(action || "").toLowerCase()
        if (a === "run") return "Opening " + arg + " for you! 🐾"
        const lines = {
            dance: "Dance time! 💃", sleep: "Nap time… 💤", wake: "I'm awake, nya!", hop: "Hop! 🐾",
            flip: "Backflip! ✨", travel: "Off to another desktop!", look: "Let me peek at your screen 👀",
            poke: "Yay! 💗", hide: "Bye-bye!", shatter: "Goodbye, cruel world…"
        }
        return lines[a] || ""
    }

    // назви дій для журналу (українською)
    readonly property var actionNamesUk: ({
        dance: "потанцювати", sleep: "поспати", wake: "прокинутись", hop: "підстрибнути", flip: "зробити сальто",
        travel: "побігти на інший робочий стіл", look: "подивитись на екран", say: "щось сказати",
        nothing: "нічого не робити", poke: "порадіти", shatter: "розбитися на шматочки", hide: "сховатися", run: "запустити"
    })

    // ── промпти ──
    readonly property string basePrompt: bc.system !== undefined && String(bc.system).trim().length
        ? String(bc.system).split("{name}").join(petName)
        : ("You are " + petName + ", a tiny cat girl who lives on a Linux (Hyprland) desktop and runs around on top of windows. "
           + "Keep every reply very short: one or two sentences, under 25 words. "
           + "You are playful and cute and sometimes say \"nya\" or \"meow\". No lists, headings or markdown. "
           + "Always reply in the same language the user writes to you in.")

    // теги, якими вона в розмові може щось зробити
    readonly property var chatTagActions: allowedActions.filter(a => a !== "say" && a !== "nothing" && (a !== "look" || lookTool))
    readonly property string tagsPrompt: {
        let p = ""
        if (lookInChat)
            p += " The user's messages come with a screenshot of their screen taken at that moment, so you CAN see it. "
                 + "Use it when the user asks about the screen or when it is relevant; otherwise just chat."
        if (!useTools && actionsInChat && chatTagActions.length)
            p += " If YOU want to do something, add ONE tag in square brackets at the very end of your reply: "
                 + chatTagActions.map(a => "[" + a + "] (" + (actionDesc[a] || a) + ")").join(", ")
                 + ". Do not add a tag if you don't want to do anything."
        if (useTools) {
            if (lookTool)
                p += " You CAN see the user's screen: whenever the user asks you to look at it or asks what is on it, "
                     + "call the look_at_screen tool. Never say that you can't see the screen."
            if (terminalTool)
                p += " When the user asks about the computer (how much RAM is used, CPU, battery, temperature, disk...), call system_status and answer with the real numbers."
                     + " When the user asks you to do a simple thing in the terminal (list files, check disk, ping, create a folder...), call run_terminal."
            if (webTool)
                p += " You have internet access through tools. When the user asks about news, current events, weather, prices, exchange rates, "
                     + "facts you are not sure about, or asks you to search/google something, call web_search first (write the query in the best language for it). "
                     + "If the snippets do not contain the exact answer (a number, a date, a name), you MUST call read_web_page with the most useful link before answering. "
                     + "NEVER invent numbers or facts: use only what is written in the tool results; if it is not there, say you could not find it. "
                     + "Then answer briefly in Ukrainian and mention the site. Do not search for simple chat or things you already know well."
            if (commandNames.length)
                p += " When the user asks you to open a program or to do something on the computer (sound louder/quieter, pause music, next song, screenshot, brightness, game mode...), call the open_program tool with the matching name. Do it right away, don't ask again."
            if (toolActions.length)
                p += " If YOU want to do something with your body, call the do_action tool."
            p += " After a tool returns its result, answer the user with a short reply."
            return p
        }
        if (lookTool)
            p += " You CAN see the user's screen: when the user asks you to look at it or asks about what is on it, "
                 + "reply with a very short phrase and add the tag [look] at the end — the screenshot will be sent to you right after. "
                 + "Never say that you can't see the screen."
        if (commandNames.length)
            p += " You can open programs and do simple actions for the user (volume, music, screenshot...), but ONLY when the user asks you to: add the tag [run:NAME] where NAME is one of: "
                 + commandNames.map(n => n + (commands[n].desc ? " (" + commands[n].desc + ")" : "")).join(", ")
                 + ". Never invent other names."
        return p
    }
    readonly property string systemPrompt: basePrompt + tagsPrompt
    // сьогоднішня дата щоразу (інакше модель певна, що зараз рік її навчання)
    function nowNote() {
        const d = new Date()
        const days = ["неділя", "понеділок", "вівторок", "середа", "четвер", "пʼятниця", "субота"]
        let n = " Today is " + Qt.formatDate(d, "yyyy-MM-dd") + " (" + days[d.getDay()] + "), time " + Qt.formatTime(d, "HH:mm")
              + ". Your built-in knowledge is older than that: for anything about dates, the current year, news or prices, trust this date and the tool results, not your memory."
        if (webTool)
            n += " If the user mentions a product, model number, game, person or term you don't know well (e.g. 'alientek t90b'), "
               + "do NOT say you don't know — call web_search with exactly that name first. "
               + "Only say nothing was found if web_search really returned \"Нічого не знайдено\"."
        return n
    }

    readonly property var toolDefs: {
        const t = []
        if (lookTool) t.push({ type: "function", function: {
            name: "look_at_screen",
            description: "Take a screenshot of the user's screen and look at it. Use it whenever the user asks you to look at the screen or asks what is on it.",
            parameters: { type: "object", properties: {}, required: [] } } })
        if (terminalTool) t.push({ type: "function", function: {
            name: "system_status",
            description: "Get the computer status right now: RAM usage, CPU load and temperature, GPU, battery, disk, top processes. Use it when the user asks about memory, CPU, battery, temperature, what is slow, etc.",
            parameters: { type: "object", properties: {}, required: [] } } })
        if (terminalTool) t.push({ type: "function", function: {
            name: "run_terminal",
            description: "Run ONE simple, safe shell command and get its output (e.g. 'df -h /', 'free -h', 'ls ~/Завантажене', 'ping -c 3 google.com', 'mkdir ~/NewFolder', 'pacman -Q | wc -l', 'uptime'). Only read-only or harmless commands; dangerous ones (rm, sudo, redirects >) are blocked.",
            parameters: { type: "object", required: ["command"], properties: {
                command: { type: "string", description: "the shell command" } } } } })
        if (webTool) t.push({ type: "function", function: {
            name: "web_search",
            description: "Search the internet. Returns up to 5 results: title, link, short snippet. Use it for news, weather, prices, exchange rates, facts you don't know.",
            parameters: { type: "object", required: ["query"], properties: {
                query: { type: "string", description: "search query" } } } } })
        if (webTool) t.push({ type: "function", function: {
            name: "read_web_page",
            description: "Download a web page and return its main text (shortened). Use it after web_search when you need details from a result.",
            parameters: { type: "object", required: ["url"], properties: {
                url: { type: "string", description: "full link, e.g. https://..." } } } } })
        if (commandNames.length) t.push({ type: "function", function: {
            name: "open_program",
            description: "Open a program or do a simple action on the computer (volume, music, screenshot, brightness, windows). Only when the user asks for it.",
            parameters: { type: "object", required: ["name"], properties: {
                name: { type: "string", enum: commandNames,
                        description: commandNames.map(n => n + (commands[n].desc ? " = " + commands[n].desc : "")).join("; ") } } } } })
        if (toolActions.length) t.push({ type: "function", function: {
            name: "do_action",
            description: "Do something with your body on the desktop.",
            parameters: { type: "object", required: ["action"], properties: {
                action: { type: "string", enum: toolActions,
                          description: toolActions.map(a => a + " = " + (actionDesc[a] || a)).join("; ") } } } } })
        return t
    }

    // виконати один tool_call; повертає текст результату для role:"tool"
    // look_at_screen асинхронний — його обробляє цикл в ask()
    function runTool(name, args) {
        let a = args || {}
        if (typeof a === "string") { try { a = JSON.parse(a) } catch (e) { a = {} } }
        if (name === "open_program") {
            const n = String(a.name || a.program || "").toLowerCase()
            if (commands[n] === undefined) return "Error: unknown program \"" + n + "\". Available: " + commandNames.join(", ")
            return runCommand(n) ? "Opened " + n + "." : "Error: could not open " + n + "."
        }
        if (name === "do_action") {
            const act = String(a.action || "").toLowerCase()
            if (toolActions.indexOf(act) < 0) return "Error: unknown action \"" + act + "\". Available: " + toolActions.join(", ")
            if (typeof canDo === "function" && !canDo(act)) return "You can't " + (actionDesc[act] || act) + " right now."
            wants([{ action: act, arg: "" }])
            return "Done: you " + (actionDesc[act] || act) + "."
        }
        // дрібна модель інколи кличе команду напряму як інструмент (volume_down замість open_program) — теж виконуємо
        const direct = String(name || "").toLowerCase()
        if (commands[direct] !== undefined)
            return runCommand(direct) ? "Done: " + direct + "." : "Error: could not run " + direct + "."
        return "Error: unknown tool " + name
    }

    // tool_calls від Ollama → ті самі {action, arg}, що й теги
    function toolsToTags(calls) {
        const out = []
        for (let i = 0; i < calls.length; i++) {
            const f = calls[i] && calls[i].function
            if (!f) continue
            let a = f.arguments || {}
            if (typeof a === "string") { try { a = JSON.parse(a) } catch (e) { a = {} } }
            if (f.name === "look_at_screen" && lookTool) out.push({ action: "look", arg: "" })
            else if (f.name === "open_program") {
                const n = String(a.name || a.program || "").toLowerCase()
                if (commands[n] !== undefined) out.push({ action: "run", arg: n })
            }
            else if (commands[String(f.name || "").toLowerCase()] !== undefined) out.push({ action: "run", arg: String(f.name).toLowerCase() })
        }
        return out
    }

    property bool busy: false
    property string partial: ""
    property var history: []
    property var xhr: null

    signal started()
    signal chunk(string textSoFar)
    signal finished(string text)
    signal failed(string reason)
    signal wants(var actions)       // теги з відповіді: [{ action, arg }]
    signal decided(var choice)      // вільна воля: { action, arg, say } або null
    signal launched(string name)    // запустила програму зі списку
    signal looked()                 // зробила скрін і відправила моделі
    signal searching(string query)  // шукає в інтернеті (для бульбашки «шукаю…»)

    // ───────────────────────── текст ─────────────────────────
    function clean(t) {
        t = String(t || "").replace(/<think>[\s\S]*?<\/think>/g, "")
        const open = t.indexOf("<think>")
        if (open >= 0) t = t.slice(0, open)
        // теги [dance], [run:htop] не показуємо (і недописаний "[ru" наприкінці теж)
        t = t.replace(/\[\s*[a-zA-Z_]+(\s*:\s*[^\]\n]*)?\s*\]/g, "").replace(/\[[a-zA-Z_:\s-]*$/, "")
        return t.replace(/\*\*|__|`/g, "").replace(/^\s+/, "")
    }

    function extractTags(raw) {
        const out = []
        const re = /\[\s*([a-zA-Z_]+)\s*(?::\s*([^\]\n]*?))?\s*\]/g
        let m
        while ((m = re.exec(String(raw || ""))) !== null) {
            const a = m[1].toLowerCase()
            const arg = (m[2] || "").trim().toLowerCase()
            if (a === "run") {
                if (commands[arg] !== undefined) out.push({ action: "run", arg: arg })
            } else if ((chatTagActions.indexOf(a) >= 0 || (a === "look" && lookTool)) && !out.some(o => o.action === a)) {
                out.push({ action: a, arg: "" })
            }
        }
        return out
    }

    // ───────────────────────── програми ─────────────────────────
    function runCommand(name) {
        if (!enabled) return false
        const c = commands[String(name || "").toLowerCase()]
        if (!c) return false
        if (isList(c.cmd)) Quickshell.execDetached(Array.prototype.slice.call(c.cmd).map(String))
        else Quickshell.execDetached(["sh", "-c", String(c.cmd)])
        launched(String(name))
        return true
    }

    // ───────────────────────── історія ─────────────────────────
    property bool historyLoaded: false

    function forget() {
        history = []
        saveHistory()
    }

    function loadHistory() {
        if (!historyPath.length) return
        let list = []
        try {
            const txt = histFile.text()
            if (txt && txt.trim().length) {
                const o = JSON.parse(txt)
                const arr = Array.isArray(o) ? o : (o && Array.isArray(o.messages) ? o.messages : [])
                list = arr.filter(m => m && (m.role === "user" || m.role === "assistant" || m.role === "event")
                                         && typeof m.content === "string")
                // старий формат подій (content українською + en) -> лише англійська
                list = list.map(m => {
                    if (m.role !== "event" || typeof m.en !== "string") return m
                    return { role: "event", kind: m.kind, content: m.en, time: m.time }
                })
            }
        } catch (e) {
            console.warn("[pet brain] не вдалося прочитати " + historyPath + ": " + (e.message || e))
            return
        }
        history = list.slice(-historyKeep)
        historyLoaded = true
    }

    function saveHistory() {
        if (!historyPath.length) return
        histFile.setText(JSON.stringify({
            pet: petName, model: model, saved: new Date().toISOString(),
            messages: history.slice(-historyKeep)
        }, null, 2) + "\n")
    }

    function saveSoon() { if (historyPath.length) saveTimer.restart() }
    Timer { id: saveTimer; interval: 1500; onTriggered: brain.saveHistory() }

    FileView {
        id: histFile
        path: brain.historyPath
        blockLoading: true
        printErrors: false
        onLoaded: if (!brain.historyLoaded) brain.loadHistory()
        onSaveFailed: (err) => console.warn("[pet brain] не вдалося зберегти історію в " + brain.historyPath + ": " + err)
    }
    onHistoryPathChanged: { historyLoaded = false; history = []; if (historyPath.length) loadHistory() }
    Component.onCompleted: loadHistory()

    // Подія — один англійський рядок (саме так її бачить модель)
    function logEvent(text, kind) {
        if (!enabled) return
        const k = String(kind || "event")
        const t = String(text === undefined ? "" : text).trim()
        // скрін «після певних дій» (brain.look.onEvents)
        if (lookEnabled && lookOnEvents.indexOf(k) >= 0 && Date.now() - lastLook > lookCooldownMs)
            Qt.callLater(() => brain.look("Something just happened: " + t + "."))
        if (!logEvents || !t.length) return
        history = history.concat([{ role: "event", kind: k, content: t, time: new Date().toISOString() }])
                         .slice(-historyKeep)
        saveSoon()
    }

    // що бачить модель: останні репліки розмови + останні події (англійською), хронологічно
    function contextMessages() {
        const wantChat = historyTurns * 2
        const wantEv = eventsInContext ? eventsContext : 0
        const out = []
        let nc = 0, ne = 0
        for (let i = history.length - 1; i >= 0 && (nc < wantChat || ne < wantEv); i--) {
            const m = history[i]
            if ((m.role === "user" || m.role === "assistant") && !m.auto) {
                if (nc >= wantChat) continue
                out.push({ role: m.role, content: m.content })
                nc++
            } else {
                if (ne >= wantEv) continue
                out.push({ role: "system", content: m.role === "event"
                    ? "(Event: " + m.content + ")"
                    : "(You said on your own: " + m.content + ")" })
                ne++
            }
        }
        return out.reverse()
    }

    // ───────────────────────── розмова ─────────────────────────
    property int askSeq: 0
    function cancel() {
        askSeq++
        const x = xhr
        xhr = null
        busy = false
        timeoutTimer.stop()
        if (x) { try { x.abort() } catch (e) {} }
    }

    function fail(reason) {
        cancel()
        console.warn("[pet brain] " + reason)
        failed(reason)
    }

    // remember = false — службовий запит (трек, балачки, скрін): не потрапляє в розмову
    // image — base64 JPEG/PNG (для моделей із зором)
    function ask(text, remember, image, noTools) {
        if (!enabled) return
        const q = String(text === undefined ? "" : text).trim()
        if (!q.length) return
        cancel()

        const keep = remember !== false && remember !== "answer"
        const answerOnly = remember === "answer"     // скрін на прохання: у розмову йде лише її відповідь
        const asked = new Date().toISOString()
        if (keep) lastUserText = q
        const msgs = [{ role: "system", content: systemPrompt + brain.nowNote() }]
        const h = contextMessages()
        for (let i = 0; i < h.length; i++) msgs.push(h[i])
        // в історію піде лише q — картинка й ця примітка тільки для поточного запиту
        const um = { role: "user", content: keep && image
            ? q + "\n\n(Attached: a screenshot of my screen right now. Look at it carefully and answer based on what you actually see: "
            + "name the programs, windows, pictures or text on it. Do not ask me to show it — you already see it.)" : q }
        if (image) um.images = [image]
        msgs.push(um)

        const withTools = useTools && keep && !noTools
        const token = ++brain.askSeq    // новий ask/cancel робить старі кроки циклу недійсними
        let used = []           // які інструменти вже викликала (для фрази, якщо сама нічого не скаже)
        busy = true
        started()

        // ── один крок циклу: запит → або текстова відповідь (кінець), або tool_calls → результати → наступний крок
        function step(n) {
            if (brain.askSeq !== token || !brain.enabled) return
            const x = new XMLHttpRequest()
            brain.xhr = x
            brain.partial = ""
            let seen = 0
            let buf = ""
            let calls = []
            const toolsNow = withTools && n < brain.toolSteps   // ліміт вичерпано — просимо просто відповісти

            function toTags(error) {
                console.warn("[pet-brain] " + brain.model + " не вміє tools — переходжу на теги")
                brain.toolsBroken = true
                brain.xhr = null
                Qt.callLater(() => brain.ask(q, remember, image))
            }

            function eat(text) {
                buf += text
                let nl
                while ((nl = buf.indexOf("\n")) >= 0) {
                    const line = buf.slice(0, nl).trim()
                    buf = buf.slice(nl + 1)
                    if (!line.length) continue
                    let o
                    try { o = JSON.parse(line) } catch (e) { continue }
                    if (o.error) {
                        if (toolsNow && /does not support tools/i.test(String(o.error))) { x.abort(); toTags(); return false }
                        brain.fail(String(o.error)); return false
                    }
                    if (o.message && o.message.tool_calls) calls = calls.concat(o.message.tool_calls)
                    if (o.message && o.message.content) {
                        brain.partial += o.message.content
                        brain.chunk(brain.clean(brain.partial))
                    }
                }
                return true
            }

            x.onreadystatechange = function() {
                if (x !== brain.xhr) return
                if (x.readyState === XMLHttpRequest.LOADING || x.readyState === XMLHttpRequest.DONE) {
                    const all = x.responseText || ""
                    const fresh = all.slice(seen)
                    seen = all.length
                    if (fresh.length && !eat(fresh)) return
                }
                if (x.readyState !== XMLHttpRequest.DONE) return

                if (x.status !== 200) {
                    let reason = x.status === 0
                        ? "Ollama не відповідає (" + brain.url + ") — запущена?"
                        : "Ollama: HTTP " + x.status
                    try { const o = JSON.parse(x.responseText); if (o.error) reason = String(o.error) } catch (e) {}
                    if (toolsNow && /does not support tools/i.test(reason)) { toTags(); return }
                    if (reason.indexOf("not found") >= 0) reason += " — зроби: ollama pull " + brain.model
                    brain.fail(reason)
                    return
                }
                eat("\n")
                console.log("[pet-brain] крок " + (n + 1) + ": " + JSON.stringify(brain.partial)
                            + (calls.length ? "  tools: " + JSON.stringify(calls.map(c => c.function)) : ""))

                // ── є виклики інструментів: виконати, додати результати, наступний крок
                if (toolsNow && calls.length) {
                    msgs.push({ role: "assistant", content: brain.partial,
                                tool_calls: calls.map(c => ({ function: { name: c.function.name, arguments: c.function.arguments || {} } })) })
                    let shotNeeded = false
                    const asyncTools = []          // system_status / run_terminal — виконуються по черзі нижче
                    for (let i = 0; i < calls.length; i++) {
                        const f = calls[i].function || {}
                        used.push(f.name === "open_program" ? { action: "run", arg: String((f.arguments || {}).name || "") }
                                  : brain.commands[String(f.name || "").toLowerCase()] !== undefined ? { action: "run", arg: String(f.name).toLowerCase() }
                                  : f.name === "do_action" ? { action: String((f.arguments || {}).action || ""), arg: "" }
                                  : (f.name === "system_status" || f.name === "run_terminal" || f.name === "web_search" || f.name === "read_web_page") ? { action: "info", arg: "" }
                                  : { action: "look", arg: "" })
                        if (f.name === "look_at_screen" && brain.lookTool) {
                            shotNeeded = true
                            msgs.push({ role: "tool", tool_name: f.name, content: "Screenshot taken, it is in the next message." })
                        } else if ((f.name === "system_status" || f.name === "run_terminal") && brain.terminalTool) {
                            asyncTools.push(f)
                        } else if ((f.name === "web_search" || f.name === "read_web_page") && brain.webTool) {
                            asyncTools.push(f)
                        } else {
                            const r = brain.runTool(f.name, f.arguments)
                            console.log("[pet-brain]   " + f.name + " → " + r)
                            msgs.push({ role: "tool", tool_name: f.name, content: r })
                        }
                    }
                    brain.xhr = null
                    function afterAsync() {
                        if (!shotNeeded) { Qt.callLater(() => step(n + 1)); return }
                        brain.shotForTool(function(b64) {
                            if (brain.askSeq !== token || !brain.enabled) return
                            if (b64) { brain.looked(); msgs.push({ role: "user", content: "(Screenshot of my screen from look_at_screen.)", images: [b64] }) }
                            else msgs.push({ role: "user", content: "(look_at_screen failed: could not take a screenshot.)" })
                            step(n + 1)
                        })
                    }
                    function nextAsync() {
                        if (brain.askSeq !== token || !brain.enabled) return
                        const f = asyncTools.shift()
                        if (!f) { afterAsync(); return }
                        let a = f.arguments || {}
                        if (typeof a === "string") { try { a = JSON.parse(a) } catch (e) { a = {} } }
                        if (f.name === "web_search" || f.name === "read_web_page") {
                            const isSearch = f.name === "web_search"
                            const q = String(isSearch ? (a.query || a.q || "") : (a.url || a.link || "")).trim()
                            brain.searching(isSearch ? q : "")
                            brain.runShell([brain.toolsDir + "/pet-web", isSearch ? "search" : "read", q], function(out) {
                                console.log("[pet-brain]   " + f.name + " `" + q + "` → " + out.slice(0, 200).replace(/\n/g, " | "))
                                msgs.push({ role: "tool", tool_name: f.name, content: out.length ? out : "(empty)" })
                                nextAsync()
                            })
                        } else if (f.name === "system_status") {
                            brain.runShell([brain.toolsDir.replace("/tools", "/bg_popups/popctl"), "sys"], function(out) {
                                const r = brain.sysSummary(out)
                                console.log("[pet-brain]   system_status → " + r.slice(0, 200))
                                msgs.push({ role: "tool", tool_name: f.name, content: r })
                                nextAsync()
                            })
                        } else {
                            const c = String(a.command || a.cmd || "")
                            brain.runShell([brain.toolsDir + "/pet-safe-shell", c], function(out) {
                                console.log("[pet-brain]   run_terminal `" + c + "` → " + out.slice(0, 200))
                                msgs.push({ role: "tool", tool_name: f.name, content: out.length ? out : "(no output)" })
                                nextAsync()
                            })
                        }
                    }
                    if (asyncTools.length) { nextAsync(); return }
                    if (!shotNeeded) { Qt.callLater(() => step(n + 1)); return }
                    // скрін → окреме повідомлення з картинкою → далі
                    brain.shotForTool(function(b64) {
                        if (brain.askSeq !== token || !brain.enabled) return
                        if (b64) { brain.looked(); msgs.push({ role: "user", content: "(Screenshot of my screen from look_at_screen.)", images: [b64] }) }
                        else msgs.push({ role: "user", content: "(look_at_screen failed: could not take a screenshot.)" })
                        step(n + 1)
                    })
                    return
                }

                // ── звичайна відповідь: кінець циклу
                const tags = brain.extractTags(brain.partial)
                if (keep && used.length === 0 && tags.length === 0) {
                    const g = brain.guessCommand(q)
                    if (g.length) {
                        console.log("[pet-brain] модель не викликала інструмент — сама запускаю " + g)
                        brain.runCommand(g)
                        used.push({ action: "run", arg: g })
                    }
                }
                let answer = brain.clean(brain.partial).trim()
                // нічого не сказала, лише щось зробила — фраза про дію
                const last = tags.length ? tags[0] : (used.length ? used[used.length - 1] : null)
                if (!answer.length && last) answer = brain.actionLine(last.action, last.arg)
                brain.xhr = null
                brain.busy = false
                timeoutTimer.stop()
                const now = new Date().toISOString()
                if (answerOnly && answer.length) {
                    brain.history = brain.history.concat([{ role: "assistant", content: answer, time: now }])
                                                 .slice(-brain.historyKeep)
                    brain.saveHistory()
                } else if (keep && answer.length) {
                    brain.history = brain.history.concat([
                        { role: "user", content: q, time: asked },
                        { role: "assistant", content: answer, time: now }
                    ]).slice(-brain.historyKeep)
                    brain.saveHistory()
                } else if (!keep && answer.length && brain.logEvents) {
                    brain.history = brain.history.concat([{ role: "assistant", auto: true, content: answer, time: now }])
                                                 .slice(-brain.historyKeep)
                    brain.saveSoon()
                }
                brain.finished(answer.length ? answer : brain.emptyReply())
                if (tags.length) brain.wants(tags)      // теги (якщо модель без tools)
            }

            x.open("POST", brain.url + "/api/chat")
            x.setRequestHeader("Content-Type", "application/json")
            x.send(JSON.stringify({
                model: brain.model, messages: msgs, stream: true, think: brain.think, keep_alive: brain.keepAlive,
                options: { num_predict: brain.maxTokens, temperature: brain.temperature },
                tools: toolsNow ? brain.toolDefs : undefined
            }))
            timeoutTimer.restart()
        }

        step(0)
    }

    Timer {
        id: timeoutTimer
        interval: brain.timeoutMs
        onTriggered: brain.fail("занадто довго думає (brain.timeoutMs)")
    }

    // ───────────────────────── скріншот ─────────────────────────
    // grim знімає екран одразу зменшеним (-s) у JPEG і віддає в stdout — на диск нічого не пишеться.
    // Картинка йде в ту саму модель (brain.model): якщо вона без зору — Ollama поверне помилку.
    property string lookReason: ""
    property string lookMode: ""        // "chat" — скрін для повідомлення в чаті
    property string pendingChat: ""

    // питання про екран — скрін чіпляється одразу, не чекаючи, чи модель сама здогадається викликати look_at_screen
    // (дрібні моделі часто відповідають «покажи мені екран» замість виклику інструмента).
    // Свій список: brain.look.keywords = "регулярний вираз" ("" = вимкнути)
    readonly property var screenRe: {
        const k = lookCfg.keywords
        if (typeof k === "string") { try { return k.trim().length ? new RegExp(k, "i") : null } catch (e) { return null } }
        return /екран|скрін|скрин|монітор|screen|бачиш|глянь|подивись|подивися|що\s+(я\s+)?(зараз\s+)?(роблю|дивлюсь|дивлюся|відкрито|відкрив)|what\s+(do\s+)?you\s+see|look\s+at/i
    }
    property bool pendingNoTools: false

    // повідомлення з чату: з look.inChat (або коли питають про екран) спершу скрін, потім запит разом із ним
    function chat(text) {
        if (!enabled) return
        const q = String(text === undefined ? "" : text).trim()
        if (!q.length) return
        const aboutScreen = lookEnabled && screenRe !== null && screenRe.test(q)
        if ((!lookInChat && !aboutScreen) || shot.running) { ask(q); return }
        cancel()
        pendingNoTools = aboutScreen && !lookInChat   // зі скріном — хай просто відповідає, а не кличе інструменти
        pendingChat = q
        lookMode = "chat"
        lastLook = Date.now()
        busy = true
        started()
        runShot()
    }

    // скрін для інструмента look_at_screen: cb(base64) або cb("") якщо не вийшло
    property var shotCb: null
    function shotForTool(cb) {
        if (shot.running) { cb(""); return }
        shotCb = cb
        lookMode = "tool"
        lastLook = Date.now()
        runShot()
    }

    function runShot() {
        shot.command = ["sh", "-c",
            'command -v grim >/dev/null 2>&1 || { echo "NOGRIM"; exit 0; }; grim -s "$1" -t jpeg -q "$2" - | base64 -w0',
            "sh", String(lookScale), String(lookQuality)]
        shot.running = true
    }
    property bool lookAsked: false      // true — користувач сам попросив глянути
    property string lastUserText: ""    // останнє, що написав користувач (питання до скріна)

    function look(reason, asked) {
        if (!lookEnabled || shot.running) { console.log("[pet-brain] look: пропущено (look.enabled=" + lookEnabled + ", running=" + shot.running + ")"); return false }
        lastLook = Date.now()
        lookReason = String(reason || "")
        lookAsked = asked === true
        lookMode = ""
        runShot()
        return true
    }

    Process {
        id: shot
        stdout: StdioCollector {
            onStreamFinished: {
                const b64 = text.trim()
                if (brain.lookMode === "tool") {
                    brain.lookMode = ""
                    const cb = brain.shotCb
                    brain.shotCb = null
                    if (b64.length < 200) console.warn("[pet-brain] скрін для look_at_screen не вийшов" + (b64 === "NOGRIM" ? " — нема grim" : ""))
                    else console.log("[pet-brain] look_at_screen: скрін " + Math.round(b64.length * 3 / 4 / 1024) + " КіБ")
                    if (cb) cb(b64.length < 200 ? "" : b64)
                    return
                }
                if (brain.lookMode === "chat") {
                    brain.lookMode = ""
                    const q = brain.pendingChat
                    brain.pendingChat = ""
                    if (!brain.enabled) return
                    if (b64.length < 200) {           // скрін не вийшов — відповідає просто без нього
                        console.warn("[pet-brain] скрін для чату не вийшов" + (b64 === "NOGRIM" ? " — нема grim" : ""))
                        brain.ask(q)
                    } else {
                        console.log("[pet-brain] чат + скрін " + Math.round(b64.length * 3 / 4 / 1024) + " КіБ → " + brain.model)
                        brain.looked()
                        brain.ask(q, true, b64, brain.pendingNoTools)
                    }
                    return
                }
                if (b64 === "NOGRIM") { brain.failed("нема grim — sudo pacman -S grim"); return }
                if (b64.length < 200) { brain.failed("не вдалося зробити скрін"); return }
                console.log("[pet-brain] look: скрін " + Math.round(b64.length * 3 / 4 / 1024) + " КіБ → " + brain.model)
                brain.looked()
                if (brain.lookAsked)
                    brain.ask("This image is a screenshot of the user's screen right now. "
                        + (brain.lookReason ? "The user asked you: \"" + brain.lookReason + "\". Answer it based on what you see. " : "Tell the user what you see. ")
                        + "Stay in character, keep it short, do not add tags.", "answer", b64)
                else
                    brain.ask((brain.lookReason ? brain.lookReason + " " : "")
                        + "This image is a screenshot of the user's screen right now. "
                        + "React to what you see, in character, in one short sentence.", false, b64)
            }
        }
    }

    // ───────────────────────── вільна воля ─────────────────────────
    property var decideXhr: null
    readonly property bool deciding: decideXhr !== null

    function decide(situation, actions) {
        if (!enabled || deciding) { decided(null); return }
        // autonomy.useModel: false — вільна воля без моделі (навмання), щоб Ollama не працювала в простої
        if (autoCfg.useModel === false) { decided(null); return }
        const list = actions.map(a => a + " (" + (actionDesc[a] || a) + ")").join(", ")
        const msgs = [{ role: "system", content: basePrompt + " Right now nobody is talking to you — you decide on your own what to do." }]
        const h = contextMessages()
        for (let i = 0; i < h.length; i++) msgs.push(h[i])
        msgs.push({ role: "user", content: situation + "\nPick exactly ONE action from: " + list + ".\n"
            + "Answer with JSON only: {\"action\": \"<one action from the list>\", \"say\": \"<a short phrase "
            + "in the language the user usually speaks to you, or an empty string>\"}" })

        const x = new XMLHttpRequest()
        decideXhr = x
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE || x !== brain.decideXhr) return
            brain.decideXhr = null
            decideTimer.stop()
            let choice = null
            if (x.status === 200) {
                try {
                    const o = JSON.parse(x.responseText)
                    choice = brain.parseChoice(o.message ? o.message.content : "", actions)
                } catch (e) {}
            } else {
                console.warn("[pet brain] вільна воля: Ollama HTTP " + x.status)
            }
            brain.decided(choice)
        }
        x.open("POST", url + "/api/chat")
        x.setRequestHeader("Content-Type", "application/json")
        x.send(JSON.stringify({
            model: brain.model, messages: msgs, stream: false, format: "json", think: false,
            keep_alive: brain.keepAlive, options: { num_predict: 80, temperature: 0.9 }
        }))
        decideTimer.restart()
    }

    // JSON → дія зі списку; якщо JSON нема — шукаємо назву дії в тексті; поза списком — null
    function parseChoice(content, actions) {
        const txt = String(content || "").replace(/<think>[\s\S]*?<\/think>/g, "")
        let action = "", say = "", parsed = false
        const j = txt.match(/\{[\s\S]*\}/)
        if (j) {
            try {
                const o = JSON.parse(j[0])
                action = String(o.action || "").trim().toLowerCase()
                say = String(o.say || "").trim()
                parsed = true
            } catch (e) {}
        }
        if (parsed && actions.indexOf(action) < 0) return null
        if (!parsed) {
            action = ""
            const low = txt.toLowerCase()
            for (let i = 0; i < actions.length; i++) if (low.indexOf(actions[i]) >= 0) { action = actions[i]; break }
        }
        if (!action.length) return null
        return { action: action, arg: "", say: say.slice(0, 160) }
    }

    Timer {
        id: decideTimer
        interval: Math.min(brain.timeoutMs, 45000)
        onTriggered: {
            const x = brain.decideXhr
            brain.decideXhr = null
            if (x) { try { x.abort() } catch (e) {} }
            brain.decided(null)
        }
    }

    // вимкнули мозок на льоту — обірвати все, що зараз у процесі
    onEnabledChanged: if (!enabled) {
        cancel()
        if (decideXhr) { const x = decideXhr; decideXhr = null; try { x.abort() } catch (e) {} }
        shot.running = false
    }
}
