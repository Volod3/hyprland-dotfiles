# hypr-settings — Quickshell-центр налаштувань Hyprland «Азур»

Окремий Quickshell-застосунок (не чіпає `~/.config/hypr/**`, `waybar`, `wallpapers_QS`, `quickshell-cc`).
Вікно — Wayland layer-shell поверхня (`Overlay`, по центру, 900×620, скло/скруглення/тінь),
закривається `Esc`.

## Запуск

```bash
~/.config/theme-switch/bin/hypr-settings          # toggle
~/.config/theme-switch/bin/hypr-settings start    # відкрити
~/.config/theme-switch/bin/hypr-settings stop     # закрити
~/.config/theme-switch/bin/hypr-settings status   # стан
qs -p ~/.config/quickshell-settings/shell.qml     # напряму
```

Бинд у `~/.config/hypr/hyprland.lua` (уже доданий):

```lua
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("/home/voltimeter/.config/theme-switch/bin/hypr-settings"))
```

Лог: `~/.config/theme-switch/logs/hypr-settings.log`.

## Розділи

1. **Комбінації клавіш** — парсинг `~/.config/hypr/hyprland.lua` (регекс по `hl.bind(...)`,
   розкриття `for i = 1, 10`, підстановка `mainMod`/`terminal`/`menu`), таблиця «комбінація → дія»
   українською, пошук по рядку. Файл лише читається.
2. **Оформлення** — слайдери/перемикачі `gaps_in`, `gaps_out`, `border_size`, `rounding`,
   `active_opacity`, `inactive_opacity`, `blur.enabled/size/passes`, `animations.enabled`.
   Кожна зміна: `hyprctl eval 'hl.config({...})'` → перевірка `hyprctl getoption` → запис у
   `overrides.json`. Кнопки: «Скинути до теми» (типові значення з `defaults.json`),
   «Відновити збережене» (з `overrides.json`) і «Застосувати».
3. **Тема та ефекти** — `theme-switch apply 1|2` / `toggle`, ігровий режим (`game-mode toggle` + статус),
   оновлення шпалер (`theme-switch apply current`), скріншот (`spectacle`, за відмови — `grim`),
   поточна тема зі `state/current`.
4. **Про систему** — модель, CPU, GPU, RAM, `hyprctl version`, ядро, екран.

## Файли

```
shell.qml                     вікно, сайдбар, статус-бар, IpcHandler
components/Theme.qml           палітра «Азур» (singleton)
components/Bridge.qml          Process/JSON-міст до bin/qsettings-ctl
components/{Btn,Toggle,SettingSlider,SectionTitle}.qml
pages/{Keybinds,Appearance,Theme,System}Page.qml
bin/qsettings-ctl             python3-бекенд (hyprctl eval/getoption, парсер lua, sysinfo)
defaults.json                 типові значення теми (для «Скинути до теми»)
overrides.json                останні застосовані значення (для «Відновити збережене»)
cache/binds.json              кеш розібраних биндів
screenshots/page0..3.png      скріншоти розділів
```

## Бекенд вручну

```bash
bin/qsettings-ctl opts                 # поточні значення + defaults + overrides
bin/qsettings-ctl set general:gaps_in 8
bin/qsettings-ctl apply '{"decoration:rounding":14}'
bin/qsettings-ctl reset                # скинути до теми
bin/qsettings-ctl restore              # з overrides.json
bin/qsettings-ctl binds                # -> cache/binds.json
bin/qsettings-ctl state | sysinfo | shot
bin/qsettings-ctl theme 1|2|toggle|current
bin/qsettings-ctl game toggle|status
bin/qsettings-ctl wallpaper
```

IPC (для скриптів/тестів):

```bash
qs ipc -p ~/.config/quickshell-settings/shell.qml call settings openPage 1
qs ipc -p ~/.config/quickshell-settings/shell.qml call settings closeWindow
```

## Скло

Прозорість панелі + `layer_rule` з блюром додає обгортка при старті
(`hl.layer_rule({ match = { namespace = "^hypr-settings$" }, blur = true })`), тому конфіг
Hyprland не змінюється — правило живе лише в поточній сесії.

## Особливості середовища

- Hyprland 0.57 з Lua-конфігом: `hyprctl keyword` майже завжди «unknown request», тому всі опції
  ставляться через `hyprctl eval`, а результат звіряється з `hyprctl getoption`.
- `spectacle -f -b -n` у цій сесії не віддає файл (rc=1/зависає) → бекенд автоматично робить
  знімок через `grim -o <focused output>` у той самий `/tmp/hypr-settings-*.png`.
