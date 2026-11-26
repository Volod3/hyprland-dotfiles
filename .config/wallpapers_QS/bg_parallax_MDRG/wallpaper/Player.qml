import Quickshell.Services.Mpris
import QtQuick

// ===== MUSIC PLAYER =====
Item {
    id: root

    required property var cfg        // settings.json -> player
    required property var parallax   // модуль Parallax

    // читання налаштувань із групи: opt("colors", "text", "#ffffff") — якщо ключа нема, береться значення за замовчуванням
    // група "" = верхній рівень секції player
    function opt(g, k, d) {
        const o = g === "" ? cfg : cfg[g];
        return (o !== undefined && o !== null && o[k] !== undefined) ? o[k] : d;
    }

    // колір + прозорість (alpha) з конфігу
    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }

// ===== PLAYER =====
    property real playerX: opt("", "x", 0)            // позиція від лівого краю (px)
    property real playerY: opt("", "y", 0)            // позиція від верху (px)
    property real playerW: opt("", "width", 200)
    property real playerH: opt("", "height", 350)

//////// STACK (кілька плеєрів)
    property string stackDirection: opt("stack", "direction", "right")   // right / left / down / up / both-horizontal / both-vertical
    property bool dedupe: opt("stack", "dedupe", true)                   // ховати дублі (той самий трек з двох джерел, напр. Chrome)
    property var ignore: opt("stack", "ignore", [])                      // джерела, які не показувати (шматок назви D-Bus або identity, напр. "plasma-browser-integration")
    property bool hideStopped: opt("stack", "hideStopped", true)         // ховати зупинені джерела, якщо є активні (лишається одна картка "нічого не грає")
    property real stackSpacing: opt("stack", "spacing", 20)
    property int maxCards: opt("stack", "maxCards", 0)                   // 0 = без обмеження
    property bool hideWhenIdle: opt("stack", "hideWhenIdle", false)      // true = ховати картку, коли плеєрів нема
    property bool stackBoth: stackDirection === "both-horizontal" || stackDirection === "both-vertical"
    property bool stackHoriz: stackDirection === "right" || stackDirection === "left" || stackDirection === "both-horizontal"
    property int stackSign: (stackDirection === "right" || stackDirection === "down") ? 1 : ((stackDirection === "left" || stackDirection === "up") ? -1 : 0)

//////// SHOW
    property bool showCover: opt("show", "cover", true)
    property bool showTime: opt("show", "time", true)

//////// COLORS
    property string cBg: opt("colors", "background", "#ffffff")
    property real aBg: opt("colors", "backgroundAlpha", 0.08)
    property string cBorder: opt("colors", "border", "#ffffff")
    property real aBorder: opt("colors", "borderAlpha", 0.28)
    property string cText: opt("colors", "text", "#ffffff")
    property real aTitle: opt("colors", "titleAlpha", 1.0)
    property real aArtist: opt("colors", "artistAlpha", 0.65)
    property real aTime: opt("colors", "timeAlpha", 0.55)
    property string cCover: opt("colors", "cover", "#ffffff")
    property real aCover: opt("colors", "coverAlpha", 0.10)
    property string cProgress: opt("colors", "progress", "#ffffff")
    property real aProgress: opt("colors", "progressAlpha", 1.0)
    property real aProgressTrack: opt("colors", "progressTrackAlpha", 0.22)
    property string cButton: opt("colors", "button", "#ffffff")
    property real aButton: opt("colors", "buttonAlpha", 0.14)
    property real aButtonBorder: opt("colors", "buttonBorderAlpha", 0.3)
    property string cIcon: opt("colors", "icon", "#ffffff")
    property real aIcon: opt("colors", "iconAlpha", 1.0)

//////// SIZES
    property real cardRadius: opt("sizes", "cardRadius", 28)
    property real borderWidth: opt("sizes", "borderWidth", 1)
    property real coverMargin: opt("sizes", "coverMargin", 24)
    property real coverRadius: opt("sizes", "coverRadius", 18)
    property int titleSize: opt("sizes", "titleSize", 16)
    property int artistSize: opt("sizes", "artistSize", 13)
    property int timeSize: opt("sizes", "timeSize", 11)
    property int iconSize: opt("sizes", "iconSize", 26)
    property int playIconSize: opt("sizes", "playIconSize", 24)
    property real playButtonSize: opt("sizes", "playButtonSize", 54)
    property real progressHeight: opt("sizes", "progressHeight", 4)
    property real seekKnobSize: opt("sizes", "seekKnobSize", 12)         // повзунок на лінії перемотки
    property real buttonSpacing: opt("sizes", "buttonSpacing", 22)
    property real buttonsBottomMargin: opt("sizes", "buttonsBottomMargin", 18)
    property int idleIconSize: opt("sizes", "idleIconSize", 90)
    property int idleTextSize: opt("sizes", "idleTextSize", 16)

//////// VOLUME — прибрано: гучність керується з waybar / бокової панелі
    property string cVolumeBg: opt("volume", "background", "#000000")      // фон кнопки згортання
    property real aVolumeBg: opt("volume", "backgroundAlpha", 0.45)

//////// COLLAPSE (кожна картка згортається окремо по висоті; затиснута кнопка згортає/розгортає всі)
    property bool collapseEnabled: opt("collapse", "enabled", true)
    property bool newCardCollapsed: opt("collapse", "startCollapsed", false)   // у якому стані з'являються картки
    property real collapsedHeight: opt("collapse", "height", 96)        // висота згорнутої картки (px)
    property real hideButtonSize: opt("collapse", "hideButtonSize", 24) // кнопка згорнути/розгорнути
    property bool hideButtonAlways: opt("collapse", "hideButtonAlwaysVisible", false)   // false = "−" з'являється при наведенні ("+" видно завжди)
    property string hideIcon: opt("collapse", "hideIcon", "−")
    property string expandIcon: opt("collapse", "expandIcon", "+")
    property int holdAllMs: opt("collapse", "holdAllMs", 2000)          // скільки тримати кнопку, щоб згорнути/розгорнути всі
    // розміри елементів керування у згорнутому вигляді
    property int compactIconSize: opt("collapse", "iconSize", 18)
    property real compactPlayButtonSize: opt("collapse", "playButtonSize", 28)
    property int compactPlayIconSize: opt("collapse", "playIconSize", 14)
    property real compactButtonsBottomMargin: opt("collapse", "buttonsBottomMargin", 8)
    signal setAllCollapsed(bool value)

//////// BEHAVIOR
    property bool keepPausedOnSkip: opt("behavior", "keepPausedOnSkip", true)   // якщо стояла пауза, то після ⏮/⏭ знову ставити на паузу

//////// TIMING
    property int pollMs: opt("timing", "pollMs", 1000)    // як часто оновлювати час відтворення (мс); менше = точніше, трохи більше навантаження

//////// TEXT
    property string fontFamily: opt("text", "fontFamily", "")            // "" = шрифт за замовчуванням
    property string idleText: opt("text", "idleText", "Нічого не грає")
    property string idleIcon: opt("text", "idleIcon", "♪")
    property string coverPlaceholder: opt("text", "coverPlaceholder", "♪")
    property string unknownTrackText: opt("text", "unknownTrack", "Невідомий трек")

//////// ANIMATION
    property bool animOn: opt("animation", "enabled", true)              // false = усі анімації вимкнено
    property int appearMs: animOn ? opt("animation", "appearMs", 500) : 0           // поява нової картки
    property int collapseMs: animOn ? opt("animation", "collapseMs", 350) : 0       // згортання / розгортання
    property int fadeMs: animOn ? opt("animation", "fadeMs", 300) : 0               // перехід "грає" <-> "нічого не грає"
    property int trackChangeMs: animOn ? opt("animation", "trackChangeMs", 260) : 0 // перегортання треку
    property real trackSlidePx: opt("animation", "trackSlidePx", 40)
    property int buttonAnimMs: animOn ? opt("animation", "buttonAnimMs", 180) : 0
    property real hoverScale: animOn ? opt("animation", "hoverScale", 1.12) : 1
    property real pressScale: animOn ? opt("animation", "pressScale", 0.86) : 1
    property int progressAnimMs: animOn ? opt("animation", "progressAnimMs", 1000) : 0
    property bool idlePulse: animOn && opt("animation", "idlePulse", true)

    // ===== СПИСОК КАРТОК: дублі, позиція в стеку =====
    // "вага" джерела: з виконавцем і обкладинкою краще, ніж без них
    function score(p) {
        return (p.trackArtist ? 2 : 0) + (p.trackArtUrl ? 1 : 0) + (isPlasma(p) ? 1 : 0);
    }

    // назва без «(154) » на початку і « - YouTube» в кінці — так Chrome і plasma-browser-integration
    // віддають той самий трек по-різному
    function normTitle(t) {
        return String(t || "").replace(/^\(\d+\)\s*/, "").replace(/\s+[-–—]\s+(YouTube|YouTube Music|SoundCloud|Spotify)$/i, "").trim().toLowerCase();
    }
    function sameTrack(a, b) {
        const x = normTitle(a.trackTitle), y = normTitle(b.trackTitle);
        return x.length > 0 && y.length > 0 && (x === y || x.indexOf(y) !== -1 || y.indexOf(x) !== -1);
    }
    function isPlasma(p) { return p && (p.dbusName || "").indexOf("plasma-browser-integration") !== -1; }
    // plasma-browser-integration «висить» після закриття браузера — показуємо його, лише поки браузер працює
    function browserAlive() {
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++) {
            const n = ((ps[i].dbusName || "") + " " + (ps[i].identity || "")).toLowerCase();
            if (!isPlasma(ps[i]) && /chrom|firefox|brave|vivaldi|opera|edge|zen/.test(n)) return true;
        }
        return false;
    }
    function meta(p, k) {
        try { const m = p.metadata; return m && m[k] ? String(m[k]) : ""; } catch (e) { return ""; }
    }
    // обкладинка: своя → з іншого джерела того самого треку → мініатюра YouTube за адресою відео
    function artOf(p) {
        if (!p) return "";
        if (p.trackArtUrl) return p.trackArtUrl;
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++)
            if (ps[i] !== p && ps[i].trackArtUrl && sameTrack(p, ps[i])) return ps[i].trackArtUrl;
        for (let i = 0; i < ps.length; i++) {
            if (ps[i] !== p && !sameTrack(p, ps[i])) continue;
            const m = meta(ps[i], "xesam:url").match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]{11})/);
            if (m) return "https://i.ytimg.com/vi/" + m[1] + "/hqdefault.jpg";
        }
        return "";
    }
    function titleOf(p) {
        if (!p) return "";
        const t = String(p.trackTitle || "").replace(/^\(\d+\)\s*/, "").replace(/\s+[-–—]\s+YouTube$/i, "");
        return t;
    }

    // чи джерело в списку stack.ignore (порівняння без урахування регістру по dbusName та identity)
    function isIgnored(p) {
        if (!p || !ignore || ignore.length === 0) return false;
        const name = ((p.dbusName || "") + " " + (p.identity || "")).toLowerCase();
        for (let i = 0; i < ignore.length; i++)
            if (name.indexOf(String(ignore[i]).toLowerCase()) !== -1) return true;
        return false;
    }

    // чи є хоч одне джерело, яке не ігнорується
    function hasPlayers() {
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++) if (!isIgnored(ps[i])) return true;
        return false;
    }

    // чи це дубль іншого джерела (той самий трек в іншому MPRIS-плеєрі, напр. браузер)
    // Дубль, якщо тривалість збігається (±2 с) і при цьому:
    //  - збігається назва, АБО
    //  - позиція відтворення майже однакова (±5 с) і обидва в одному стані (грає/пауза).
    // (Chrome часто віддає друге джерело з назвою "YouTube" замість назви треку, тому самої назви мало.)
    function isDup(p) {
        if (!p) return false;
        if (isIgnored(p)) return true;
        if (isPlasma(p) && !browserAlive()) return true;
        const ps = Mpris.players.values;
        let ip = -1;
        for (let i = 0; i < ps.length; i++) if (ps[i] === p) ip = i;

        // зупинене джерело (напр. друга вкладка/процес браузера між треками) не заслуговує окремої картки:
        // ховаємо його, якщо є хоч одне активне; а якщо зупинені всі — лишаємо тільки першу
        // (ігноровані джерела тут не враховуються — раніше через них могла зникнути навіть остання картка)
        if (hideStopped && p.playbackState === MprisPlaybackState.Stopped) {
            let firstStopped = null;
            for (let i = 0; i < ps.length; i++) {
                const q = ps[i];
                if (isIgnored(q)) continue;
                if (q.playbackState !== MprisPlaybackState.Stopped) return true;
                if (firstStopped === null) firstStopped = q;
            }
            return firstStopped !== p;
        }

        if (!dedupe) return false;
        for (let i = 0; i < ps.length; i++) {
            const q = ps[i];
            if (q === p || isIgnored(q)) continue;
            if (hideStopped && q.playbackState === MprisPlaybackState.Stopped) continue;   // воно й так сховане
            const lp = p.length || 0;
            const lq = q.length || 0;
            if (lp <= 0 || lq <= 0 || Math.abs(lp - lq) > 2) continue;
            const sameTitle = sameTrack(p, q);
            const sameMoment = p.isPlaying === q.isPlaying && Math.abs(p.position - q.position) <= 5;
            if (!sameTitle && !sameMoment) continue;
            if (score(q) > score(p) || (score(q) === score(p) && i < ip)) return true;
        }
        return false;
    }

    // номер картки серед видимих (без дублів)
    function slotOf(p) {
        if (!p) return 0;
        const ps = Mpris.players.values;
        let n = 0;
        for (let i = 0; i < ps.length; i++) {
            if (ps[i] === p) return n;
            if (!isDup(ps[i])) n++;
        }
        return n;
    }

    // скільки карток зараз показано
    function visibleCount() {
        const ps = Mpris.players.values;
        let n = 0;
        for (let i = 0; i < ps.length; i++) if (!isDup(ps[i])) n++;
        if (maxCards > 0) n = Math.min(n, maxCards);
        return Math.max(1, n);
    }

    // зсув картки в "кроках" (розмір картки + spacing) від позиції x/y
    function stackOffset(slot, n) {
        if (!stackBoth) return slot * stackSign;
        // both-*: 1-ша в центрі, 2-га зліва/зверху, 3-тя справа/знизу, 4-та зліва... а вся група центрується на x/y
        const left = Math.floor(n / 2);
        const j = (slot === 0) ? left : (slot % 2 === 1 ? left - 1 - (slot - 1) / 2 : left + slot / 2);
        return j - (n - 1) / 2;
    }

    // 3:07, а для довгих треків 1:02:07 (раніше було 62:07)
    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec || 0));
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const s = sec % 60;
        const ss = (s < 10 ? "0" : "") + s;
        return h > 0 ? h + ":" + (m < 10 ? "0" : "") + m + ":" + ss : m + ":" + ss;
    }


    // ===== ПОЗИЦІЯ МІЖ ШАРАМИ + ПАРАЛАКС (як в інших модулях: atLayer / afterLayer / followLayer) =====
    z: parallax.zOf(cfg)
    readonly property real depth: parallax.depthOf(cfg)
    visible: !(root.hideWhenIdle && !root.hasPlayers())

    x: root.playerX
    y: root.playerY
    width: root.playerW
    height: root.playerH

    transform: Translate { x: root.parallax.dx(root.depth); y: root.parallax.dy(root.depth) }

    // ===== КАРТКИ: по одній на кожне джерело звуку (якщо джерел нема — одна порожня картка) =====
    Repeater {
        model: root.hasPlayers() ? Mpris.players : 1

        delegate: Item {
            id: card

            required property var modelData
            required property int index

            readonly property var player: (modelData !== null && typeof modelData === "object") ? modelData : null
            readonly property bool idle: player === null || player.playbackState === MprisPlaybackState.Stopped

            property real appear: 0           // 0..1, анімація появи картки
            property string shownTitle: ""    // те, що зараз показано (міняється посеред анімації перегортання)
            property string shownArtist: ""
            property string shownArt: ""
            property real trackShift: 0
            property real trackOpacity: 1
            property int slideDir: 1          // 1 = наступний трек, -1 = попередній
            property bool seeking: false      // користувач тягне повзунок перемотки
            property real seekFrac: 0         // позиція повзунка 0..1 під час перемотки

            // згортання цієї картки
            property bool collapsed: root.newCardCollapsed
            property real shownT: collapsed ? 0 : 1      // 1 = розгорнуто, 0 = згорнуто (анімується)
            property real contentFade: Math.max(0, (shownT - 0.3) / 0.7)   // зайві елементи гаснуть першими
            Behavior on shownT { NumberAnimation { duration: root.collapseMs; easing.type: Easing.InOutCubic } }

            Connections {
                target: root
                function onSetAllCollapsed(value) { card.collapsed = value; }
            }

            // ⏮/⏭ з "тримати паузу": якщо до натискання стояла пауза, то після перемикання (плеєри люблять самі
            // починати грати) кілька разів підряд ставимо паузу
            property int pauseTries: 0
            function skip(forward) {
                const p = player;
                if (!p) return;
                if (root.keepPausedOnSkip && !p.isPlaying) {
                    pauseTries = 0;
                    keepPausedTimer.restart();
                }
                if (forward) p.next(); else p.previous();
            }
            Timer {
                id: keepPausedTimer
                interval: 100
                repeat: true
                onTriggered: {
                    card.pauseTries++;
                    if (card.player && card.player.isPlaying && card.player.canPause) card.player.pause();
                    if (card.pauseTries >= 20) stop();   // ~2 с
                }
            }

            readonly property bool dup: root.isDup(player)
            readonly property int slot: root.slotOf(player)
            readonly property real off: root.stackOffset(slot, root.visibleCount())

            visible: !dup && (root.maxCards === 0 || slot < root.maxCards)
            z: -index
            width: root.playerW
            height: root.collapsedHeight + (root.playerH - root.collapsedHeight) * card.shownT   // згортання тільки по висоті

            // нова картка виїжджає з центру, решта плавно розсуваються (stack.direction)
            x: root.stackHoriz ? off * (width + root.stackSpacing) * appear : 0
            // при згортанні нижній край картки лишається на місці: стискається згори вниз
            property real stackY: root.stackHoriz ? 0 : off * (root.playerH + root.stackSpacing) * appear
            Behavior on stackY { enabled: card.appear >= 1; NumberAnimation { duration: root.appearMs; easing.type: Easing.OutCubic } }
            y: stackY + (root.playerH - height)
            Behavior on x { enabled: card.appear >= 1; NumberAnimation { duration: root.appearMs; easing.type: Easing.OutCubic } }
            opacity: appear
            scale: 0.9 + 0.1 * appear

            NumberAnimation on appear { from: 0; to: 1; duration: root.appearMs; easing.type: Easing.OutCubic }

            function sync() {
                shownTitle = root.titleOf(player);
                shownArtist = player ? (player.trackArtist || "") : "";
                shownArt = root.artOf(player);
            }
            Component.onCompleted: sync()

            // Плеєри шлють назву/виконавця/обкладинку окремими сигналами і в різному порядку.
            // Раніше виконавець і обкладинка мінялися одразу, а назва — з анімацією, тож на мить
            // показувалась стара назва з новим виконавцем. Тепер зміни збираються і застосовуються разом.
            Connections {
                target: card.player
                ignoreUnknownSignals: true
                function onTrackTitleChanged() { metaTimer.restart(); if (card.player) card.player.positionChanged(); }
                function onTrackArtistChanged() { metaTimer.restart(); }
                function onTrackArtUrlChanged() { metaTimer.restart(); }
                function onIsPlayingChanged() { playPulse.restart(); if (card.player) card.player.positionChanged(); }
            }
            Connections {
                target: Mpris.players
                function onValuesChanged() { metaTimer.restart(); }
            }
            Timer {
                interval: 2000; repeat: true; running: card.player !== null && card.shownArt === ""
                onTriggered: { const a = root.artOf(card.player); if (a) card.shownArt = a; }
            }
            Timer {
                id: metaTimer
                interval: 40
                onTriggered: {
                    const p = card.player;
                    if (!p || changeAnim.running) return;      // анімація сама все підхопить
                    if (root.titleOf(p) !== card.shownTitle || (p.trackArtist || "") !== card.shownArtist)
                        changeAnim.restart();                   // інший трек — перегортання
                    else
                        card.shownArt = root.artOf(p);          // лише догрузилась обкладинка
                }
            }

            // перегортання треку: старе виїжджає, нове заїжджає з протилежного боку
            SequentialAnimation {
                id: changeAnim
                ParallelAnimation {
                    NumberAnimation { target: card; property: "trackOpacity"; to: 0; duration: root.trackChangeMs; easing.type: Easing.InCubic }
                    NumberAnimation { target: card; property: "trackShift"; to: -card.slideDir * root.trackSlidePx; duration: root.trackChangeMs; easing.type: Easing.InCubic }
                }
                ScriptAction { script: { card.sync(); card.trackShift = card.slideDir * root.trackSlidePx; } }
                ParallelAnimation {
                    NumberAnimation { target: card; property: "trackOpacity"; to: 1; duration: root.trackChangeMs; easing.type: Easing.OutCubic }
                    NumberAnimation { target: card; property: "trackShift"; to: 0; duration: root.trackChangeMs; easing.type: Easing.OutCubic }
                }
                ScriptAction { script: { card.slideDir = 1; metaTimer.restart(); } }   // перевірити, чи не змінилось щось під час анімації
            }

            // "стрибок" іконки play/pause при зміні стану
            SequentialAnimation {
                id: playPulse
                NumberAnimation { target: playIcon; property: "scale"; to: 0.5; duration: root.buttonAnimMs / 2; easing.type: Easing.InQuad }
                NumberAnimation { target: playIcon; property: "scale"; to: 1; duration: root.buttonAnimMs * 1.5; easing.type: Easing.OutBack }
            }

            Timer {
                interval: root.pollMs
                repeat: true
                running: card.player !== null && card.player.isPlaying
                onTriggered: card.player.positionChanged()
            }

            // наведення на картку (показує кнопку згортання)
            HoverHandler { id: cardHover }

            // скляна підложка
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: root.tint(root.cBg, root.aBg)
                border.color: root.tint(root.cBorder, root.aBorder)
                border.width: root.borderWidth
            }

            // кнопка згорнути ("−", при наведенні) / розгорнути ("+", видно завжди, коли згорнуто) цю картку.
            // Якщо тримати її holdAllMs (2 с) — згортаються/розгортаються ВСІ картки.
            Rectangle {
                id: hideBtn
                z: 50
                visible: root.collapseEnabled && opacity > 0
                width: root.hideButtonSize
                height: width
                radius: width / 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                color: root.tint(root.cVolumeBg, root.aVolumeBg)
                opacity: (card.collapsed || root.hideButtonAlways || cardHover.hovered) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.buttonAnimMs } }
                scale: hideMouse.pressed ? root.pressScale : (hideMouse.containsMouse ? root.hoverScale : 1)
                Behavior on scale { NumberAnimation { duration: root.buttonAnimMs; easing.type: Easing.OutBack } }

                property real holdT: 0   // 0..1, прогрес утримання

                // кільце-заповнення, поки кнопку тримають
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * hideBtn.holdT
                    height: width
                    radius: width / 2
                    color: root.tint(root.cIcon, 0.35)
                    visible: hideBtn.holdT > 0
                }

                NumberAnimation {
                    id: holdAnim
                    target: hideBtn
                    property: "holdT"
                    from: 0; to: 1
                    duration: root.holdAllMs
                }

                Text {
                    anchors.centerIn: parent
                    text: card.collapsed ? root.expandIcon : root.hideIcon
                    color: root.tint(root.cIcon, root.aIcon)
                    font.family: root.fontFamily || Qt.application.font.family
                    font.pixelSize: parent.width * 0.7
                }
                MouseArea {
                    id: hideMouse
                    property bool held: false
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    pressAndHoldInterval: root.holdAllMs

                    onPressed: { held = false; holdAnim.restart(); }
                    onPressAndHold: {
                        held = true;
                        const target = !card.collapsed;      // усі стають такими, якими стане ця картка
                        root.newCardCollapsed = target;
                        root.setAllCollapsed(target);
                    }
                    onReleased: { holdAnim.stop(); hideBtn.holdT = 0; }
                    onCanceled: { holdAnim.stop(); hideBtn.holdT = 0; }
                    onClicked: if (!held) card.collapsed = !card.collapsed
                }
            }

            // ===== КОЛИ ЩОСЬ Є =====
            Item {
                id: activeContent
                anchors.fill: parent
                opacity: card.idle ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: root.fadeMs } }

                // обкладинка
                Rectangle {
                    id: art
                    visible: root.showCover
                    x: root.coverMargin; y: root.coverMargin * (0.5 + 0.5 * card.shownT)
                    width: parent.width - 2 * root.coverMargin
                    height: root.showCover ? width * card.shownT : 0
                    radius: root.coverRadius
                    color: root.tint(root.cCover, root.aCover)
                    clip: true
                    opacity: card.trackOpacity
                    transform: Translate { x: card.trackShift }

                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: card.shownArt
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false                 // браузери перезаписують той самий файл обкладинки
                        sourceSize.width: 512
                        smooth: true
                        visible: status === Image.Ready
                    }
                    // заглушка і тоді, коли обкладинка не завантажилась (раніше лишався порожній квадрат)
                    Text {
                        anchors.centerIn: parent
                        text: root.coverPlaceholder
                        color: root.tint(root.cText, 1)
                        font.family: root.fontFamily || Qt.application.font.family
                        font.pixelSize: Math.max(1, Math.min(90, art.height * 0.5))
                        visible: artImg.status !== Image.Ready
                    }
                }

                // назва + виконавець
                Column {
                    id: info
                    anchors.top: art.bottom
                    anchors.topMargin: (root.showCover ? 14 : root.coverMargin) * card.shownT
                    anchors.left: art.left
                    anchors.right: art.right
                    anchors.rightMargin: (root.hideButtonSize + 6) * (1 - card.shownT)   // місце під кнопку розгорнути
                    spacing: 2
                    opacity: card.trackOpacity
                    transform: Translate { x: card.trackShift }

                    Text {
                        width: parent.width
                        text: card.shownTitle || root.unknownTrackText
                        color: root.tint(root.cText, root.aTitle)
                        font.family: root.fontFamily || Qt.application.font.family
                        font.pixelSize: root.titleSize
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        opacity: card.contentFade
                        height: implicitHeight * card.contentFade
                        text: card.shownArtist
                        color: root.tint(root.cText, root.aArtist)
                        font.family: root.fontFamily || Qt.application.font.family
                        font.pixelSize: root.artistSize
                        elide: Text.ElideRight
                    }
                }

                // прогрес-бар (лінію можна тягнути повзунком; позиція застосовується, коли відпускаєш)
                Item {
                    id: progress
                    anchors.top: info.bottom
                    anchors.topMargin: 8 + 6 * card.shownT
                    anchors.left: art.left
                    anchors.right: art.right
                    height: 14

                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: (progressMouse.containsMouse || card.seeking) ? root.progressHeight * 1.8 : root.progressHeight
                        radius: height / 2
                        color: root.tint(root.cProgress, root.aProgressTrack)
                        Behavior on height { NumberAnimation { duration: root.buttonAnimMs; easing.type: Easing.OutCubic } }

                        Rectangle {
                            id: fill
                            height: parent.height
                            radius: height / 2
                            color: root.tint(root.cProgress, root.aProgress)
                            width: card.seeking
                                ? parent.width * card.seekFrac
                                : ((card.player && card.player.length > 0)
                                    ? parent.width * Math.min(1, (card.player.position + ((card.player.isPlaying && root.progressAnimMs > 0) ? root.progressAnimMs / 1000 : 0)) / card.player.length)
                                    : 0)
                            Behavior on width {
                                enabled: root.progressAnimMs > 0 && !changeAnim.running && !card.seeking
                                NumberAnimation { duration: root.progressAnimMs; easing.type: Easing.Linear }
                            }
                        }

                        // повзунок
                        Rectangle {
                            width: root.seekKnobSize
                            height: width
                            radius: width / 2
                            color: root.tint(root.cProgress, 1)
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width, fill.width)) - width / 2
                            opacity: (progressMouse.containsMouse || card.seeking) ? 1 : 0
                            scale: card.seeking ? 1.3 : ((progressMouse.containsMouse) ? 1 : 0.6)
                            Behavior on opacity { NumberAnimation { duration: root.buttonAnimMs } }
                            Behavior on scale { NumberAnimation { duration: root.buttonAnimMs; easing.type: Easing.OutBack } }
                        }
                    }

                    // після відпускання повзунок ще мить тримається на місці, поки плеєр оновить позицію
                    Timer {
                        id: seekRelease
                        interval: 300
                        onTriggered: card.seeking = false
                    }

                    MouseArea {
                        id: progressMouse
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: -9          // збільшена зона натискання, щоб не цілитись у тонку лінію
                        anchors.bottomMargin: -9
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor

                        function frac(mx) { return Math.max(0, Math.min(1, mx / width)); }

                        onPressed: mouse => {
                            if (!card.player || !card.player.canSeek || card.player.length <= 0) return;
                            seekRelease.stop();
                            card.seeking = true;
                            card.seekFrac = frac(mouse.x);
                        }
                        onPositionChanged: mouse => {
                            if (pressed && card.seeking) card.seekFrac = frac(mouse.x);
                        }
                        onReleased: mouse => {
                            if (!card.seeking) return;
                            card.seekFrac = frac(mouse.x);
                            const p = card.player;
                            if (p && p.canSeek && p.length > 0) {
                                p.position = card.seekFrac * p.length;
                                p.positionChanged();
                            }
                            seekRelease.restart();
                        }
                        onCanceled: card.seeking = false
                    }
                }

                // час
                Item {
                    visible: root.showTime && opacity > 0
                    opacity: card.contentFade
                    anchors.top: progress.bottom
                    anchors.left: art.left
                    anchors.right: art.right
                    height: 14
                    Text {
                        anchors.left: parent.left
                        text: card.player ? root.fmt(card.seeking ? card.seekFrac * card.player.length : card.player.position) : ""
                        color: root.tint(root.cText, root.aTime)
                        font.family: root.fontFamily || Qt.application.font.family
                        font.pixelSize: root.timeSize
                    }
                    Text {
                        anchors.right: parent.right
                        text: card.player ? root.fmt(card.player.length) : ""
                        color: root.tint(root.cText, root.aTime)
                        font.family: root.fontFamily || Qt.application.font.family
                        font.pixelSize: root.timeSize
                    }
                }

                // кнопки
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.compactButtonsBottomMargin + (root.buttonsBottomMargin - root.compactButtonsBottomMargin) * card.shownT
                    // згорнуто: ⏮ і ⏭ по краях лінії часу, пауза посередині; розгорнуто: звичайна купка кнопок
                    spacing: Math.max(0, (art.width - prevBtn.width - playBtn.width - nextBtn.width) / 2) * (1 - card.shownT) + root.buttonSpacing * card.shownT

                    Text {
                        id: prevBtn
                        property real nudge: 0
                        text: "⏮"; color: root.tint(root.cIcon, root.aIcon)
                        font.pixelSize: root.compactIconSize + (root.iconSize - root.compactIconSize) * card.shownT
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: (card.player && card.player.canGoPrevious) ? 1 : 0.35
                        scale: prevMouse.pressed ? root.pressScale : (prevMouse.containsMouse ? root.hoverScale : 1)
                        Behavior on scale { NumberAnimation { duration: root.buttonAnimMs; easing.type: Easing.OutBack } }
                        transform: Translate { x: prevBtn.nudge }
                        SequentialAnimation {
                            id: prevNudgeAnim
                            NumberAnimation { target: prevBtn; property: "nudge"; to: -14; duration: root.buttonAnimMs * 0.4; easing.type: Easing.OutQuad }
                            NumberAnimation { target: prevBtn; property: "nudge"; to: 0; duration: root.buttonAnimMs * 1.4; easing.type: Easing.OutBack }
                        }
                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent; anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (card.player && card.player.canGoPrevious) {
                                card.slideDir = -1;
                                prevNudgeAnim.restart();
                                card.skip(false);
                            }
                        }
                    }
                    Rectangle {
                        id: playBtn
                        width: root.compactPlayButtonSize + (root.playButtonSize - root.compactPlayButtonSize) * card.shownT
                        height: width
                        radius: width / 2
                        color: root.tint(root.cButton, root.aButton)
                        border.color: root.tint(root.cButton, root.aButtonBorder)
                        scale: playMouse.pressed ? root.pressScale : (playMouse.containsMouse ? root.hoverScale : 1)
                        Behavior on scale { NumberAnimation { duration: root.buttonAnimMs; easing.type: Easing.OutBack } }
                        Text {
                            id: playIcon
                            anchors.centerIn: parent
                            text: (card.player && card.player.isPlaying) ? "⏸" : "▶"
                            color: root.tint(root.cIcon, root.aIcon)
                            font.pixelSize: root.compactPlayIconSize + (root.playIconSize - root.compactPlayIconSize) * card.shownT
                        }
                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (card.player && card.player.canTogglePlaying) {
                                keepPausedTimer.stop();
                                card.player.togglePlaying();
                            }
                        }
                    }
                    Text {
                        id: nextBtn
                        property real nudge: 0
                        text: "⏭"; color: root.tint(root.cIcon, root.aIcon)
                        font.pixelSize: root.compactIconSize + (root.iconSize - root.compactIconSize) * card.shownT
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: (card.player && card.player.canGoNext) ? 1 : 0.35
                        scale: nextMouse.pressed ? root.pressScale : (nextMouse.containsMouse ? root.hoverScale : 1)
                        Behavior on scale { NumberAnimation { duration: root.buttonAnimMs; easing.type: Easing.OutBack } }
                        transform: Translate { x: nextBtn.nudge }
                        SequentialAnimation {
                            id: nextNudgeAnim
                            NumberAnimation { target: nextBtn; property: "nudge"; to: 14; duration: root.buttonAnimMs * 0.4; easing.type: Easing.OutQuad }
                            NumberAnimation { target: nextBtn; property: "nudge"; to: 0; duration: root.buttonAnimMs * 1.4; easing.type: Easing.OutBack }
                        }
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent; anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (card.player && card.player.canGoNext) {
                                card.slideDir = 1;
                                nextNudgeAnim.restart();
                                card.skip(true);
                            }
                        }
                    }
                }
            }

            // ===== КОЛИ НІЧОГО НЕ ГРАЄ =====
            Item {
                id: idleContent
                anchors.fill: parent
                opacity: card.idle ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: root.fadeMs } }

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: card.contentFade
                        height: implicitHeight * card.contentFade
                        text: root.idleIcon
                        color: root.tint(root.cText, 0.5)
                        font.family: root.fontFamily || Qt.application.font.family
                        font.pixelSize: root.idleIconSize

                        // м'яке "дихання" іконки
                        SequentialAnimation on scale {
                            running: root.idlePulse && idleContent.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.12; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.idleText
                        color: root.tint(root.cText, root.aArtist)
                        font.family: root.fontFamily || Qt.application.font.family
                        font.pixelSize: root.idleTextSize
                    }
                }
            }
        }
    }
}
