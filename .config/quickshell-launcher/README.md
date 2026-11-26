# Азур · Лаунчер застосунків (Quickshell)

Заміна `wofi --show drun`, яка в цій системі не рендерить іконки.
Скляна панель по центру зверху, пошук, іконки з .desktop-файлів, керування
клавіатурою та мишею.

## Запуск

```bash
~/.config/theme-switch/bin/app-menu          # toggle: відкрити / закрити
~/.config/theme-switch/bin/app-menu --status # running pid=… / stopped
~/.config/theme-switch/bin/app-menu --query telegram   # відкрити з запитом
```

Прив'язка в Hyprland (`~/.config/hypr/…`):

```
bind = $mainMod, D, exec, /home/voltimeter/.config/theme-switch/bin/app-menu
```

Лог запуску: `~/.config/theme-switch/logs/app-menu.log`
Лог самого QML (console.log): `/run/user/1000/quickshell/by-id/*/log.log`

## Керування

| Клавіша | Дія |
|---|---|
| будь-який текст | фільтр по назві / keywords / exec / категоріях |
| ↑ ↓ / Tab / PgUp PgDn | переміщення по списку |
| Enter | запуск вибраного |
| Esc | закрити |
| клік поза панеллю | закрити |
| клік по рядку | запуск |

## Файли

- `shell.qml` — вікно-шар (WlrLayershell Overlay), пошук, фільтр, запуск.
- `AppRow.qml` — рядок: іконка, назва з підсвіткою співпадіння, підзаголовок.
- `apps.py` — парсер `.desktop` + пошук файлів іконок, друкує JSON.
  Перевірка: `python3 ~/.config/quickshell-launcher/apps.py --stats`

`apps.py` читає `/usr/share/applications`, `/usr/local/share/applications`,
`~/.local/share/applications` (користувацькі перекривають системні за іменем
файлу), виключає `NoDisplay=true` / `Hidden=true`, віддає перевагу
`Name[uk]`, вирізає field-codes з `Exec`, шукає іконку як файл:
`Icon=` з `/` → шлях; інакше hicolor (`~/.local/share/icons` → `/usr/share/icons`,
розміри 256…24, потім `scalable`), далі breeze/Adwaita (усі підкаталоги,
включно з `devices`, `preferences`), потім `/usr/share/pixmaps`.

## Запуск застосунків

- `Terminal=true` → `kitty -e sh -c '<Exec>'`
- інакше → `<Exec>` через `sh -c`
- обидва варіанти — `Quickshell.execDetached(["setsid", "-f", "sh", "-c", …])`,
  щоб лаунчер не тримав дочірній процес і той пережив закриття панелі.
