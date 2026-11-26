# Азур · Центр керування (Quickshell)

Панель керування у стилі темно-синього скла для Hyprland + Quickshell 0.3.x.

## Запуск

```bash
~/.config/theme-switch/bin/cc          # toggle: відкрити / закрити
~/.config/theme-switch/bin/cc open     # тільки відкрити
~/.config/theme-switch/bin/cc close    # тільки закрити
~/.config/theme-switch/bin/cc status   # open (pid …) | closed
```

Закриття: `Esc`, клік поза панеллю, повторний запуск `cc`.

## Файли

| файл | призначення |
|---|---|
| `shell.qml` | сама панель (PanelWindow, WlrLayer Overlay, bottom-right) |
| `SlimSlider.qml` | скляний слайдер зі шкалою 0–150% і міткою 100% |
| `GlyphButton.qml` | кругла кнопка-глиф (mute тощо) |
| `PillButton.qml` | маленька кнопка «Звук →», «пристрої ▾» |
| `QuickTile.qml` | плитка швидкого перемикача |
| `DeviceRow.qml` | рядок вибору sink/source |
| `ccctl` | bash-бекенд: `status` → JSON, решта — дії |

Обгортка: `~/.config/theme-switch/bin/cc`, лог: `~/.config/theme-switch/logs/cc.log`.

## Бекенд (ccctl)

```bash
ccctl status                    # JSON: vol, mic, bright, sinks, sources, wifi, bt, dnd, game, bat, temp, cpu, ram
ccctl vol 120 | vol-mute
ccctl mic 80  | mic-mute
ccctl sink '<name>' | source '<name>'
ccctl bright 60
ccctl wifi toggle|on|off
ccctl bt   toggle|on|off
ccctl dnd  toggle|on|off
ccctl game toggle
ccctl pavu sink|source          # pavucontrol на вкладці виходу/входу
```

Стан опитується кожні ~900 мс; під час перетягування слайдера UI не перебивається
полінгом (`volDrag/micDrag/brightDrag`), запис у систему дебаунситься 90 мс.

## Постійний блюр (опційно)

`cc` додає layer-rule у рантаймі. Щоб правило жило в конфігу Hyprland, додайте в
`~/.config/hypr/hyprland.lua` поруч з іншими `hl.layer_rule(...)`:

```lua
hl.layer_rule({ name = "blur-quickshell-cc", match = { namespace = "^quickshell-cc$" },
                blur = true, ignore_alpha = 0.25 })
```

Без блюру панель теж читабельна (альфа скла ~0.70), просто менш «скляна».

## Хоткей

```lua
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("/home/voltimeter/.config/theme-switch/bin/cc"))
```
