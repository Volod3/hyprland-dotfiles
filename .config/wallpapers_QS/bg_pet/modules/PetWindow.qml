import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick

PanelWindow {
    id: win

    property var cfg: ({})

    // ───────────────────────── допоміжні читачі конфігу ─────────────────────────
    function num(o, k, d) {
        if (!o || o[k] === undefined || o[k] === null) return d
        const v = Number(o[k])
        return isNaN(v) ? d : v
    }
    function flag(o, k, d) {
        if (!o || o[k] === undefined || o[k] === null) return d
        return Boolean(o[k])
    }
    function obj(v) {
        return (v && typeof v === "object" && !Array.isArray(v)) ? v : ({})
    }
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function wrap180(a) { return ((a + 180) % 360 + 360) % 360 - 180 }

    readonly property var physCfg: obj(cfg ? cfg.physics : null)
    readonly property var hardCfg: obj(cfg ? cfg.hardcore : null)
    readonly property var wanderCfg: obj(cfg ? cfg.wander : null)
    readonly property var fxCfg: obj(cfg ? cfg.effects : null)
    readonly property var platCfg: obj(cfg ? cfg.platforms : null)
    readonly property var sndCfg: obj(cfg ? cfg.sounds : null)

    readonly property bool peaceful: flag(cfg, "peaceful", true)
    readonly property real petScale: num(cfg, "scale", 1.0)
    readonly property real petSize: 96 * petScale
    readonly property real footPad: num(cfg, "footPadding", 0) * petScale
    readonly property real contactH: petSize - footPad
    readonly property bool spriteFacesLeft: cfg ? cfg.facing === "left" : false
    readonly property string petName: (cfg && cfg.name) ? String(cfg.name) : "Mimi"
    // true = над усім, навіть над повноекранними вікнами; false = під повноекранними
    // (раніше ключ "alwaysOnTop" у pet.json ніде не читався)
    readonly property bool alwaysOnTop: flag(cfg, "alwaysOnTop", true)

    // фізика
    readonly property real gravity: num(physCfg, "gravity", 1200)
    readonly property real floorBounce: num(physCfg, "bounce", 0.35)
    readonly property real wallBounce: num(physCfg, "wallBounce", 0.55)
    readonly property real ceilingBounce: num(physCfg, "ceilingBounce", 0.5)
    readonly property real groundFriction: num(physCfg, "friction", 0.97)      // за кадр @60fps
    readonly property real airDrag: num(physCfg, "airDrag", 0.985)            // за кадр @60fps
    readonly property real spinDamping: num(physCfg, "spinDamping", 0.985)
    readonly property real spinFactor: num(physCfg, "spinFactor", 0.65)
    readonly property real spinAccel: num(physCfg, "spinAccel", 1.0)
    readonly property real spinK: spinFactor / 0.65
    readonly property real throwBoost: physCfg.throwBoost !== undefined
        ? num(physCfg, "throwBoost", 0.7) : num(physCfg, "throwMultiplier", 0.7)
    readonly property real throwThreshold: num(physCfg, "throwThreshold", 250)
    readonly property real maxThrowSpeed: num(physCfg, "maxThrowSpeed", 2400)
    // кидок на інший стіл: тепер у "workspaces" (старі ключі в "physics" теж розуміються)
    readonly property bool wsEnabled: flag(wsCfg, "throwToSwitch", flag(physCfg, "enableHyprlandWorkspaces", true))
    readonly property real wsSwitchSpeed: num(wsCfg, "throwSwitchSpeed", num(physCfg, "workspaceSwitchSpeed", 1900))

    // hardcore
    readonly property real shatterSpeed: num(hardCfg, "shatterSpeed", 1800)
    readonly property bool shatterOnFloor: flag(hardCfg, "shatterOnFloor", false)
    readonly property bool splatterEnabled: flag(hardCfg, "splatterEnabled", true)
    readonly property string splatterColor: (hardCfg.splatterColor && String(hardCfg.splatterColor).trim().length > 0)
        ? String(hardCfg.splatterColor) : "#d90429"
    readonly property int dropsPerPiece: Math.max(0, Math.floor(hardCfg.dropsPerPiece !== undefined
        ? num(hardCfg, "dropsPerPiece", 3) : num(hardCfg, "pieceDrops", 3)))
    readonly property real burstForce: Math.max(0.1, hardCfg.burstForce !== undefined
        ? num(hardCfg, "burstForce", 1.0) : num(hardCfg, "scatterForce", 1.0))
    readonly property real dropLifetimeSec: Math.max(0.3, num(hardCfg, "dropLifetimeMs", 2200) / 1000.0)
    readonly property bool fullRestartAfterShatter: hardCfg.fullRestart !== undefined
        ? Boolean(hardCfg.fullRestart)
        : (hardCfg.restartOnShatter !== undefined ? Boolean(hardCfg.restartOnShatter) : true)

    // ефекти
    readonly property bool shadowEnabled: flag(fxCfg, "shadow", true)
    readonly property bool squashEnabled: flag(fxCfg, "squash", true)
    readonly property bool heartsEnabled: flag(fxCfg, "hearts", true)
    readonly property string heartColor: fxCfg.heartColor ? String(fxCfg.heartColor) : "#ff5d8f"

    // платформи (верхні краї вікон Hyprland)
    readonly property bool platEnabled: flag(platCfg, "enabled", false)
    // true: кішка падає, щойно її центр вийшов за край вікна; false: тримається, поки хоч трохи перекриває
    readonly property bool platEdgeFall: flag(platCfg, "edgeFall", true)
    // ймовірність, що прогулянка свідомо зайде за край платформи (0 = ніколи не зіскакує сама)
    readonly property real platWanderOffChance: clamp(num(platCfg, "wanderOffChance", 0.25), 0, 1)
    readonly property int platRefreshMs: Math.floor(clamp(num(platCfg, "refreshMs", 400), 150, 3000))

    // ───────────────────────── вікно та маска кліків ─────────────────────────
    readonly property var musicCfg: obj(cfg ? cfg.music : null)
    readonly property bool musicEnabled: flag(musicCfg, "enabled", true)
    readonly property bool musicAnnounce: flag(musicCfg, "announceTracks", true)
    readonly property int musicBeatMs: Math.floor(clamp(num(musicCfg, "beatMs", 520), 200, 2000))
    readonly property real musicHopChance: clamp(num(musicCfg, "hopChance", 0.15), 0, 1)
    readonly property string noteColor: musicCfg.noteColor ? String(musicCfg.noteColor) : "#7dcfff"

    readonly property var travelCfg: obj(wanderCfg.workspaceTravel)
    readonly property bool travelEnabled: flag(travelCfg, "enabled", false)
    readonly property real travelChance: clamp(num(travelCfg, "chance", 0.12), 0, 1)
    readonly property real travelSpeed: num(travelCfg, "speed", 260)

    readonly property var wsCfg: obj(cfg ? cfg.workspaces : null)
    readonly property bool wsEnter: flag(wsCfg, "enterOnSwitch", true)
    // наскільки далі за межею екрана вона стартує (0 = рівно за краєм); спільне значення або окремі для країв
    readonly property real enterOffsetL: num(wsCfg, "enterOffsetLeft", num(wsCfg, "enterOffset", 30))
    readonly property real enterOffsetR: num(wsCfg, "enterOffsetRight", num(wsCfg, "enterOffset", 30))
    // швидкість, з якою вона заходить на екран (px/с)
    readonly property real enterSpeed: Math.max(20, num(wsCfg, "enterSpeed", 260))
    // true — поміняти сторони місцями
    readonly property bool enterInvert: flag(wsCfg, "invertSide", false)
    readonly property real sleepAfterSec: num(fxCfg, "sleepAfterMs", 0) / 1000.0
    readonly property var bubbleTheme: obj(cfg ? cfg.menuTheme : null)

    // мозок (локальна LLM через Ollama) — pet.json -> "brain"
    readonly property var brainCfg: obj(cfg ? cfg.brain : null)
    readonly property var chatterCfg: obj(brainCfg.chatter)
    property bool chatOpen: false           // відкрите поле для повідомлення

    // вільна воля — pet.json -> brain.autonomy
    readonly property var autoCfg: obj(brainCfg.autonomy)
    readonly property bool autoEnabled: petBrain.autoEnabled
    readonly property bool autoFallbackRandom: autoCfg.fallbackRandom !== false

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: win.alwaysOnTop ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "desktop_pet"
    // клавіатуру забираємо лише поки відкрите поле для повідомлення
    WlrLayershell.keyboardFocus: win.chatOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Під час перетягування ловимо мишу по всьому екрану; інакше — лише кішка + чат + меню.
    // (Раніше при відкритому чаті/меню весь екран був «мертвим» для інших програм, напр. Chrome.
    //  Клік повз чат/меню тепер ловить HyprlandFocusGrab нижче.)
    readonly property bool maskFull: isDragging
    readonly property real boxSize: {
        const r = angle * Math.PI / 180
        return (Math.abs(Math.cos(r)) + Math.abs(Math.sin(r))) * petSize
    }

    // Кліки ловимо лише на ТІЛІ персонажа (вузька смуга по центру спрайта), а не на всьому квадраті:
    // пет ходить по верхніх краях вікон, і прозорі кути квадрата раніше перекривали вкладки/кнопки (напр. у Chrome).
    readonly property real hitW: Math.round(boxSize * (Math.abs(angle) > 30 ? 0.7 : 0.42))
    readonly property real hitH: Math.round(boxSize * 0.86)
    mask: Region {
        x: win.maskFull ? 0 : Math.max(0, Math.round(win.posX + win.petSize / 2 - win.hitW / 2))
        y: win.maskFull ? 0 : Math.round(win.posY + win.petSize / 2 - win.hitH / 2 + win.boxSize * 0.06)
        width: win.isShattered ? 0 : (win.maskFull ? win.width : win.hitW)
        height: win.isShattered ? 0 : (win.maskFull ? win.height : win.hitH)
        Region { item: chatBox.visible ? chatBox : null }
        Region { item: petMenu.visible ? petMenu : null }
    }
    HyprlandFocusGrab {
        windows: [win]
        active: (win.chatOpen || petMenu.visible) && grabDelay.ready
        onCleared: { petMenu.visible = false; win.closeChat() }
    }
    Timer {
        id: grabDelay
        property bool ready: false
        interval: 150
        running: win.chatOpen || petMenu.visible
        onTriggered: ready = true
        onRunningChanged: if (!running) ready = false
    }

    // ───────────────────────── стан ─────────────────────────
    property real posX: 300
    property real posY: 300
    property real vx: 0
    property real vy: 0
    property real angle: 0
    property real angularVel: 0

    property bool isDragging: false
    property bool isShattered: false
    property bool grounded: false
    property real airTime: 0
    property bool airborne: false
    property bool facingLeft: false
    property bool settled: false
    property string mood: ""
    property real shadowY: 0
    property bool sleeping: false
    property real idleTime: 0
    property int travelDir: 0
    property var lastWsId: undefined
    property real enterOpacity: 1
    property bool entering: false

    // бульбашка з текстом
    property string bubbleText: ""
    property bool bubbleOn: false

    // таймер / секундомір
    property string timerMode: ""          // "", "countdown", "stopwatch"
    property real timerStartMs: 0
    property real timerEndMs: 0
    property real timerNow: 0
    property int danceBeats: 0
    property string lastAnnounced: ""

    // пружина "стиснення/розтягування"
    property real squash: 0
    property real squashVel: 0
    readonly property real airStretch: (squashEnabled && !isDragging && !grounded)
        ? Math.min(0.14, Math.abs(vy) / 7000) : 0
    readonly property real bodyScaleX: squashEnabled ? (1 + squash * 0.8) / (1 + airStretch) : 1
    readonly property real bodyScaleY: squashEnabled ? (1 - squash) * (1 + airStretch) : 1

    // прогулянки
    property bool isWandering: false
    property real wanderTargetX: 300
    property int lastWanderDir: 0
    property bool allowWanderRotate: false

    // перетягування
    property real grabDX: 0
    property real grabDY: 0
    property real pressPX: 0
    property real pressPY: 0
    property real pressT: 0
    property real dragVx: 0
    property real dragVy: 0
    property var dragSamples: []
    property real lastWsSwitch: 0
    property bool pickSoundPending: false

    // ── як вона опинилась у повітрі (для причини падіння/смерті в журналі) ──
    // "throw" — кинули, "drop" — відпустили з рук, "jump" — сама стрибнула, "fall" — зісковзнула з вікна
    property string flightCause: ""
    property real flightSpeed: 0
    property real peakY: 0                  // найвища точка польоту (менше = вище)

    // людська причина удару: where = "left wall" / "right wall" / "ceiling" / "floor" / "window"
    function impactCause(where, speed) {
        const v = Math.round(speed) + " px/s"
        const h = Math.max(0, Math.round(posY - peakY))
        const fromH = h > 40 ? " from " + h + " px high" : ""
        switch (flightCause) {
        case "throw":
            return "the user threw you" + (where === "floor" || where === "window" ? " and you slammed onto the " : " into the ")
                   + where + " (thrown at " + Math.round(flightSpeed) + " px/s, hit at " + v + ")"
        case "drop":
            return "the user let go of you and you fell" + fromH + " onto the " + where + " at " + v
        case "jump":
            return "you jumped on your own and crashed into the " + where + " at " + v
        case "fall":
            return "you slipped off a window and fell" + fromH + " onto the " + where + " at " + v
        default:
            return "you crashed into the " + where + " at " + v
        }
    }
    function playPickSound() {
        if (!pickSoundPending) return
        pickSoundPending = false
        sfx("onPick")
        logEvent("The user picked you up", "pick")
    }

    // платформи
    property var platforms: []
    property var standPlat: null

    // розліт на шматочки
    property string shatterSource: ""
    property bool shatterFlip: false
    property var pieces: []
    property var pieceInfo: []
    property int pieceCount: 0
    property real shatterAge: 0
    property real shatterLife: 3.5

    // краплі крові та сердечка (пули без ListModel — швидко)
    readonly property int maxDrops: 260
    readonly property int maxHearts: 14
    property var drops: []
    property var hearts: []
    property int dropCursor: 0
    property int aliveDrops: 0
    property int aliveHearts: 0

    property int lastReactionIndex: -1
    property real lastTick: Date.now()

    readonly property string currentSpriteState: {
        if (isShattered) return "shatter"
        if (isDragging) return "drag"
        if (airborne) return "fly"
        if (mood !== "") return mood
        if (sleeping) return "sleep"
        if (Math.abs(vx) > 15) return "walk"
        if (musicActive) return "music"
        return "idle"
    }

    // ── музика (MPRIS) ──
    readonly property var activePlayer: {
        if (!musicEnabled) return null
        try {
            const list = Mpris.players.values
            for (let i = 0; i < list.length; i++) {
                // plasma-browser-integration лишається «грати» навіть після закриття Chrome — ігноруємо
                const n = ((list[i].dbusName || "") + " " + (list[i].identity || "")).toLowerCase()
                if (n.indexOf("plasma-browser-integration") >= 0) continue
                if (list[i].isPlaying) return list[i]
            }
        } catch (e) {}
        return null
    }
    readonly property bool musicActive: activePlayer !== null
    readonly property string musicTrack: activePlayer
        ? ((activePlayer.trackArtist ? activePlayer.trackArtist + " — " : "") + (activePlayer.trackTitle || ""))
        : ""
    onMusicTrackChanged: if (musicAnnounce) trackTimer.restart()

    readonly property string timerLabel: {
        if (timerMode === "") return ""
        const countdown = timerMode === "countdown"
        const ms = countdown ? Math.max(0, timerEndMs - timerNow) : Math.max(0, timerNow - timerStartMs)
        return (countdown ? "Timer " : "Stopwatch ") + fmtTime(ms, countdown)
    }

    Component.onCompleted: {
        try { lastWsId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : undefined } catch (e) {}
        const d = []
        for (let i = 0; i < maxDrops; i++) d.push({ alive: false })
        drops = d
        const h = []
        for (let j = 0; j < maxHearts; j++) h.push({ alive: false })
        hearts = h
    }

    onVisibleChanged: {
        if (visible) {
            lastTick = Date.now()
            settled = false
        }
    }

    // ───────────────────────── інтервали таймерів ─────────────────────────
    function nextReactionIntervalMs() {
        const rr = obj(sndCfg.randomReactions)
        const range = (Array.isArray(rr.randomIntervalMs) && rr.randomIntervalMs.length >= 2)
            ? rr.randomIntervalMs
            : ((sndCfg.randomIntervalMs && sndCfg.randomIntervalMs.length >= 2) ? sndCfg.randomIntervalMs : [1000, 4000])
        const rawMin = Number(range[0])
        const rawMax = Number(range[1])
        const minV = Math.max(200, isNaN(rawMin) ? 1000 : rawMin)
        const maxV = Math.max(minV + 100, isNaN(rawMax) ? 4000 : rawMax)
        return Math.floor(Math.random() * (maxV - minV + 1)) + minV
    }

    function nextWanderIntervalMs() {
        const range = (wanderCfg.intervalMs && wanderCfg.intervalMs.length >= 2) ? wanderCfg.intervalMs : [4000, 10000]
        const rawMin = Number(range[0])
        const rawMax = Number(range[1])
        const minV = Math.max(800, isNaN(rawMin) ? 4000 : rawMin)
        const maxV = Math.max(minV + 500, isNaN(rawMax) ? 10000 : rawMax)
        return Math.floor(Math.random() * (maxV - minV + 1)) + minV
    }

    // (прапорці "random"/"all" наприкінці списку тут не файли — раніше їх пробувало програти як звук)
    function reactionFiles() {
        const rr = sndCfg.randomReactions
        let list = []
        if (petAudio.isList(rr)) list = petAudio.toArray(rr)
        else if (rr && typeof rr === "object" && petAudio.isList(rr.files)) list = petAudio.toArray(rr.files)
        return list.filter(f => {
            const t = String(f).trim().toLowerCase()
            return t.length > 0 && t !== "random" && t !== "all"
        })
    }

    // ───────────────────────── керування життєвим циклом ─────────────────────────
    // запис події в історію (pet.json -> brain.logEvents)
    // подія в журнал (англійською — так її бачить і модель)
    function logEvent(text, kind) { petBrain.logEvent(text, kind) }

    function sfx(name) {
        const s = sndCfg[name]
        if (s) petAudio.play(s)
    }

    function restartShell() {
        Quickshell.execDetached([
            "sh", "-c",
            "sleep 0.15; exec qs -p \"$1\"", "sh",
            Quickshell.shellPath("shell.qml")
        ])
        Qt.quit()
    }

    function clearParticles() {
        pieces = []
        pieceInfo = []
        pieceCount = 0
        for (let i = 0; i < drops.length; i++) {
            drops[i].alive = false
            const it = dropsRep.itemAt(i)
            if (it) it.visible = false
        }
        for (let j = 0; j < hearts.length; j++) {
            hearts[j].alive = false
            const ht = heartsRep.itemAt(j)
            if (ht) ht.visible = false
        }
        aliveDrops = 0
        aliveHearts = 0
    }

    function restoreFromShatter() {
        logEvent(isShattered ? "You came back to life after shattering" : "You appeared on the screen", isShattered ? "revive" : "show")
        clearParticles()
        isShattered = false
        isDragging = false
        isWandering = false
        lastWanderDir = 0
        travelDir = 0
        entering = false
        sleeping = false
        allowWanderRotate = false
        mood = ""
        vx = 0
        vy = 0
        angle = 0
        angularVel = 0
        squash = 0
        squashVel = 0
        grounded = false
        airTime = 0
        airborne = false
        posX = Math.max(20, (width - petSize) * 0.5)
        posY = Math.max(20, (height - petSize) * 0.2)
        settled = false
        lastTick = Date.now()
        visible = true
    }

    function finishShatter() {
        clearParticles()
        if (fullRestartAfterShatter) {
            visible = false
            restartShell()
        } else {
            visible = false
        }
    }

    // ───────────────────────── бульбашка, таймер, дії ─────────────────────────
    function say(text, ms) {
        const t = String(text === undefined ? "" : text).trim()
        if (t.length === 0 || isShattered) return
        bubbleText = t
        bubbleOn = true
        bubbleTimer.interval = (ms > 0) ? ms : Math.min(10000, 2200 + t.length * 60)
        bubbleTimer.restart()
    }

    function fmtTime(ms, ceilIt) {
        const total = Math.max(0, ceilIt ? Math.ceil(ms / 1000) : Math.floor(ms / 1000))
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        const p = (n) => (n < 10 ? "0" : "") + n
        return h > 0 ? (h + ":" + p(m) + ":" + p(s)) : (p(m) + ":" + p(s))
    }

    function startTimer(minutes) {
        let min = Number(minutes)
        if (!(min > 0)) min = 25
        const now = Date.now()
        timerMode = "countdown"
        timerStartMs = now
        timerEndMs = now + min * 60000
        timerNow = now
        logEvent("The user set a timer for " + min + " minutes", "timer")
        say("Timer set for " + (Math.round(min) === min ? min : min.toFixed(1)) + " min")
    }

    function toggleStopwatch() {
        const now = Date.now()
        if (timerMode === "stopwatch") {
            const el = now - timerStartMs
            timerMode = ""
            logEvent("The user stopped the stopwatch at " + fmtTime(el, false), "stopwatch")
            say("Stopwatch: " + fmtTime(el, false), 6000)
        } else {
            timerMode = "stopwatch"
            timerStartMs = now
            timerNow = now
            logEvent("The user started a stopwatch", "stopwatch")
            say("Stopwatch started")
        }
    }

    function stopTimer() {
        if (timerMode === "") return
        timerMode = ""
        logEvent("The user cancelled the timer", "timer")
        say("Cancelled")
    }

    function finishTimer() {
        timerMode = ""
        logEvent("The timer went off", "timer")
        sleeping = false
        if (visible && !isShattered) {
            say("Time's up!", 12000)
            startDance()
            spawnHearts(6)
            sfx("onTimer")
        }
        Quickshell.execDetached(["sh", "-c",
            'command -v notify-send >/dev/null 2>&1 && notify-send -a "$1" "Timer" "Time is up!"; exit 0',
            "sh", win.petName])
    }

    function startDance() {
        if (isShattered || isDragging) return
        sleeping = false
        mood = "dance"
        logEvent("You are dancing", "dance")
        danceBeats = 0
        moodTimer.stop()
        danceTimer.restart()
        settled = false
    }

    function sleep() {
        if (isShattered || isDragging) return
        if (!sleeping) logEvent("You fell asleep", "sleep")
        sleeping = true
        isWandering = false
        travelDir = 0
        allowWanderRotate = false
        mood = ""
        danceTimer.stop()
        settled = false
    }

    function wake() {
        if (!sleeping) return
        logEvent("You woke up", "wake")
        sleeping = false
        idleTime = 0
        settled = false
    }

    function hop() {
        if (isShattered || isDragging) return
        wake()
        if (grounded) {
            vy = -560
            grounded = false
        }
        squashVel += 3
        settled = false
    }

    function flip() {
        if (isShattered || isDragging) return
        wake()
        logEvent("You did a backflip", "flip")
        isWandering = false
        vy = -460
        grounded = false
        angularVel = (Math.random() < 0.5 ? -1 : 1) * (540 + Math.random() * 300)
        squashVel += 3
        settled = false
    }

    // Чи є куди перебігати (існуючі воркспейси зліва/справа від поточного)
    function canTravel(dir) {
        try {
            const cur = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : undefined
            if (cur === undefined) return true
            const list = Hyprland.workspaces.values
            for (let i = 0; i < list.length; i++) {
                const id = list[i].id
                if (id > 0 && (dir > 0 ? id > cur : id < cur)) return true
            }
            return false
        } catch (e) {
            return true
        }
    }

    function startTravel(dirWanted) {
        if (isShattered || isDragging || sleeping || !grounded || isWandering) return false
        const dirs = []
        if (dirWanted !== 1 && canTravel(-1)) dirs.push(-1)
        if (dirWanted !== -1 && canTravel(1)) dirs.push(1)
        if (dirs.length === 0) return false
        const td = dirs[Math.floor(Math.random() * dirs.length)]
        travelDir = td
        lastWanderDir = td
        wanderTargetX = td > 0 ? width - petSize : 0
        allowWanderRotate = false
        isWandering = true
        settled = false
        return true
    }

    // Дійшла до краю: перемикаємо стіл і виходить з протилежного боку
    function crossWorkspace(dir) {
        travelDir = 0
        lastWsSwitch = Date.now()
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", dir > 0 ? "e+1" : "e-1"])
        logEvent("You ran to the " + (dir > 0 ? "next" : "previous") + " workspace on your own", "travel")
        platforms = []
        posX = dir > 0 ? 0 : width - petSize
        facingLeft = dir < 0
        lastWanderDir = dir
        wanderTargetX = clamp(posX + dir * (140 + Math.random() * 260), 0, width - petSize)
        allowWanderRotate = false
        isWandering = true
        settled = false
        sfx("onTravel")
    }

    // Ти перемкнув стіл: Мімі вибігає на новий із того боку, звідки він "приїхав"
    function enterFromEdge(dir) {
        // dir > 0 — перейшов на стіл з більшим номером, dir < 0 — з меншим.
        // Менший номер -> вона вибігає з ПРАВОГО краю, більший -> з ЛІВОГО.
        sleeping = false
        isWandering = false
        allowWanderRotate = false
        travelDir = 0
        mood = ""
        danceTimer.stop()
        platforms = []
        standPlat = null

        const fromRight = (dir < 0) !== enterInvert
        // стартує повністю за межею екрана (+ offset) і заходить усередину
        posX = fromRight ? (width + enterOffsetR) : (-petSize - enterOffsetL)
        posY = height - contactH
        vx = 0
        vy = 0
        angle = 0
        angularVel = 0
        grounded = true
        airTime = 0
        airborne = false
        entering = true

        const walkDir = fromRight ? -1 : 1
        facingLeft = walkDir < 0
        lastWanderDir = walkDir
        wanderTargetX = clamp(fromRight ? width - petSize - (60 + Math.random() * 260)
                                        : 60 + Math.random() * 260, 0, width - petSize)
        isWandering = true
        settled = false
    }

    function onWorkspaceSwitched() {
        let id
        try {
            const ws = Hyprland.focusedWorkspace
            if (!ws) return
            id = ws.id
            if (ws.monitor && ws.monitor.name && win.screen && win.screen.name && ws.monitor.name !== win.screen.name) return
        } catch (e) {
            return
        }
        if (id === lastWsId) return
        const old = lastWsId
        lastWsId = id
        if (!wsEnter || old === undefined || id <= 0 || old <= 0) return
        if (!visible || isShattered || isDragging) return
        if (Date.now() - lastWsSwitch < 900) return   // це ми самі її перенесли (кидок / власний перебіг)
        logEvent("The user switched from workspace " + old + " to " + id + " and you ran after them", "workspace")
        enterFromEdge(id > old ? 1 : -1)
    }

    function doAction(act) {
        const s = String(act === undefined ? "" : act)
        const i = s.indexOf(":")
        const name = (i >= 0 ? s.slice(0, i) : s).trim()
        const arg = i >= 0 ? s.slice(i + 1).trim() : ""

        if (name === "hide") {
            // «Сховати» — просто сховати, без анімації розбивання (раніше в хардкор-режимі вона вмикалась і тут)
            logEvent("The user hid you", "hide")
            visible = false
        }
        else if (name === "restart") restartShell()
        else if (name === "quit") Qt.quit()
        else if (name === "poke") poke()
        else if (name === "dance") startDance()
        else if (name === "sleep") sleep()
        else if (name === "wake") wake()
        else if (name === "hop") hop()
        else if (name === "flip") flip()
        else if (name === "shatter") triggerShatter(0, -300, "the user smashed you with a command")
        else if (name === "say") say(arg)
        else if (name === "timer") startTimer(parseFloat(arg))
        else if (name === "stopwatch") toggleStopwatch()
        else if (name === "stoptimer") stopTimer()
        else if (name === "chat") openChat()
        // очистити історію чату (і chat_history.json): "forget", "deleteHistory" або "clearHistory"
        else if (name === "forget" || name === "deleteHistory" || name === "clearHistory") {
            petBrain.forget()
            say("Chat history cleared.")
        }
        else if (name === "ask") petBrain.chat(arg)
        else if (name === "look") petBrain.look("", true)
        else if (name === "run") petBrain.runCommand(arg)
        else if (name === "travel") {
            const d = arg === "left" ? -1 : (arg === "right" ? 1 : 0)
            if (!startTravel(d)) say("Nowhere to go.")
        }
    }

    function poke() {
        if (isShattered || isDragging) return
        wake()
        danceTimer.stop()
        mood = "happy"
        moodTimer.restart()
        if (grounded) {
            vy = -380
            grounded = false
        }
        squashVel += 3.2
        settled = false
        spawnHearts(5)
        sfx("onPoke")
        logEvent("The user petted you", "poke")
    }

    // ───────────────────────── сердечка ─────────────────────────
    function spawnHearts(count) {
        spawnGlyphs(count, "♥", heartColor)
    }

    function spawnGlyphs(count, glyph, col) {
        if (!heartsEnabled) return
        for (let i = 0; i < count; i++) {
            let idx = -1
            for (let k = 0; k < hearts.length; k++) {
                if (!hearts[k].alive) { idx = k; break }
            }
            if (idx < 0) return
            const life = 1.0 + Math.random() * 0.8
            hearts[idx] = {
                alive: true,
                x: posX + petSize * (0.2 + Math.random() * 0.6),
                y: posY + petSize * 0.2,
                vx: (Math.random() - 0.5) * 50,
                vy: -(70 + Math.random() * 70),
                life: life, max: life,
                size: 14 + Math.random() * 14,
                ph: Math.random() * 6.28,
                glyph: glyph, col: col
            }
        }
        aliveHearts = Math.max(aliveHearts, 1)
    }

    function stepHearts(dt) {
        if (aliveHearts <= 0) return
        let alive = 0
        for (let i = 0; i < hearts.length; i++) {
            const h = hearts[i]
            if (!h.alive) continue
            const it = heartsRep.itemAt(i)
            h.life -= dt
            if (h.life <= 0) {
                h.alive = false
                if (it) it.visible = false
                continue
            }
            alive++
            h.x += (h.vx + Math.sin(h.life * 6 + h.ph) * 22) * dt
            h.y += h.vy * dt
            h.vy *= Math.pow(0.985, dt * 60)
            if (it) {
                it.x = h.x
                it.y = h.y
                it.sz = h.size
                it.glyph = h.glyph
                it.col = h.col
                it.scale = Math.min(1, (h.max - h.life) / 0.16)
                it.opacity = Math.min(1, h.life / 0.5)
                it.visible = true
            }
        }
        aliveHearts = alive
    }

    // ───────────────────────── краплі ─────────────────────────
    function spawnDrop(x, y, baseVx, baseVy) {
        if (!splatterEnabled || dropsPerPiece <= 0 || drops.length === 0) return
        let idx = -1
        for (let k = 0; k < maxDrops; k++) {
            const j = (dropCursor + k) % maxDrops
            if (!drops[j].alive) { idx = j; break }
        }
        if (idx < 0) idx = dropCursor
        dropCursor = (idx + 1) % maxDrops

        const r = 3 + Math.random() * 5
        const life = dropLifetimeSec * (0.75 + Math.random() * 0.5)
        drops[idx] = {
            alive: true, stuck: false,
            x: x, y: y,
            vx: (baseVx || 0) * 0.25 + (Math.random() - 0.5) * 140 * burstForce,
            vy: (baseVy || 0) * 0.2 - 60 * burstForce - Math.random() * 110 * burstForce,
            r: r, w: r * 2, h: r * 2,
            life: life, max: life
        }
        aliveDrops = Math.max(aliveDrops, 1)
    }

    function stepDrops(dt) {
        if (aliveDrops <= 0) return
        let alive = 0
        const damp = Math.pow(0.985, dt * 60)
        for (let i = 0; i < drops.length; i++) {
            const d = drops[i]
            if (!d.alive) continue
            const it = dropsRep.itemAt(i)
            d.life -= dt
            if (d.life <= 0) {
                d.alive = false
                if (it) it.visible = false
                continue
            }
            alive++
            if (!d.stuck) {
                d.vy += gravity * 0.9 * dt
                d.vx *= damp
                d.x += d.vx * dt
                d.y += d.vy * dt
                if (d.y + d.h >= height) {
                    d.stuck = true
                    d.vx = 0
                    d.vy = 0
                    d.w = d.r * 2.6
                    d.h = Math.max(2, d.r * 0.6)
                    d.y = height - d.h
                }
            }
            if (it) {
                const ratio = clamp(d.life / Math.min(d.max * 0.35, 0.8), 0, 1)
                it.x = d.x
                it.y = d.y
                it.width = d.w
                it.height = d.h
                it.radius = d.stuck ? 2 : d.r
                it.opacity = 0.92 * ratio
                it.visible = true
            }
        }
        aliveDrops = alive
    }

    // ───────────────────────── розліт на шматочки ─────────────────────────
    function playShatterSound() {
        if (sndCfg.onShatter) { petAudio.play(sndCfg.onShatter); return }
        if (hardCfg.shatterSound) { petAudio.play(hardCfg.shatterSound); return }
        if (sndCfg.onThrow) petAudio.play(sndCfg.onThrow)
    }

    function triggerShatter(impactVx, impactVy, cause) {
        if (isShattered) return
        const sp = Math.round(Math.hypot(impactVx || 0, impactVy || 0))
        logEvent("You died — you shattered into pieces"
                 + (cause ? ": " + cause : (sp > 0 ? " (impact at " + sp + " px/s)" : "")), "death")
        isShattered = true
        isDragging = false
        isWandering = false
        travelDir = 0
        allowWanderRotate = false
        petMenu.visible = false
        danceTimer.stop()

        shatterSource = petSprite.sourceNow()
        shatterFlip = petBody.spriteMirrored

        const rawCount = num(hardCfg, "pieceCount", 12)
        const want = Math.max(1, Math.floor(rawCount))
        const cols = hardCfg.cols !== undefined ? Math.max(1, Math.floor(num(hardCfg, "cols", 3))) : Math.ceil(Math.sqrt(want))
        const rows = hardCfg.rows !== undefined ? Math.max(1, Math.floor(num(hardCfg, "rows", 3))) : Math.ceil(want / cols)
        const total = cols * rows

        const pw = petSize / cols
        const ph = petSize / rows
        const ang = angle * Math.PI / 180
        const cs = Math.cos(ang)
        const sn = Math.sin(ang)
        const cx = posX + petSize / 2
        const cy = posY + petSize / 2

        const baseVx = (impactVx || 0) * 0.35 * burstForce
        const baseVy = (impactVy || 0) * 0.35 * burstForce

        const arr = []
        const info = []
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                // центр шматочка відносно центру кішки, повернутий разом із нею
                const ox = (c + 0.5) * pw - petSize / 2
                const oy = (r + 0.5) * ph - petSize / 2
                const px = cx + ox * cs - oy * sn - pw / 2
                const py = cy + ox * sn + oy * cs - ph / 2

                const dirX = (c + 0.5 - cols * 0.5)
                const dirY = (r + 0.5 - rows * 0.5)
                const burst = (200 + Math.random() * 380) * burstForce

                const svx = baseVx + dirX * burst + (Math.random() - 0.5) * 160 * burstForce
                const svy = baseVy + dirY * burst - 200 * burstForce

                arr.push({
                    x: px, y: py, w: pw, h: ph,
                    vx: svx, vy: svy,
                    a: angle, av: (Math.random() - 0.5) * 850 * burstForce + angularVel * 0.5,
                    acc: Math.random() * 0.08
                })
                info.push({ w: pw, h: ph, sx: c * pw, sy: r * ph })

                for (let b = 0; b < dropsPerPiece; b++) {
                    spawnDrop(px + pw * 0.5, py + ph * 0.5, svx, svy)
                }
            }
        }
        pieces = arr
        pieceInfo = info
        pieceCount = total

        shatterAge = 0
        shatterLife = Math.max(0.6, num(hardCfg, "pieceLifetimeMs", 3500) / 1000.0)
        playShatterSound()
    }

    function stepPieces(dt) {
        if (pieceCount <= 0) return
        const fadeSpan = shatterLife * 0.35
        const alpha = clamp((shatterLife - shatterAge) / fadeSpan, 0, 1)
        const trail = shatterAge < 1.2 && splatterEnabled && dropsPerPiece > 0
        const g = gravity * 0.85
        const damp = Math.pow(0.992, dt * 60)

        for (let i = 0; i < pieces.length; i++) {
            const p = pieces[i]
            p.vy += g * dt
            p.vx *= damp
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.a += p.av * dt

            if (p.y + p.h >= height) {
                p.y = height - p.h
                p.vy = Math.abs(p.vy) < 60 ? 0 : -p.vy * 0.45
                p.vx *= 0.85
                p.av *= 0.8
            }
            if (p.y <= 0) { p.y = 0; p.vy = Math.abs(p.vy) * 0.6 }
            if (p.x <= 0) { p.x = 0; p.vx = Math.abs(p.vx) * 0.75 }
            else if (p.x + p.w >= width) { p.x = width - p.w; p.vx = -Math.abs(p.vx) * 0.75 }

            if (trail) {
                p.acc += dt
                if (p.acc >= 0.09) {
                    p.acc = 0
                    if (Math.random() < 0.6) spawnDrop(p.x + p.w * 0.5, p.y + p.h * 0.5, p.vx, p.vy)
                }
            }

            const it = piecesRep.itemAt(i)
            if (it) {
                it.x = p.x
                it.y = p.y
                it.rotation = p.a
                it.opacity = alpha
            }
        }
    }

    // ───────────────────────── платформи з вікон Hyprland ─────────────────────────
    function refreshPlatforms() {
        if (!platEnabled || !visible || isShattered) {
            if (platforms.length > 0) platforms = []
            return
        }
        try {
            Hyprland.refreshMonitors()
            Hyprland.refreshToplevels()

            const mon = Hyprland.monitorFor(win.screen)
            const mi = (mon && mon.lastIpcObject) ? mon.lastIpcObject : ({})
            const ox = Number(mi.x) || 0
            const oy = Number(mi.y) || 0
            const wsId = (mi.activeWorkspace && mi.activeWorkspace.id !== undefined) ? mi.activeWorkspace.id : undefined
            const monId = mi.id

            const list = Hyprland.toplevels.values
            const out = []
            for (let i = 0; i < list.length; i++) {
                const o = list[i].lastIpcObject
                if (!o || !o.at || !o.size) continue
                if (o.mapped === false || o.hidden === true) continue
                if (wsId !== undefined && o.workspace && o.workspace.id !== wsId) continue
                if (monId !== undefined && o.monitor !== undefined && o.monitor !== monId) continue

                const px = o.at[0] - ox
                const py = o.at[1] - oy
                const pw = o.size[0]
                if (pw < petSize * 0.6) continue
                // платформа має бути достатньо низько, щоб кішка на ній поміщалась
                if (py < petSize + 4 || py > height - 8) continue
                out.push({ x: px, y: py, w: pw })
            }
            platforms = out
        } catch (e) {
            platforms = []
        }
    }

    function overPlatform(p) {
        if (platEdgeFall) {
            const c = posX + petSize / 2
            return c >= p.x && c <= p.x + p.w
        }
        return !(posX + petSize * 0.75 <= p.x || posX + petSize * 0.25 >= p.x + p.w)
    }

    function surfaceBelow() {
        let y = height
        const bottom = posY + contactH
        for (let i = 0; i < platforms.length; i++) {
            const p = platforms[i]
            if (!overPlatform(p)) continue
            if (p.y >= bottom - 12 && p.y < y) y = p.y
        }
        shadowY = y
    }

    // ───────────────────────── швидкість перетягування ─────────────────────────
    function pushSample(x, y) {
        const t = Date.now()
        dragSamples.push({ t: t, x: x, y: y })
        pruneSamples(t)
    }

    function pruneSamples(now) {
        while (dragSamples.length > 0 && now - dragSamples[0].t > 110) dragSamples.shift()
    }

    // Швидкість у px/с за реальним часом — не залежить від частоти опитування миші.
    function sampleVelocity() {
        const now = Date.now()
        pruneSamples(now)
        const s = dragSamples
        if (s.length < 2) return { x: 0, y: 0 }
        const a = s[0]
        const c = s[s.length - 1]
        if (now - c.t > 70) return { x: 0, y: 0 }           // курсор вже зупинився
        const span = (c.t - a.t) / 1000
        if (span < 0.008) return { x: 0, y: 0 }
        return { x: (c.x - a.x) / span, y: (c.y - a.y) / span }
    }

    // ───────────────────────── головний цикл фізики ─────────────────────────
    function step(dt) {
        if (width < 10 || height < 10) return

        stepDrops(dt)
        stepHearts(dt)

        if (isShattered) {
            shatterAge += dt
            stepPieces(dt)
            if (shatterAge >= shatterLife) finishShatter()
            return
        }

        // пружина стиснення
        squashVel += (-420 * squash - 18 * squashVel) * dt
        squash = clamp(squash + squashVel * dt, -0.4, 0.4)

        const wasGrounded = grounded
        if (isDragging) stepDrag(dt)
        else stepFree(dt)

        // запам'ятати, з чого почався політ і з якої висоти
        if (isDragging) {
            flightCause = ""
        } else if (!grounded) {
            if (wasGrounded && flightCause === "") {
                flightCause = vy < -50 ? "jump" : "fall"
                peakY = posY
            }
            peakY = Math.min(peakY, posY)
        } else {
            flightCause = ""
        }

        // куди дивиться кішка
        if (isDragging) {
            if (Math.abs(dragVx) > 150) facingLeft = dragVx < 0
        } else if (Math.abs(vx) > 12) {
            facingLeft = vx < 0
        }

        if (entering && !isWandering) entering = false

        const nowAir = airTime > 0.12
        if (nowAir !== airborne) airborne = nowAir

        if (shadowEnabled) surfaceBelow()

        if (sleepAfterSec > 0 && !sleeping) {
            if (grounded && vx === 0 && !isWandering && !isDragging && mood === "") {
                idleTime += dt
                if (idleTime >= sleepAfterSec) sleep()
            } else {
                idleTime = 0
            }
        }

        settled = !isDragging && grounded && vx === 0 && !isWandering
            && Math.abs(angularVel) < 0.5 && Math.abs(angle) < 0.05
            && Math.abs(squash) < 0.003 && Math.abs(squashVel) < 0.05
            && aliveDrops === 0 && aliveHearts === 0
    }

    function stepDrag(dt) {
        const dv = sampleVelocity()
        const k = Math.min(1, dt * 14)
        dragVx += (dv.x - dragVx) * k
        dragVy += (dv.y - dragVy) * k

        // кішка "висить" на курсорі й нахиляється в бік руху
        const target = clamp(dragVx * 0.012 * spinK, -38, 38)
        angularVel += ((target - angle) * 240 - angularVel * 18) * dt
        angle += angularVel * dt

        posX = clamp(posX, 0, width - petSize)
        posY = clamp(posY, 0, height - contactH)
        grounded = false
        airTime = 0
    }

    function stepFree(dt) {
        const pw = petSize

        // ── горизонтальний рух ──
        if (isWandering) {
            const rem = wanderTargetX - posX
            if (Math.abs(rem) < 8 && grounded) {
                isWandering = false
                allowWanderRotate = false
                vx = 0
                if (travelDir !== 0) crossWorkspace(travelDir)
            } else {
                const sp = travelDir !== 0 ? travelSpeed : (entering ? enterSpeed : num(wanderCfg, "speed", 140))
                const want = (rem > 0 ? 1 : -1) * sp
                const accel = (grounded ? 2400 : 900) * dt
                vx = Math.abs(want - vx) <= accel ? want : vx + (want > vx ? accel : -accel)
            }
        } else {
            vx *= Math.pow(grounded ? groundFriction : airDrag, dt * 60)
            if (grounded && Math.abs(vx) < 4) vx = 0
        }

        vy = Math.min(vy + gravity * dt, 3600)
        posX += vx * dt
        posY += vy * dt

        grounded = false
        standPlat = null

        // ── підлога / платформи ──
        let floorY = height
        let plat = null
        const bottom = posY + contactH
        if (platEnabled && vy >= 0 && platforms.length > 0) {
            let bestDepth = 1e9
            for (let i = 0; i < platforms.length; i++) {
                const p = platforms[i]
                if (!overPlatform(p)) continue
                const depth = bottom - p.y
                if (depth >= 0 && depth <= vy * dt + 10 && depth < bestDepth) {
                    bestDepth = depth
                    plat = p
                }
            }
            if (plat) floorY = plat.y
        }

        if (bottom >= floorY) {
            posY = floorY - contactH
            if (vy > 90) {
                const impact = vy
                if (shatterOnFloor && !peaceful && impact >= shatterSpeed) {
                    triggerShatter(vx, impact, impactCause(plat ? "window" : "floor", impact))
                    return
                }
                vy = -impact * floorBounce
                vx *= 0.75
                if (!isWandering || allowWanderRotate) angularVel += vx * 0.45 * spinK
                squashVel += Math.min(impact * 0.0075, 9)
                if (impact > 650) sfx("onLand")
                if (impact > 1100) logEvent("You landed hard: " + impactCause(plat ? "window" : "floor", impact), "land")
            } else {
                vy = 0
                grounded = true
                standPlat = plat
            }
        }

        // ── стеля ──
        if (posY <= 0) {
            posY = 0
            if (vy < 0) {
                const hitUp = -vy
                if (!peaceful && hitUp >= shatterSpeed) {
                    triggerShatter(vx, vy, impactCause("ceiling", hitUp))
                    return
                }
                vy = hitUp * ceilingBounce
                angularVel += vx * 0.35 * spinK
                squashVel += Math.min(hitUp * 0.004, 5)
            }
        }

        // ── стіни ──
        if (entering) {
            if (posX >= 0 && posX + pw <= width) entering = false
        } else if (posX <= 0) {
            posX = 0
            if (vx < 0) {
                const hitL = -vx
                if (!peaceful && hitL >= shatterSpeed) {
                    triggerShatter(vx, vy, impactCause("left wall", hitL))
                    return
                }
                if (isWandering) {
                    isWandering = false
                    allowWanderRotate = false
                    vx = 0
                    if (travelDir !== 0) crossWorkspace(travelDir)
                } else if (hitL > 30) {
                    vx = hitL * wallBounce
                    angularVel -= hitL * 0.3 * spinK
                } else {
                    vx = 0
                }
            }
        } else if (posX + pw >= width) {
            posX = width - pw
            if (vx > 0) {
                const hitR = vx
                if (!peaceful && hitR >= shatterSpeed) {
                    triggerShatter(vx, vy, impactCause("right wall", hitR))
                    return
                }
                if (isWandering) {
                    isWandering = false
                    allowWanderRotate = false
                    vx = 0
                    if (travelDir !== 0) crossWorkspace(travelDir)
                } else if (hitR > 30) {
                    vx = -hitR * wallBounce
                    angularVel += hitR * 0.3 * spinK
                } else {
                    vx = 0
                }
            }
        }

        airTime = grounded ? 0 : airTime + dt

        // ── обертання ──
        if (grounded && isWandering && allowWanderRotate) {
            // котиться, поки йде
            const want = lastWanderDir * 160
            angularVel += (want - angularVel) * Math.min(1, dt * 6)
        } else if (grounded) {
            // на землі пружинить до найближчого "вертикального" положення
            const target = Math.round(angle / 360) * 360
            angularVel += ((target - angle) * 200 - angularVel * 14) * dt
            if (Math.abs(angularVel) < 2 && Math.abs(angle - target) < 0.4) {
                angle = 0
                angularVel = 0
            }
        } else {
            angularVel *= Math.pow(spinDamping, dt * 60)
        }
        angle += angularVel * dt
    }

    // ───────────────────────── таймери ─────────────────────────
    Timer {
        id: loop
        // коли кішка спокійно сидить — працюємо рідше, щоб не гріти ноут
        interval: win.settled ? 50 : 16
        repeat: true
        running: win.visible
        onTriggered: {
            const now = Date.now()
            const dt = Math.max(0.001, Math.min(0.05, (now - win.lastTick) / 1000))
            win.lastTick = now
            win.step(dt)
        }
    }

    // тримають на місці довше за "клік" — це вже підхопили
    Timer {
        id: pickSoundTimer
        interval: 350
        onTriggered: if (win.isDragging) win.playPickSound()
    }

    Timer {
        id: moodTimer
        interval: 1500
        repeat: false
        onTriggered: win.mood = ""
    }

    Timer {
        id: platTimer
        interval: win.platRefreshMs
        repeat: true
        running: win.platEnabled && win.visible && !win.isShattered
        triggeredOnStart: true
        onTriggered: win.refreshPlatforms()
        onRunningChanged: if (!running && win.platforms.length > 0) win.platforms = []
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { win.onWorkspaceSwitched() }
    }

    NumberAnimation {
        id: enterAnim
        target: win
        property: "enterOpacity"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutQuad
    }

    Timer {
        id: bubbleTimer
        repeat: false
        onTriggered: win.bubbleOn = false
    }

    // оновлення таймера/секундоміра
    Timer {
        interval: 250
        repeat: true
        running: win.timerMode !== ""
        onTriggered: {
            win.timerNow = Date.now()
            if (win.timerMode === "countdown" && win.timerNow >= win.timerEndMs) win.finishTimer()
        }
    }

    // назва треку, коли він змінився
    Timer {
        id: trackTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (win.musicTrack.length > 0 && win.musicTrack !== win.lastAnnounced && !win.isShattered) {
                win.lastAnnounced = win.musicTrack
                win.logEvent("A song started playing: " + win.musicTrack, "music")
                // коментує лише справжню музику (є виконавець), а не заголовки вкладок браузера
                if (petBrain.enabled && win.brainCfg.commentTracks === true && !petBrain.busy && !win.chatOpen
                        && win.activePlayer && win.activePlayer.trackArtist)
                    petBrain.ask("The song \"" + win.musicTrack + "\" just started playing. Comment on it in one short sentence.", false)
                else
                    win.say("Now playing: " + win.musicTrack, 5000)
            }
        }
    }

    // кішка пританцьовує в такт
    Timer {
        id: musicBeat
        property int beat: 0
        interval: win.musicBeatMs
        repeat: true
        running: win.musicActive && win.visible && !win.isShattered && !win.isDragging
            && !win.sleeping && !petMenu.visible
        onTriggered: {
            if (!win.grounded || win.isWandering || win.mood !== "") return
            beat++
            win.squashVel += 2.4
            win.settled = false
            if (beat % 2 === 0) win.angularVel += (beat % 4 === 0 ? 1 : -1) * 60
            if (Math.random() < win.musicHopChance) {
                win.vy = -220
                win.grounded = false
            }
            if (beat % 3 === 0) win.spawnGlyphs(1, Math.random() < 0.5 ? "♪" : "♫", win.noteColor)
        }
    }

    // танець
    Timer {
        id: danceTimer
        interval: 340
        repeat: true
        onTriggered: {
            win.danceBeats++
            if (win.danceBeats > 12 || win.isShattered || win.isDragging) {
                stop()
                if (win.mood === "dance") win.mood = ""
                return
            }
            if (win.grounded) {
                win.vy = -300
                win.grounded = false
            }
            win.squashVel += 2
            win.angularVel += (win.danceBeats % 2 === 0 ? 1 : -1) * 140
            win.settled = false
            if (win.danceBeats % 3 === 0) win.spawnGlyphs(1, "♪", win.noteColor)
        }
    }

    // сплячка: літають "z"
    Timer {
        interval: 2200
        repeat: true
        running: win.sleeping && win.visible && !win.isShattered
        onTriggered: win.spawnGlyphs(1, "z", "#9aa5ce")
    }

    // ── утримання пета мишею → чат ──
    property real holdPx: 0
    property real holdPy: 0
    property real holdT: 0
    readonly property real holdMs: 1200          // скільки тримати пета, щоб відкрився чат (мс)
    Timer {
        id: holdChatTimer
        interval: win.holdMs
        onTriggered: win.holdToChat("timer")
    }
    function holdToChat(why) {
        console.log("[pet] утримання → чат (" + why + "), dragging=" + win.isDragging + " chatOpen=" + win.chatOpen)
        if (win.chatOpen || win.isShattered) return
        {
            // відпустити пета на місці (без кидка) і відкрити чат
            win.isDragging = false
            win.vx = 0
            win.vy = 0
            pickSoundTimer.stop()
            win.pickSoundPending = false
            win.openChat()
        }
    }
    // кільце, що заповнюється, поки тримаєш (з'являється після 0.3 с)
    Rectangle {
        id: holdRing
        z: 120
        readonly property bool on: holdChatTimer.running
        property real p: 0
        width: win.petSize * 0.9; height: width; radius: width / 2
        x: win.posX + win.petSize / 2 - width / 2
        y: win.posY + win.petSize / 2 - height / 2
        color: "transparent"
        border.width: 3
        border.color: "#f2b8d4"
        visible: opacity > 0.01
        opacity: on && p > 0.15 ? 0.35 + p * 0.6 : 0
        scale: 0.5 + p * 0.6
        Behavior on opacity { NumberAnimation { duration: 150 } }
        NumberAnimation on p { id: holdAnim; running: false; from: 0; to: 1; duration: win.holdMs }
        onOnChanged: { if (on) holdAnim.restart(); else { holdAnim.stop(); p = 0 } }
        Text {
            anchors.centerIn: parent
            text: "💬"
            font.pixelSize: 22
            opacity: holdRing.p
        }
    }

    // ───────────────────────── мозок: розмова з локальною LLM ─────────────────────────
    function openChat() {
        if (isShattered) return
        if (!petBrain.enabled) return                 // мозок вимкнений — як до його появи
        petMenu.visible = false
        isWandering = false
        wake()
        chatOpen = true
        Qt.callLater(() => chatInput.forceActiveFocus())
    }
    function closeChat() {
        if (!chatOpen) return
        chatOpen = false
        chatInput.text = ""
    }
    function sendChat() {
        const t = chatInput.text.trim()
        if (!t.length) return
        chatInput.text = ""
        // одразу відпустити клавіатуру й екран: відповідь буде в бульбашці, а решта робочого столу
        // працює без зайвого кліку (раніше поле лишалось відкритим і перехоплювало все)
        closeChat()
        petBrain.chat(t)
    }
    // ── вільна воля ──
    function nextFreeWillMs() {
        const r = autoCfg.intervalMs
        const lo = Math.max(20000, Number(r && r[0]) || 90000)
        const hi = Math.max(lo + 1000, Number(r && r[1]) || 300000)
        return Math.floor(lo + Math.random() * (hi - lo))
    }

    // що зараз узагалі має сенс (прокинутись — лише якщо спить, бігти — лише якщо є куди...)
    function availableActions() {
        return petBrain.allowedActions.filter(a => {
            if (a === "wake") return sleeping
            if (sleeping) return a === "wake" || a === "nothing" || a === "say"
            if (a === "sleep") return !sleeping
            if (a === "travel") return grounded && (canTravel(-1) || canTravel(1))
            if (a === "hop" || a === "flip" || a === "dance") return grounded
            if (a === "look") return petBrain.lookEnabled
            return true
        })
    }

    function situation() {
        const parts = ["It is " + Qt.formatTime(new Date(), "hh:mm") + "."]
        if (musicActive) parts.push("Music is playing: \"" + musicTrack + "\".")
        if (sleeping) parts.push("You are asleep.")
        if (standPlat) parts.push("You are sitting on top of a window.")
        if (timerMode !== "") parts.push("A " + (timerMode === "countdown" ? "timer" : "stopwatch") + " is running.")
        return parts.join(" ")
    }

    // виконати рішення (з вільної волі або з тегу в розмові)
    function performChoice(action, phrase, source, arg) {
        const a = String(action || "").toLowerCase()
        if (a === "run") {                                             // програма зі списку brain.commands
            if (!petBrain.runCommand(arg)) return false
            return true
        }
        if (petBrain.allowedActions.indexOf(a) < 0) return false      // поза білим списком — ні
        const p = String(phrase || "").trim()
        const what = petBrain.actionNamesUk[a] || a
        logEvent("You decided on your own to " + (petBrain.actionDesc[a] || a) + (p.length ? " and said \"" + p + "\"" : ""), "will")
        if (a === "say" || a === "nothing") {
            if (p.length) say(p)
            return true
        }
        // у розмові фразу вже сказала сама відповідь; у вільній волі без фрази — коротка репліка про дію
        const line = p.length ? p : (source === "chat" ? "" : petBrain.actionLine(a, ""))
        if (a === "look") {
            if (line.length) say(line)
            petBrain.look(source === "chat" ? "" : "You decided on your own to peek at the user's screen.")
            return true
        }
        doAction(a)
        if (line.length) say(line)
        return true
    }

    function randomChoice(list) {
        const acts = list.filter(a => a !== "say")
        return acts.length ? acts[Math.floor(Math.random() * acts.length)] : ""
    }

    function nextChatterMs() {
        const r = chatterCfg.intervalMs
        const lo = Math.max(30000, Number(r && r[0]) || 300000)
        const hi = Math.max(lo + 1000, Number(r && r[1]) || 900000)
        return Math.floor(lo + Math.random() * (hi - lo))
    }

    PetBrain {
        id: petBrain
        cfg: win.cfg
        canDo: function(a) { return win.availableActions().indexOf(a) >= 0 }
    }

    // Вільна воля: раз на кілька хвилин сама вирішує, чим зайнятися
    Timer {
        id: freeWillTimer
        repeat: true
        running: win.autoEnabled && win.visible && !win.isShattered && !win.isDragging
            && !win.chatOpen && !petMenu.visible
        interval: win.nextFreeWillMs()
        onTriggered: {
            interval = win.nextFreeWillMs()
            if (petBrain.busy || petBrain.deciding || win.isWandering || !win.grounded && !win.sleeping) return
            const acts = win.availableActions()
            if (!acts.length) return
            win.pendingActions = acts
            petBrain.decide(win.situation(), acts)
        }
    }
    property var pendingActions: []

    Connections {
        target: petBrain
        // рішення моделі; якщо вона мовчить/помилилась — навмання (brain.autonomy.fallbackRandom)
        function onDecided(choice) {
            if (win.isShattered || win.isDragging || win.chatOpen) return
            if (choice && win.pendingActions.indexOf(choice.action) >= 0) win.performChoice(choice.action, choice.say, "will")
            else if (win.autoFallbackRandom) win.performChoice(win.randomChoice(win.pendingActions), "", "random")
        }
        // теги [dance] у відповіді в розмові — трохи згодом, щоб спершу встигла показатись відповідь
        function onWants(actions) {
            // попросили глянути на екран — скрін із її ж питанням, незалежно від автономії
            if (actions.some(t => t.action === "look") && petBrain.lookEnabled) {
                Qt.callLater(() => petBrain.look(petBrain.lastUserText, true))
                return
            }
            const avail = win.availableActions()
            const ok = actions.filter(t => t.action === "run" || avail.indexOf(t.action) >= 0)
            if (ok.length) Qt.callLater(() => win.performChoice(ok[0].action, "", "chat", ok[0].arg))
        }
        function onLaunched(name) {
            win.logEvent("You opened " + name + " for the user", "run")
        }
        function onLooked() {
            win.logEvent("You looked at the user's screen", "look")
        }
    }

    Connections {
        target: petBrain
        function onStarted() {
            win.say("...", 120000)
            win.spawnGlyphs(1, "?", win.noteColor)
        }
        function onChunk(text) { if (text.length) win.say(text, 120000) }
        function onFinished(text) {
            win.say(text, Math.min(20000, 3000 + text.length * 70))
            win.sfx("onAnswer")
        }
        function onFailed(reason) { win.say("Error: " + reason, 9000) }
        function onSearching(q) { win.say(q.length ? "🔎 шукаю: " + q + "…" : "🔎 читаю сторінку…", 120000) }
    }

    // іноді щось каже сама (brain.chatter.enabled)
    Timer {
        id: chatterTimer
        repeat: true
        running: petBrain.enabled && win.chatterCfg.enabled === true && win.visible
            && !win.isShattered && !win.chatOpen && !win.sleeping
        interval: win.nextChatterMs()
        onTriggered: {
            interval = win.nextChatterMs()
            if (petBrain.busy || win.bubbleOn || win.isDragging) return
            petBrain.ask("Say something short and cute on your own, without asking the user anything. It is "
                + Qt.formatTime(new Date(), "hh:mm")
                + (win.musicActive ? " and \"" + win.musicTrack + "\" is playing" : "") + ".", false)
        }
    }

    PetAudio {
        id: petAudio
        cfg: win.cfg
    }

    Timer {
        id: randomReactionTimer
        repeat: true
        running: win.visible && !win.isShattered && !win.isDragging && !petMenu.visible
            && !win.sleeping && win.reactionFiles().length > 0
        interval: win.nextReactionIntervalMs()

        onTriggered: {
            interval = win.nextReactionIntervalMs()
            const list = win.reactionFiles()
            if (list.length === 0) return

            let idx = Math.floor(Math.random() * list.length)
            if (list.length > 1 && idx === win.lastReactionIndex) {
                idx = (idx + 1 + Math.floor(Math.random() * (list.length - 1))) % list.length
            }
            win.lastReactionIndex = idx

            const rr = win.sndCfg.randomReactions
            const itemVol = (rr && !petAudio.isList(rr) && rr.volume !== undefined) ? Number(rr.volume) : petAudio.soundVolume
            petAudio.playIfIdle({
                volume: isNaN(itemVol) ? petAudio.soundVolume : itemVol,
                files: [list[idx]]
            })
        }
    }

    Timer {
        id: wanderTimer
        repeat: true
        running: win.visible && !win.isShattered && !win.isDragging && !petMenu.visible
            && !win.sleeping && !win.chatOpen && win.flag(win.wanderCfg, "enabled", true)
        interval: win.nextWanderIntervalMs()

        onTriggered: {
            interval = win.nextWanderIntervalMs()
            if (!win.grounded || win.isWandering || win.sleeping) return

            // іноді вирушає на інший стіл
            if (win.travelEnabled && !win.standPlat && Math.random() < win.travelChance) {
                if (win.startTravel(0)) return
            }

            const pw = win.petSize
            let lo = 20
            let hi = Math.max(lo + 40, win.width - pw - 20)

            // на платформі найчастіше гуляємо в її межах
            const sp = win.standPlat
            if (sp && Math.random() >= win.platWanderOffChance) {
                // межі, у яких кішка ще має опору (з невеликим запасом від краю)
                const inLo = win.platEdgeFall ? sp.x - pw * 0.4 : sp.x - pw * 0.1
                const inHi = win.platEdgeFall ? sp.x + sp.w - pw * 0.6 : sp.x + sp.w - pw * 0.9
                const plo = Math.max(lo, inLo)
                const phi = Math.min(hi, inHi)
                if (phi - plo > 40) { lo = plo; hi = phi }
            }

            // напрямок: від стінки, інакше найчастіше змінюємо попередній
            let dir = Math.random() < 0.5 ? -1 : 1
            if (win.posX < lo + 80) dir = 1
            else if (win.posX > hi - 80) dir = -1
            else if (win.lastWanderDir !== 0 && Math.random() < 0.6) dir = -win.lastWanderDir

            let nextX = win.clamp(win.posX + dir * (120 + Math.random() * 450), lo, hi)
            if (Math.abs(nextX - win.posX) < 40) {
                dir = -dir
                nextX = win.clamp(win.posX + dir * (120 + Math.random() * 450), lo, hi)
            }
            if (Math.abs(nextX - win.posX) < 25) return

            dir = nextX > win.posX ? 1 : -1
            win.lastWanderDir = dir
            win.wanderTargetX = nextX
            win.isWandering = true
            win.settled = false

            if (Math.random() < win.num(win.wanderCfg, "hopChance", 0.25)) {
                win.vy = -win.num(win.wanderCfg, "hopSpeed", 340)
                win.grounded = false
            }

            win.allowWanderRotate = Math.random() < win.num(win.wanderCfg, "rotateChance", win.num(win.wanderCfg, "rotatechance", 0.0))
            if (!win.allowWanderRotate) {
                win.angularVel = 0
            }
        }
    }

    // ───────────────────────── візуал ─────────────────────────
    // Клік повз меню закриває його
    MouseArea {
        anchors.fill: parent
        z: 50
        enabled: petMenu.visible || win.chatOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: { petMenu.visible = false; win.closeChat() }
    }

    // Тінь під кішкою: зменшується й блякне, коли вона високо
    Rectangle {
        readonly property real dist: Math.max(0, win.shadowY - (win.posY + win.contactH))
        readonly property real k: Math.max(0, 1 - dist / 700)
        visible: win.shadowEnabled && !win.isShattered && win.visible
        width: win.petSize * 0.62 * (0.55 + 0.45 * k)
        height: Math.max(4, width * 0.16)
        radius: height / 2
        x: win.posX + win.petSize / 2 - width / 2
        y: win.shadowY - height * 0.5
        color: "#000000"
        opacity: 0.32 * k
        z: 5
    }

    Item {
        id: petBody
        readonly property bool spriteMirrored: win.facingLeft !== win.spriteFacesLeft

        visible: !win.isShattered
        x: win.posX
        y: win.posY
        width: win.petSize
        height: win.petSize
        rotation: win.angle
        opacity: win.enterOpacity
        transformOrigin: Item.Center
        z: 10

        // стиснення/розтягування від ніг
        transform: Scale {
            origin.x: petBody.width / 2
            origin.y: petBody.height - win.footPad
            xScale: win.bodyScaleX
            yScale: win.bodyScaleY
        }

        PetSprite {
            id: petSprite
            anchors.fill: parent
            cfg: win.cfg
            stateName: win.currentSpriteState
            flipX: petBody.spriteMirrored
            active: win.visible && !win.isShattered
        }

        // запасний варіант, якщо спрайтів нема
        Rectangle {
            anchors.fill: parent
            visible: !petSprite.hasSprite
            radius: width / 2
            color: !win.peaceful ? "#f7768e" : (win.isDragging ? "#ff9e64" : "#7aa2f7")
            border.width: 2
            border.color: "#ffffff"

            Text {
                anchors.centerIn: parent
                text: win.petName
                font.pixelSize: 15
                color: "#1a1b26"
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            enabled: !win.isShattered
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: win.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            // запасний шлях для «затиснути й тримати 2 с → чат» (вбудований сигнал Qt)
            pressAndHoldInterval: win.holdMs
            onPressAndHold: (mouse) => {
                if (mouse.button !== Qt.LeftButton) return
                const pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                if (Math.hypot(pt.x - win.holdPx, pt.y - win.holdPy) < 14) win.holdToChat("pressAndHold")
            }

            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    const p = mapToItem(win.contentItem, mouse.x, mouse.y)
                    petMenu.x = Math.min(win.width - petMenu.width - 8, Math.max(8, p.x))
                    petMenu.y = Math.min(win.height - petMenu.height - 8, Math.max(8, p.y))
                    petMenu.visible = !petMenu.visible
                    return
                }

                petMenu.visible = false
                win.isWandering = false
                win.travelDir = 0
                win.entering = false
                win.sleeping = false
                win.idleTime = 0
                danceTimer.stop()
                win.allowWanderRotate = false
                win.mood = ""

                const pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                win.grabDX = pt.x - win.posX
                win.grabDY = pt.y - win.posY
                win.pressPX = pt.x
                win.pressPY = pt.y
                win.pressT = Date.now()
                win.dragSamples = [{ t: Date.now(), x: pt.x, y: pt.y }]
                win.dragVx = 0
                win.dragVy = 0
                win.vx = 0
                win.vy = 0
                win.angle = win.wrap180(win.angle)
                win.isDragging = true
                win.settled = false
                win.squashVel -= 3          // кішку "підхопили" — витягується вгору
                // Звук "підхопили" — лише коли справді тягнуть (зрушили або тримають), а не на кожне погладжування.
                // Раніше простий клік (погладити) щоразу грав переляканий onPick.
                win.pickSoundPending = true
                pickSoundTimer.restart()
                // затиснути й тримати 2 с без руху — відкрити чат
                if (petBrain.enabled) { win.holdPx = pt.x; win.holdPy = pt.y; win.holdT = Date.now(); holdChatTimer.restart() }
            }

            onPositionChanged: (mouse) => {
                if (!win.isDragging || win.isShattered) return
                const pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                win.posX = pt.x - win.grabDX
                win.posY = pt.y - win.grabDY
                win.pushSample(pt.x, pt.y)
                if (holdChatTimer.running && Math.hypot(pt.x - win.holdPx, pt.y - win.holdPy) >= 10) holdChatTimer.stop()
                if (win.pickSoundPending && Math.hypot(pt.x - win.pressPX, pt.y - win.pressPY) >= 8) win.playPickSound()
            }

            onCanceled: {
                holdChatTimer.stop()
                if (win.isDragging) win.isDragging = false
                pickSoundTimer.stop()
                win.pickSoundPending = false
            }

            onReleased: (mouse) => {
                holdChatTimer.stop()
                if (mouse.button !== Qt.LeftButton || win.isShattered || !win.isDragging) return
                const pt = mapToItem(win.contentItem, mouse.x, mouse.y)
                const moved = Math.hypot(pt.x - win.pressPX, pt.y - win.pressPY)
                const held = Date.now() - win.pressT
                const dv = win.sampleVelocity()
                win.isDragging = false
                win.settled = false
                pickSoundTimer.stop()
                win.pickSoundPending = false

                // короткий клік без руху — просто погладили
                if (moved < 8 && held < 350) {
                    win.vx = 0
                    win.vy = 0
                    win.poke()
                    return
                }

                let tvx = dv.x * win.throwBoost
                let tvy = dv.y * win.throwBoost
                const sp = Math.hypot(tvx, tvy)
                if (sp > win.maxThrowSpeed) {
                    tvx *= win.maxThrowSpeed / sp
                    tvy *= win.maxThrowSpeed / sp
                }
                win.vx = tvx
                win.vy = tvy
                win.angularVel += tvx * 0.2 * win.spinFactor * win.spinAccel

                const speed = Math.hypot(tvx, tvy)
                win.flightCause = speed > win.throwThreshold ? "throw" : "drop"
                win.flightSpeed = speed
                win.peakY = win.posY
                if (speed > win.throwThreshold) {
                    win.sfx("onThrow")
                    win.logEvent("The user threw you at " + Math.round(speed) + " px/s", "throw")
                    const nowMs = Date.now()
                    if (win.wsEnabled && Math.abs(tvx) > win.wsSwitchSpeed && nowMs - win.lastWsSwitch > 1200) {
                        win.lastWsSwitch = nowMs
                        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", tvx > 0 ? "+1" : "-1"])
                        win.logEvent("The throw sent you to another workspace", "throw")
                    }
                } else {
                    win.sfx("onDrop")
                    win.logEvent("The user put you down", "drop")
                }
            }
        }
    }

    // Краплі крові (фіксований пул)
    Repeater {
        id: dropsRep
        model: win.maxDrops
        delegate: Rectangle {
            visible: false
            color: win.splatterColor
            z: 88
        }
    }

    // Сердечка
    Repeater {
        id: heartsRep
        model: win.maxHearts
        delegate: Text {
            property real sz: 18
            property string glyph: "♥"
            property color col: win.heartColor
            visible: false
            text: glyph
            color: col
            font.pixelSize: sz
            transformOrigin: Item.Center
            z: 95
        }
    }

    // Прогрів кешу: перший кадр кожного спрайта вже декодований до вибуху,
    // тож 30 шматочків беруть його з пам'яті, а не з диска.
    Repeater {
        model: petSprite.allSources
        delegate: Image {
            required property string modelData
            width: 1
            height: 1
            opacity: 0
            source: modelData
            sourceSize.width: win.petSize
            sourceSize.height: win.petSize
            cache: true
            asynchronous: true
        }
    }

    // Шматочки
    Repeater {
        id: piecesRep
        model: win.pieceCount
        delegate: Item {
            id: pc
            required property int index
            readonly property var info: win.pieceInfo[index] || ({ w: 1, h: 1, sx: 0, sy: 0 })

            width: info.w
            height: info.h
            opacity: 0
            clip: true
            transformOrigin: Item.Center
            z: 90

            Image {
                visible: win.shatterSource.length > 0
                x: -pc.info.sx
                y: -pc.info.sy
                width: win.petSize
                height: win.petSize
                source: win.shatterSource
                sourceSize.width: win.petSize
                sourceSize.height: win.petSize
                cache: true
                asynchronous: false
                fillMode: Image.PreserveAspectFit
                smooth: true
                transform: Scale {
                    origin.x: win.petSize * 0.5
                    xScale: win.shatterFlip ? -1 : 1
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: win.shatterSource.length === 0
                color: !win.peaceful ? "#f7768e" : "#7aa2f7"
                border.width: 1
                border.color: "#ffffff"
            }
        }
    }

    // Бейдж таймера над кішкою
    Rectangle {
        id: timerBadge
        visible: win.timerMode !== "" && !win.isShattered && win.visible
        width: badgeText.implicitWidth + 20
        height: 24
        radius: 12
        x: Math.max(4, Math.min(win.width - width - 4, win.posX + win.petSize / 2 - width / 2))
        y: Math.max(4, win.posY - height - 4)
        color: win.bubbleTheme.bg || "#1a1b26"
        border.width: 1
        border.color: win.timerMode === "countdown" ? "#ff9e64" : "#9ece6a"
        z: 96

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: win.timerLabel
            color: win.bubbleTheme.text || "#c0caf5"
            font.pixelSize: 13
            font.bold: true
        }
    }

    // Прихований вимірювач ширини тексту бульбашки
    Text {
        id: bubbleMeasure
        visible: false
        text: win.bubbleText
        font.pixelSize: 13
        font.bold: true
    }

    // Бульбашка з текстом
    Rectangle {
        id: bubble
        width: Math.min(300, bubbleMeasure.implicitWidth) + 24
        height: bubbleLabel.implicitHeight + 16
        radius: 12
        color: win.bubbleTheme.bg || "#1a1b26"
        border.width: 1
        border.color: win.bubbleTheme.border || "#7aa2f7"
        opacity: (win.bubbleOn && !win.isShattered) ? 1 : 0
        visible: opacity > 0.01
        x: Math.max(8, Math.min(win.width - width - 8, win.posX + win.petSize / 2 - width / 2))
        y: Math.max(4, (chatBox.visible ? chatBox.y : (timerBadge.visible ? timerBadge.y : win.posY)) - height - 10)
        z: 97

        Behavior on opacity { NumberAnimation { duration: 140 } }

        // хвостик у бік кішки (ховається під тілом бульбашки)
        Rectangle {
            width: 12
            height: 12
            rotation: 45
            z: -1
            x: Math.max(10, Math.min(bubble.width - 22, win.posX + win.petSize / 2 - bubble.x - 6))
            y: bubble.height - 7
            color: bubble.color
            border.width: 1
            border.color: bubble.border.color
        }

        Text {
            id: bubbleLabel
            x: 12
            y: 8
            width: parent.width - 24
            text: win.bubbleText
            wrapMode: Text.Wrap
            color: win.bubbleTheme.text || "#c0caf5"
            font.pixelSize: 13
            font.bold: true
        }
    }

    // Поле для повідомлення над кішкою: Enter — надіслати, Esc або клік повз — закрити
    Rectangle {
        id: chatBox
        visible: win.chatOpen && !win.isShattered && win.visible
        width: 300
        height: 36
        radius: 12
        x: win.clamp(win.posX + win.petSize / 2 - width / 2, 8, win.width - width - 8)
        y: Math.max(4, win.posY - height - 8)
        color: win.bubbleTheme.bg || "#1a1b26"
        border.width: 1
        border.color: chatInput.activeFocus ? (win.bubbleTheme.border || "#7aa2f7") : "#555a7a"
        z: 98

        TextInput {
            id: chatInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: win.bubbleTheme.text || "#c0caf5"
            selectionColor: win.bubbleTheme.border || "#7aa2f7"
            font.pixelSize: 13
            font.bold: true
            clip: true
            selectByMouse: true
            Keys.onReturnPressed: win.sendChat()
            Keys.onEnterPressed: win.sendChat()
            Keys.onEscapePressed: win.closeChat()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chatInput.text.length === 0
                text: petBrain.busy ? win.petName + " is thinking..." : "Say something to " + win.petName + "...  (Esc to close)"
                color: win.bubbleTheme.text || "#c0caf5"
                opacity: 0.45
                font.pixelSize: 13
                font.bold: true
            }
        }
    }

    PetMenu {
        id: petMenu
        z: 100
        items: win.cfg.menu || []
        theme: win.cfg.menuTheme || ({})
        onActionRequested: (act) => win.doAction(act)
    }
}
