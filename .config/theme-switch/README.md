# theme-switch — перемикання шпалер + теми столу

Дві теми, кожна = parallax-шпалери (Quickshell) + палітра для панелі, сповіщень, термінала,
wofi та рамок вікон Hyprland.

| # | Тема | Шпалери | Палітра |
|---|------|---------|---------|
| 1 | Мадара | `bg_parallax_MDRG` | як було (капучино, фіолетово-синя) |
| 2 | Азур  | `bg_parallax_TEST_3` | синьо-голуба: акцент `#7fdcff`, фон `#0b1020`–`#1a2a52` |

## Користування

```bash
theme-switch list          # список тем
theme-switch apply 2       # застосувати (можна: azure / азур / test3 / blue)
theme-switch apply madara  # назад
theme-switch toggle        # швидко перемкнути між двома
theme-switch current       # яка зараз
theme-switch menu          # меню wofi
```

Гарячі клавіші (з `~/.config/hypr/hyprland.lua`):
- **Pause / Break** — меню вибору теми (на зайнятому столі автоматично стрибає на порожній і повертає назад)
- **SUPER + ALT + B** — те саме меню
- **SUPER + ALT + T** — перемкнути тему туди-сюди
- **Meta (утримати ~0.3 с)** — лаунчер **виїжджає з-під панелі** (як меню Пуск у KDE); комбінації з Meta не конфліктують (`long_press`)
- **SUPER + Space / SUPER + R** — той самий лаунчер
  (`~/.config/quickshell-launcher/`, запуск `bin/app-menu` → режим `bar`; `--center` — по центру; 79 програм, пошук, драг-скролбар, ↑↓/Enter,
  знімок fullscreen-вікон і повернення у fullscreen після закриття)
- **Print** — скріншот усього екрана, **Shift+Print** / **SUPER+Shift+S** — область
  (`bin/screenshot`: пробує Spectacle, а якщо він на Hyprland не зберігає файл — grim/slurp;
  зберігає у `~/Картинки/Знімки вікон`, копіює в буфер і показує сповіщення)
- **SUPER + ALT + V** — панель керування: звук/мікрофон (з бустом до 150 %), яскравість,
  перемикачі BT/DND/ігровий режим, вибір sink/source (`~/.config/quickshell-cc/`, запуск `bin/cc`)
- **SUPER + ALT + S** — налаштування Hyprland: усі комбінації (з пошуком), слайдери оформлення
  з живим застосуванням, перемикання теми/ігрового режиму (`~/.config/quickshell-settings/`,
  запуск `bin/hypr-settings`)
- **SUPER + F** — «на весь екран» із панеллю (maximize), **F11** — справжній fullscreen (панель ховається)
- **SUPER + ALT + G** — ігровий режим вручну

Меню тем не висне поверх програм: `theme-menu` дивиться вікна на активному столі й, якщо вони є,
переходить на вільний стіл, показує меню там і повертає назад. Для ручного обходу: `theme-menu --force`.

## Ігровий режим

`bin/game-mode on|off|toggle|status` + `bin/game-watch` (автодетект).

- **Автоматично**: `game-watch` слухає сокет подій Hyprland; щойно з'являється fullscreen-вікно —
  вмикає режим, коли таких вікон не лишилось — вимикає (антидребезгінг 2 с, перепідключення при обриві,
  `flock` проти двох екземплярів).
- **Вручну**: `SUPER + ALT + G` або клік по іконці 󰊗/󰊓 у панелі.
- **Що робить**: зберігає поточні значення Hyprland у `state/game-mode.json`, далі blur/animations/shadows
  вимкнено, `rounding 0`, `gaps 0`, `opacity 1.0`, `allow_tearing true`. Після вимкнення відновлює
  рівно те, що було (тобто блюр і прозорість теми не губляться).
- GPU: `nvidia-smi -pm 1` / `-lgc` вимагають root — без нього крок пропускається з записом у
  `logs/game-mode.log` (без sudo-запитів).

## Опції / іконки

- Лаунчер (`wofi --show drun`) має іконки застосунків: `~/.config/wofi/config` (`allow_images=true`,
  `image_size=28`) + стиль `#img` у палітрі теми.
- Меню тем — скляна панель з іконками, галочкою поточної теми й підсвіткою.

## Важливо про середовище (інакше ламається «магія»)

`qs` (шпалери) та `waybar` мусять стартувати з `HYPRLAND_INSTANCE_SIGNATURE`, `WAYLAND_DISPLAY`
і `XDG_RUNTIME_DIR` у середовищі. Без них:

- паралакс (рух шарів за курсором) завмирає — `Parallax.qml` смикає `hyprctl cursorpos`;
- waybar вимикає модулі `hyprland/workspaces`, `hyprland/window`, `hyprland/language`
  («HYPRLAND_INSTANCE_SIGNATURE was not set») — панель стає порожньою посередині.

Це вже враховано в `bin/theme-switch` (функція `ensure_hypr_env`) і `bin/qs-start`.

## Що саме змінюється

- `~/.config/waybar/style.css` — замінюється лише блок `@define-color` вгорі, тіло файлу не чіпається;
- `~/.config/swaync/style.css` — так само (далі `swaync-client --reload-css`);
- `~/.config/wofi/style.css` — повністю з теми;
- `~/.config/kitty/kitty.conf` — кольори (`background`, `color0..15`, курсор…), плюс `kitty @ set-colors` для вже відкритих вікон;
- `~/.config/hypr/hyprland.lua` — `active_border` / `inactive_border` (живо через `hyprctl keyword`, і у файлі — щоб пережило перезапуск);
- Quickshell-шпалери: вбиває старий `qs -p …/shell.qml` (+cava) і піднімає новий;
- waybar перезапускається, щоб підхопити палітру.

Стан зберігається у `state/current`; з автозапуску Hyprland тепер викликається `bin/qs-start`,
який читає цей файл — тобто після ребуту буде та тема, яку обрано останньою.

## Додати третю тему

```bash
cp -r themes/2-azure themes/3-moon
# 1. у themes/3-moon/theme.conf змінити ID / LABEL / QS_DIR
# 2. поправити кольори у waybar.css.head, swaync.css.head, kitty.colors, wofi.css
# 3. додати id у resolve() в bin/theme-switch (case)
# 4. theme-switch apply 3
```

Для кожної теми Quickshell-шпалер кольори візуалізатора/плеєра живуть у її власному
`settings.json` (поле `visualizer.barsColorTop/barsColorBottom`, `player.colors`, `clock.color`).

## Відкат

Оригінали всіх конфігів збережено у `backup/<дата-час>/`, а поруч із зміненими файлами
лежать `*.theme-bak`.
