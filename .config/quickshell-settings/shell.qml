import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "components"
import "pages"

// Центр налаштувань Hyprland «Азур» — окремий Quickshell-застосунок.
// Запуск: ~/.config/theme-switch/bin/hypr-settings (або qs -p цей файл)
ShellRoot {
    id: root

    property int page: 4
    property var titles: ["Комбінації клавіш", "Оформлення", "Ефекти та ігровий режим", "Про систему",
                          "Живлення та сон", "Екран", "Клавіатура", "Миша й тачпад", "Вікна", "Сповіщення", "Диски", "Теми"]
    property var subtitles: [
        "гарячі клавіші з ~/.config/hypr/hyprland.lua — лише перегляд",
        "живі зміни через hyprctl eval + перевірка getoption",
        "theme-switch, ігровий режим, шпалери та знімки",
        "залізо, версії Hyprland і ядра",
        "затемнення, вимкнення екрана, блокування, сон, режим живлення",
        "дисплеї й монітори, яскравість, масштаб, нічний режим, частота",
        "розкладки, перемикання мови, повтор клавіш",
        "чутливість, прокрутка, тачпад",
        "фокус, розмітка, курсор, затемнення неактивних",
        "«Не турбувати» і центр сповіщень",
        "місце на диску, файли, флешки",
        "шпалери й кольори всього інтерфейсу · швидко — Pause"
    ]

    // ── описи нових сторінок (pages/SchemaPage.qml) ──
    readonly property var minutes: ({ mul: 60, suffix: " хв", from: 0, step: 1, zeroText: "ніколи" })
    function m(o) { return Object.assign({}, minutes, o) }
    readonly property var powerSchema: [
        { title: "Енергозбереження екрана", icon: "\uf186", items: [
            m({ type: "slider", key: "idle.dim", label: "Затемнити екран через", to: 30 }),
            m({ type: "slider", key: "idle.dpms", label: "Вимкнути екран через", to: 60 }),
            m({ type: "slider", key: "idle.lock", label: "Заблокувати через", to: 60 }),
            m({ type: "slider", key: "idle.suspend", label: "Сон (suspend) через", to: 120 }),
            { type: "toggle", key: "idle.ac_suspend", label: "Засинати й на зарядці", hint: "вимкнено — від мережі ПК не засинає (щоб був доступний з телефона); від батареї — засинає" },
            { type: "toggle", key: "idle.lock_before_sleep", label: "Блокувати перед сном", hint: "після пробудження — екран блокування з паролем" },
            { type: "toggle", key: "misc:mouse_move_enables_dpms", label: "Будити вимкнений екран рухом миші", hint: "лише вимкнений екран; зі СНУ миша не будить (клавіатура, кришка, кнопка живлення)" },
            { type: "toggle", key: "misc:key_press_enables_dpms", label: "Будити екран клавішею" }
        ]},
        { title: "Коли закриваєш кришку", icon: "\uf109", items: [
            { type: "choice", key: "lid.battery", label: "Від батареї", options: [
                { v: "suspend", t: "Сон" }, { v: "lock", t: "Блокування" }, { v: "screen", t: "Вимкнути екран" }, { v: "nothing", t: "Нічого" } ] },
            { type: "choice", key: "lid.ac", label: "Від мережі", options: [
                { v: "suspend", t: "Сон" }, { v: "lock", t: "Блокування" }, { v: "screen", t: "Вимкнути екран" }, { v: "nothing", t: "Нічого" } ] }
        ]},
        { title: "Режим живлення", icon: "\uf0e7", items: [
            { type: "choice", key: "power.profile", label: "Профіль", options: [
                { v: "power-saver", t: "Економія" }, { v: "balanced", t: "Баланс" }, { v: "performance", t: "Потужність" } ] },
            { type: "choice", key: "power.on_battery", label: "Коли відключаєш зарядку", hint: "профіль перемкнеться сам", options: [
                { v: "keep", t: "Не міняти" }, { v: "balanced", t: "Баланс" }, { v: "power-saver", t: "Економія" } ] },
            { type: "choice", key: "power.on_ac", label: "Коли підключаєш зарядку", options: [
                { v: "keep", t: "Не міняти" }, { v: "balanced", t: "Баланс" }, { v: "performance", t: "Потужність" } ] },
            { type: "choice", key: "power.critical_action", label: "Коли заряд 3%", hint: "сповіщення приходять на 20%, 10% і 5%", options: [
                { v: "suspend", t: "Сон" }, { v: "none", t: "Нічого" } ] },
            { type: "slider", key: "power.low_battery", label: "Економія, коли заряд нижче", from: 0, to: 50, step: 5, suffix: "%", zeroText: "ніколи" },
            { type: "button", label: "Батарея, процеси, навантаження", text: "Відкрити", cmd: "qs -p ~/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup toggle sys" }
        ]},
        { title: "Що вимикає «Економія»", icon: "\uf06c", items: [
            { type: "toggle", key: "eco.hz60", label: "Екран 60 Гц замість 144", hint: "найбільша економія — у 2,4 раза менше кадрів" },
            { type: "toggle", key: "eco.effects", label: "Без розмиття й тіней", hint: "розмиття під вікнами — найважча робота для відеокарти" },
            { type: "toggle", key: "eco.static_wallpaper", label: "Статичні шпалери", hint: "паралакс і хвилька cava зупиняються" },
            { type: "toggle", key: "eco.hide_pet", label: "Ховати пета", hint: "і вивантажувати модель Ollama з пам'яті" },
            { type: "toggle", key: "eco.no_turbo", label: "Без турбобусту процесора", hint: "трохи повільніше, але холодніше й набагато економніше" },
            { type: "toggle", key: "eco.kbd_light", label: "Гасити підсвітку клавіатури" },
            { type: "slider", key: "eco.brightness", label: "Обмежити яскравість до", from: 0, to: 100, step: 5, suffix: "%", zeroText: "не змінювати" }
        ]},
        { title: "Відеокарта", icon: "\uf26c", items: [
            { type: "note", label: "Робочий стіл (Hyprland, панелі, шпалери)", hint: "завжди на вбудованій Intel: екран ноутбука підключений до неї — так найменше енергії й затримок" },
            { type: "choice", key: "gpu.apps", label: "Програми та ігри", hintKey: "gpu.info", options: [
                { v: "auto", t: "Авто" }, { v: "igpu", t: "Вбудована" }, { v: "dgpu", t: "NVIDIA" } ] },
            { type: "note", label: "Як це працює", hint: "діє на програми, запущені після зміни; в «Економії» — завжди вбудована" }
        ]},
        { title: "Захист батареї", icon: "\uf240", items: [
            { type: "choice", key: "battery.limit", label: "Заряджати до", hintKey: "battery.info", options: [
                { v: "60", t: "60%" }, { v: "80", t: "80% (типово)" }, { v: "90", t: "90%" }, { v: "100", t: "100%" } ] },
            { type: "note", label: "Навіщо", hint: "батарея, що стоїть на 100%, старіє швидше; 80% — запас на відключення світла і довге життя батареї" },
            { type: "button", label: "Потрібна повна батарея в дорогу?", hint: "до 100% лише цього разу — після відключення зарядки ліміт повернеться",
              text: "Зарядити до 100% один раз", cmd: "~/.config/wallpapers_QS/tools/powerd full-once" }
        ]}
    ]
    readonly property var themesSchema: [
        { title: "Теми робочого столу", icon: "\uf1fc", items: [
            { type: "themes", key: "theme", label: "Шпалери й кольори всього інтерфейсу", hint: "клік — перемкнути з анімацією; швидке меню — клавіша Pause / Break" }
        ]}
    ]
    readonly property var disksSchema: [
        { title: "Місце на диску", icon: "\uf0a0", items: [
            { type: "button", label: "Що займає місце — уся система", hint: "Filelight: кольорова карта папок і файлів за розміром", text: "Відкрити", cmd: "filelight /" },
            { type: "button", label: "Що займає місце — домашня тека", text: "Відкрити", cmd: "filelight ~" },
            { type: "button", label: "Файли", hint: "Dolphin", text: "Відкрити", cmd: "dolphin" },
            { type: "button", label: "Диски й навантаження", hint: "заповненість, швидкість, процеси", text: "Відкрити", cmd: "qs -p ~/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup toggle sys" }
        ]},
        { title: "Флешки й знімні диски", icon: "\uf287", items: [
            { type: "choice", key: "devices.onconnect", label: "Коли підключаєш флешку", options: [
                { v: "menu", t: "Меню пристроїв" }, { v: "files", t: "Відкрити файли" }, { v: "none", t: "Нічого" } ] },
            { type: "toggle", key: "devices.automount", label: "Монтувати автоматично", hint: "щойно підключиш — з'явиться у Dolphin і в меню флешок на панелі" },
            { type: "button", label: "Меню пристроїв", hint: "від'єднати безпечно, прогрес запису", text: "Відкрити", cmd: "qs -p ~/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup open dev" },
            { type: "button", label: "Форматувати флешку", hint: "меню флешок → «Форматувати»: exFAT / FAT32 / NTFS / ext4, назва, один клік", text: "Відкрити", cmd: "qs -p ~/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup open dev" }
        ]}
    ]
    readonly property var displaySchema: [
        { title: "Дисплеї", icon: "\uf108", items: [
            { type: "displays", key: "monitors", label: "Монітори", hint: "як у KDE: роздільність, частота, масштаб, розташування другого екрана, дзеркало, поворот" }
        ]},
        { title: "Екран", icon: "\uf108", items: [
            { type: "slider", key: "display.brightness", label: "Яскравість", from: 1, to: 100, suffix: "%" },
            { type: "choice", key: "display.scale", label: "Масштаб", hint: "розмір усього на екрані", options: [
                { v: 1, t: "100%" }, { v: 1.25, t: "125%" }, { v: 1.5, t: "150%" }, { v: 2, t: "200%" } ] },
            { type: "choice", key: "misc:vrr", label: "Адаптивна частота (VRR)", options: [
                { v: 0, t: "Вимк" }, { v: 1, t: "Завжди" }, { v: 2, t: "В іграх" } ] }
        ]},
        { title: "Нічний режим", icon: "\uf186", items: [
            { type: "toggle", key: "night.enabled", label: "Нічне світло", hint: "тепліші кольори — менше синього ввечері (hyprsunset)" },
            { type: "toggle", key: "night.schedule", label: "За розкладом", hint: "вмикається й вимикається саме у вказаний час" },
            { type: "time", key: "night.from", label: "Вмикати о", hint: "коліщатко / клік — змінити", presets: ["19:00", "20:00", "21:00", "22:00"] },
            { type: "time", key: "night.to", label: "Вимикати о", hint: "ПКМ — назад", presets: ["06:00", "07:00", "08:00"] },
            { type: "slider", key: "night.temp", label: "Температура кольору", hint: "менше — тепліше", from: 2500, to: 6500, step: 100, suffix: " K" }
        ]}
    ]
    readonly property var keyboardSchema: [
        { title: "Розкладки", icon: "\uf11c", items: [
            { type: "layouts", key: "input:kb_layout", label: "Розкладки", hint: "порядок = порядок перемикання" },
            { type: "choice", key: "input:kb_options", label: "Перемикання мови", options: [
                { v: "grp:alt_shift_toggle", t: "Alt+Shift" }, { v: "grp:ctrl_shift_toggle", t: "Ctrl+Shift" },
                { v: "grp:caps_toggle", t: "CapsLock" }, { v: "grp:win_space_toggle", t: "Win+Space" } ] }
        ]},
        { title: "Набір тексту", icon: "\uf031", items: [
            { type: "slider", key: "input:repeat_delay", label: "Затримка перед повтором", from: 150, to: 1000, step: 10, suffix: " мс" },
            { type: "slider", key: "input:repeat_rate", label: "Швидкість повтору", from: 5, to: 60, suffix: " /с" },
            { type: "toggle", key: "input:numlock_by_default", label: "Num Lock увімкнений одразу", hint: "у системі, на екрані входу, на екрані блокування і в консолях (спитає пароль)" }
        ]},
        { title: "Підсвітка клавіатури", icon: "\uf11c", items: [
            { type: "kbdlight", key: "kbd", label: "" }
        ]}
    ]
    readonly property var mouseSchema: [
        { title: "Миша", icon: "\uf245", items: [
            { type: "slider", key: "input:sensitivity", label: "Чутливість", from: -1, to: 1, step: 0.05, decimals: 2 },
            { type: "choice", key: "input:accel_profile", label: "Прискорення", options: [ { v: "", t: "Адаптивне" }, { v: "flat", t: "Без прискорення" } ] },
            { type: "toggle", key: "input:natural_scroll", label: "Природна прокрутка (миша)" },
            { type: "slider", key: "input:scroll_factor", label: "Швидкість прокрутки", from: 0.2, to: 3, step: 0.1, decimals: 1, suffix: "×" },
            { type: "toggle", key: "input:left_handed", label: "Для лівші (поміняти кнопки)" },
            { type: "choice", key: "input:follow_mouse", label: "Фокус вікна", options: [
                { v: 1, t: "За мишею" }, { v: 2, t: "Клік" }, { v: 0, t: "Не міняти" } ] }
        ]},
        { title: "Тачпад", icon: "\uf0a6", items: [
            { type: "toggle", key: "input:touchpad:tap-to-click", label: "Дотик = клік" },
            { type: "toggle", key: "input:touchpad:natural_scroll", label: "Природна прокрутка" },
            { type: "toggle", key: "input:touchpad:disable_while_typing", label: "Вимикати, коли друкуєш" },
            { type: "toggle", key: "input:touchpad:drag_lock", label: "Фіксація перетягування" },
            { type: "slider", key: "input:touchpad:scroll_factor", label: "Швидкість прокрутки", from: 0.2, to: 3, step: 0.1, decimals: 1, suffix: "×" }
        ]},
        { title: "Курсор", icon: "\uf245", items: [
            { type: "cursors", key: "cursor.theme", label: "Тема курсора", hint: "діє одразу; деякі вже відкриті програми підхоплять після перезапуску" },
            { type: "slider", key: "cursor.size", label: "Розмір", from: 16, to: 64, step: 4, suffix: " px" },
            { type: "toggle", key: "cursor:hide_on_key_press", label: "Ховати курсор, коли друкуєш" },
            { type: "slider", key: "cursor:inactive_timeout", label: "Ховати нерухомий курсор через", from: 0, to: 30, step: 1, suffix: " с", zeroText: "ніколи" }
        ]}
    ]
    readonly property var windowsSchema: [
        { title: "Поведінка вікон", icon: "\uf2d2", items: [
            { type: "choice", key: "general:layout", label: "Розмітка", options: [
                { v: "dwindle", t: "Плитки" }, { v: "master", t: "Головне + стос" }, { v: "scrolling", t: "Стрічка" } ] },
            { type: "toggle", key: "general:resize_on_border", label: "Змінювати розмір, тягнучи за край" },
            { type: "toggle", key: "misc:focus_on_activate", label: "Перемикатись на вікно, що просить уваги" },
            { type: "toggle", key: "binds:workspace_back_and_forth", label: "Повторне натискання столу — назад" },
            { type: "toggle", key: "misc:animate_manual_resizes", label: "Анімувати зміну розміру" }
        ]},
        { title: "Неактивні вікна", icon: "\uf06e", items: [
            { type: "toggle", key: "decoration:dim_inactive", label: "Затемнювати неактивні вікна" },
            { type: "slider", key: "decoration:dim_strength", label: "Сила затемнення", from: 0, to: 1, step: 0.05, decimals: 2 }
        ]}
    ]
    readonly property var notifySchema: [
        { title: "Сповіщення", icon: "\uf0f3", items: [
            { type: "toggle", key: "notify.dnd", label: "Не турбувати", hint: "сповіщення не спливатимуть, але лишаться в центрі" },
            { type: "button", label: "Центр сповіщень", text: "Відкрити", cmd: "swaync-client -t -sw" }
        ]},
        { title: "Звуки інтерфейсу", icon: "\uf028", items: [
            { type: "toggle", key: "sound.enabled", label: "Звуки", hint: "помилки, флешки, зарядка, знімки екрана, блокування, теми — у стилі поточної теми" },
            { type: "toggle", key: "sound.volumeFeedback", label: "Звук при зміні гучності", hint: "короткий «тук» на новій гучності, як у KDE" },
            { type: "slider", key: "sound.volume", label: "Гучність звуків", from: 5, to: 100, step: 5, suffix: "%" },
            { type: "button", label: "Прослухати всі звуки теми", hint: "по черзі, ~20 с", text: "Грати", cmd: "~/.config/wallpapers_QS/tools/sfx test" }
        ]}
    ]

    function handleEscape() {
        if (root.page === 0 && keybinds.query !== "") {
            keybinds.clearSearch();
            return;
        }
        Qt.quit();
    }

    Bridge {
        id: bridge
        dir: Quickshell.shellDir
    }

    // Керування ззовні (для биндів і тестів):
    //   qs ipc -p ~/.config/quickshell-settings/shell.qml call settings openPage 2
    IpcHandler {
        target: "settings"

        function openPage(index: int): void { root.page = index; }
        function closeWindow(): void { Qt.quit(); }
        function refresh(): void { bridge.refreshAll(); }
        function status(): string { return bridge.status; }
    }

    PanelWindow {
        id: win

        implicitWidth: 940
        implicitHeight: 720
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hypr-settings"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        Shortcut {
            sequence: "Escape"
            onActivated: root.handleEscape()
        }

        // ------------------------------------------------ тінь навколо скла ---
        Item {
            id: frame
            anchors.fill: parent
            anchors.margins: 20

            // (раніше тут було 6 тонких рамок-«тіней» — вони виглядали як смужки довкола вікна)
            Rectangle {
                id: panelMask
                anchors.fill: parent
                radius: 22
                color: "black"
                visible: false
                layer.enabled: true
                antialiasing: true
            }
            // --------------------------------------------------- скло ------
            Rectangle {
                id: panel
                anchors.fill: parent
                radius: 22
                border.width: 1
                border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)
                antialiasing: true
                // clip: true обрізав би вміст ПРЯМОКУТНИКОМ — плями й блиск вилазили за заокруглені кути
                // (звідси «смужки» й гострі краї). Тепер вміст обрізається маскою точно по формі скла.
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: panelMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                // напівпрозоре скло: крізь нього видно розмиті шпалери (layer_rule blur)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.90) }
                    GradientStop { position: 0.6; color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.90) }
                    GradientStop { position: 1.0; color: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.90) }
                }

                // декоративні акцентні плями
                Rectangle {
                    width: 560; height: 560; radius: 280
                    x: 470; y: -300
                    color: Theme.accent; opacity: 0.05
                }
                Rectangle {
                    width: 420; height: 420; radius: 210
                    x: -180; y: 380
                    color: Theme.accent2; opacity: 0.05
                }
                // верхній блиск скла (з відступами — не заходить у заокруглені кути)
                Rectangle {
                    anchors.left: parent.left; anchors.leftMargin: 28
                    anchors.right: parent.right; anchors.rightMargin: 28
                    anchors.top: parent.top; anchors.topMargin: 1
                    height: 1
                    color: Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.30)
                }

                // ================================================= сайдбар ===
                Item {
                    id: side
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    width: 226

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Qt.rgba(0.0, 0.0, 0.0, 0.22)
                        border.width: 1
                        border.color: Theme.strokeSoft
                    }

                    // логотип
                    Rectangle {
                        id: logo
                        x: 16; y: 18
                        width: 34; height: 34
                        radius: 10
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: Theme.accent2 }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "H"
                            color: Theme.bg0
                            font.family: Theme.mono
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        anchors.left: logo.right
                        anchors.leftMargin: 10
                        anchors.top: logo.top
                        anchors.topMargin: 2
                        spacing: 1
                        Text {
                            text: "Hyprland"
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "НАЛАШТУВАННЯ"
                            color: Theme.textMute
                            font.family: Theme.mono
                            font.pixelSize: 8
                            font.letterSpacing: 2.2
                        }
                    }

                    // навігація
                    Column {
                        id: nav
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.top: logo.bottom
                        anchors.topMargin: 24
                        spacing: 4
                        // висота пункту підлаштовується, щоб останній не налазив на плашку теми внизу
                        readonly property int count: navRep.count
                        readonly property real itemH: Math.max(28, Math.min(40, (sideFoot.y - nav.y - 12 - spacing * (count - 1)) / Math.max(1, count)))

                        Repeater {
                            id: navRep
                            // p — номер сторінки (порядок у меню — як у «Параметрах системи» KDE)
                            model: [
                                { "p": 4, "icon": "\uf0e7", "label": "Живлення та сон" },
                                { "p": 5, "icon": "\uf108", "label": "Екран" },
                                { "p": 6, "icon": "\uf11c", "label": "Клавіатура" },
                                { "p": 7, "icon": "\uf245", "label": "Миша й тачпад" },
                                { "p": 8, "icon": "\uf2d2", "label": "Вікна" },
                                { "p": 10, "icon": "\uf0a0", "label": "Диски" },
                                { "p": 11, "icon": "\uf03e", "label": "Теми" },
                                { "p": 1, "icon": "\uf1fc", "label": "Оформлення" },
                                { "p": 2, "icon": "\uf11b", "label": "Ефекти та ігри" },
                                { "p": 9, "icon": "\uf0f3", "label": "Сповіщення" },
                                { "p": 0, "icon": "\uf084", "label": "Комбінації клавіш" },
                                { "p": 3, "icon": "\uf2db", "label": "Про систему" }
                            ]

                            Item {
                                required property var modelData
                                required property int index
                                width: nav.width
                                height: nav.itemH

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: root.page === modelData.p
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
                                        : (navMa.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06) : "transparent")
                                    border.width: root.page === modelData.p ? 1 : 0
                                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Rectangle {
                                    visible: root.page === modelData.p
                                    width: 3
                                    height: 18
                                    radius: 2
                                    color: Theme.accent
                                    anchors.left: parent.left
                                    anchors.leftMargin: -2
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    id: navIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    color: root.page === modelData.p ? Theme.accent : Theme.textMute
                                    font.family: Theme.mono
                                    font.pixelSize: 14
                                }

                                Text {
                                    anchors.left: navIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: root.page === modelData.p ? Theme.text : Theme.textDim
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: navMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.page = modelData.p
                                }
                            }
                        }
                    }

                    // низ сайдбара: тема, версія, підказка
                    Column {
                        id: sideFoot
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        spacing: 7

                        Rectangle {
                            width: parent.width
                            height: 30
                            radius: 9
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)

                            Rectangle {
                                id: themeDot
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: Theme.accent
                            }
                            Text {
                                anchors.left: themeDot.right
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: Theme.name.length ? Theme.name + " · Pause — змінити" : "Тема"
                                color: Theme.textDim
                                font.family: Theme.mono
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: "Esc — закрити · Win+I"
                            color: Theme.textMute
                            font.family: Theme.mono
                            font.pixelSize: 8
                        }
                    }
                }

                // ================================================== контент ===
                Item {
                    id: main
                    anchors.left: side.right
                    anchors.leftMargin: 22
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14

                    Item {
                        id: header
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 56

                        Text {
                            id: pageTitle
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: root.titles[root.page]
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.top: pageTitle.bottom
                            anchors.topMargin: 5
                            text: root.subtitles[root.page]
                            color: Theme.textMute
                            font.family: Theme.mono
                            font.pixelSize: 9
                        }

                        Rectangle {
                            id: closeBtn
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width: 30
                            height: 30
                            radius: 9
                            color: closeMa.containsMouse ? Qt.rgba(1, 0.439, 0.588, 0.18) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.05)
                            border.width: 1
                            border.color: closeMa.containsMouse ? Qt.rgba(1, 0.439, 0.588, 0.45) : Theme.strokeSoft
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2715"
                                color: closeMa.containsMouse ? Theme.danger : Theme.textMute
                                font.family: Theme.mono
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.quit()
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Theme.strokeSoft
                        }
                    }

                    Item {
                        id: pageHost
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: header.bottom
                        anchors.topMargin: 14
                        anchors.bottom: statusBar.top
                        anchors.bottomMargin: 10

                        KeybindsPage {
                            id: keybinds
                            anchors.fill: parent
                            visible: root.page === 0
                            bridge: bridge
                        }
                        AppearancePage {
                            anchors.fill: parent
                            visible: root.page === 1
                            bridge: bridge
                        }
                        ThemePage {
                            anchors.fill: parent
                            visible: root.page === 2
                            bridge: bridge
                        }
                        SchemaPage { anchors.fill: parent; visible: root.page === 4; schema: root.powerSchema }
                        SchemaPage { anchors.fill: parent; visible: root.page === 5; schema: root.displaySchema }
                        SchemaPage { anchors.fill: parent; visible: root.page === 6; schema: root.keyboardSchema }
                        SchemaPage { anchors.fill: parent; visible: root.page === 7; schema: root.mouseSchema }
                        SchemaPage { anchors.fill: parent; visible: root.page === 8; schema: root.windowsSchema }
                        SchemaPage { anchors.fill: parent; visible: root.page === 9; schema: root.notifySchema }
                        SchemaPage { anchors.fill: parent; visible: root.page === 10; schema: root.disksSchema }
                        SchemaPage { anchors.fill: parent; visible: root.page === 11; schema: root.themesSchema }
                        SystemPage {
                            anchors.fill: parent
                            visible: root.page === 3
                            bridge: bridge
                        }
                    }

                    Item {
                        id: statusBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 26

                        Rectangle {
                            id: statusDot
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            visible: bridge.busy || bridge.status !== ""     // без повідомлення — без зайвої крапки
                            color: bridge.status === ""
                                ? Theme.textMute
                                : (bridge.statusOk ? Theme.ok : Theme.danger)

                            SequentialAnimation on opacity {
                                running: bridge.busy
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 460 }
                                NumberAnimation { to: 1.0; duration: 460 }
                            }
                        }

                        Text {
                            anchors.left: statusDot.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: bridge.busy ? (bridge.status !== "" ? bridge.status : "Виконую…") : bridge.status
                            color: bridge.status === ""
                                ? Theme.textMute
                                : (bridge.statusOk ? Theme.textDim : Theme.danger)
                            font.family: Theme.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        bridge.refreshAll();
        console.log("[hypr-settings] shellDir=" + Quickshell.shellDir);
    }
}
