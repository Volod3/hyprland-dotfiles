#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
apps.py — збирач списку застосунків для Quickshell-лаунчера.

Друкує JSON-масив у stdout:
  [{"name":..,"name_native":..,"exec":..,"terminal":bool,
    "icon":..,"categories":[..],"keywords":[..],"comment":..,"id":..}, ...]

Особливості:
  * читає .desktop з /usr/share, /usr/local/share, ~/.local/share (у цьому ж
    порядку пріоритету — користувацькі перекривають системні за іменем файлу);
  * ховає NoDisplay=true / Hidden=true / Type!=Application;
  * Icon= може бути абсолютним шляхом або темою-іменем — шукаємо файл самі
    (PNG у пріоритеті: SVG у Qt інколи не рендериться у скріншоті);
  * з Exec вирізає field-codes (%f %U %i …), Terminal=true позначає прапорцем.

Використання:  python3 apps.py [--stats]
"""
import json
import os
import re
import sys

HOME = os.path.expanduser("~")

APP_DIRS = [
    os.path.join(HOME, ".local/share/applications"),
    "/usr/local/share/applications",
    "/usr/share/applications",
]

# Порядок пошуку растрових/векторних іконок. PNG — першими (надійніше).
HICOLOR = "/usr/share/icons/hicolor"
# теки-корені тем (користувацькі — першими, вони перекривають системні)
ICON_ROOTS = [
    os.path.join(HOME, ".local/share/icons"),
    os.path.join(HOME, ".icons"),
    "/usr/share/icons",
]
HICOLOR_ROOTS = [os.path.join(r, "hicolor") for r in ICON_ROOTS]
SIZE_DIRS = ["256x256", "128x128", "64x64", "48x48", "96x96", "512x512", "32x32", "24x24"]
ICON_EXTS = [".png", ".svg", ".svgz", ".xpm"]

FIELD_CODE = re.compile(r"%[fFuUdDnNickvm]")


def _unescape(val):
    """Розкодовує escapes .desktop-файлу."""
    out = []
    i = 0
    while i < len(val):
        ch = val[i]
        if ch == "\\" and i + 1 < len(val):
            nxt = val[i + 1]
            out.append({"s": " ", "n": "\n", "t": "\t", "r": "\r",
                        "\\": "\\"}.get(nxt, nxt))
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out).strip()


def _split_list(val):
    """Розбиває ; -список з повагою до \\;"""
    parts, cur = [], []
    i = 0
    while i < len(val):
        ch = val[i]
        if ch == "\\" and i + 1 < len(val):
            cur.append(val[i:i + 2])
            i += 2
            continue
        if ch == ";":
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    if cur:
        parts.append("".join(cur).strip())
    return [p for p in (_unescape(x) for x in parts) if p]


def parse_desktop(path):
    """Повертає dict ключів секції [Desktop Entry] (перший однойменний файл)."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    except OSError:
        return None

    section = None
    data = {}
    for line in raw.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1]
            continue
        if section != "Desktop Entry" or "=" not in s:
            continue
        key, _, val = s.partition("=")
        data[key.strip()] = val  # останній перемагає, як у специфікації
    return data


def clean_exec(exec_line):
    """Прибирає field-codes і зайві пробіли; лишає лапки як є."""
    txt = FIELD_CODE.sub("", exec_line)
    txt = re.sub(r"\s+", " ", txt).strip()
    return txt


def resolve_icon(icon, icon_id=""):
    """Знаходить реальний файл іконки. Повертає абсолютний шлях або ''."""
    if not icon:
        icon = icon_id
    if not icon:
        return ""
    icon = icon.strip().strip('"')
    if not icon:
        return ""

    # 1) абсолютний шлях
    if "/" in icon:
        cand = os.path.expanduser(icon)
        if os.path.isfile(cand):
            return cand
        return ""

    names = [icon]
    # деякі .desktop вказують ім'я з розширенням
    root, ext = os.path.splitext(icon)
    if ext in ICON_EXTS:
        names = [root]
    else:
        ext = ""

    def probe(base, nm):
        for e in ([ext] if ext else ICON_EXTS):
            p = os.path.join(base, nm + e)
            if os.path.isfile(p):
                return p
        return ""

    # 2) hicolor у порядку розмірів (усі корені тем: спершу ~/.local/share/icons)
    for nm in names:
        for hroot in HICOLOR_ROOTS:
            for size in SIZE_DIRS:
                p = probe(os.path.join(hroot, size, "apps"), nm)
                if p:
                    return p
            # 3) scalable (svg)
            p = probe(os.path.join(hroot, "scalable", "apps"), nm)
            if p:
                return p

    # 4) breeze / breeze-dark / Adwaita
    for theme in ("breeze", "breeze-dark", "Adwaita", "default", "locolor"):
        base = os.path.join("/usr/share/icons", theme)
        if not os.path.isdir(base):
            continue
        # breeze: apps/<size>/name.svg
        apps = os.path.join(base, "apps")
        if os.path.isdir(apps):
            try:
                for sub in sorted(os.listdir(apps)):
                    p = probe(os.path.join(apps, sub), names[0])
                    if p:
                        return p
            except OSError:
                pass
        # Adwaita: <size>/apps/name.png
        try:
            for sub in sorted(os.listdir(base)):
                p = probe(os.path.join(base, sub, "apps"), names[0])
                if p:
                    return p
        except OSError:
            pass

    # 5) глибший фолбек: будь-який підкаталог теми (devices/printers, preferences,
    #    actions, places…) — деякі KDE-модулі посилаються на такі іконки.
    for theme in ("breeze", "breeze-dark", "Adwaita"):
        base = os.path.join("/usr/share/icons", theme)
        if not os.path.isdir(base):
            continue
        try:
            cats = sorted(os.listdir(base))
        except OSError:
            continue
        for cat in cats:
            cdir = os.path.join(base, cat)
            if not os.path.isdir(cdir):
                continue
            try:
                subs = sorted(os.listdir(cdir), reverse=True)  # більші розміри першими
            except OSError:
                continue
            for sub in subs:
                sdir = os.path.join(cdir, sub)
                if not os.path.isdir(sdir):
                    p = probe(cdir, sub)  # іконка лежить прямо в каталозі
                    if p:
                        return p
                    continue
                for nm in names:
                    p = probe(sdir, nm)
                    if p:
                        return p
    for nm in names:
        p = probe("/usr/share/pixmaps", nm)
        if p:
            return p

    # 6) глобальний пошук по іменах у типових теках (повільно, але рідко)
    return ""


def localized(data, key):
    """Name[uk] → Name[en] → Name."""
    for loc in ("uk", "uk_UA", "en", "en_US"):
        v = data.get("%s[%s]" % (key, loc))
        if v:
            return _unescape(v), loc
    v = data.get(key)
    if v:
        return _unescape(v), "C"
    return "", ""


def collect():
    seen = {}   # basename .desktop -> entry (перший виграє = вищий пріоритет)
    order = []
    hidden = {"nodisplay": 0, "hidden": 0, "notype": 0, "noexec": 0}

    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        try:
            files = sorted(os.listdir(d))
        except OSError:
            continue
        for fn in files:
            if not fn.endswith(".desktop"):
                continue
            if fn in seen:
                continue  # уже взято з теки з вищим пріоритетом
            data = parse_desktop(os.path.join(d, fn))
            if data is None:
                continue

            if data.get("Type", "Application").strip() != "Application":
                hidden["notype"] += 1
                continue
            if data.get("NoDisplay", "").strip().lower() == "true":
                hidden["nodisplay"] += 1
                continue
            if data.get("Hidden", "").strip().lower() == "true":
                hidden["hidden"] += 1
                continue

            exec_line = clean_exec(data.get("Exec", ""))
            if not exec_line:
                hidden["noexec"] += 1
                continue

            name, loc = localized(data, "Name")
            if not name:
                continue
            native = _unescape(data.get("Name", "")) or name
            comment, _ = localized(data, "Comment")

            kw = []
            for suffix in ("uk", "uk_UA", "en", "en_US", ""):
                k = "Keywords[%s]" % suffix if suffix else "Keywords"
                if data.get(k):
                    kw = _split_list(data[k])
                    break

            entry = {
                "name": name,
                "name_native": native,
                "name_loc": loc,
                "exec": exec_line,
                "terminal": data.get("Terminal", "").strip().lower() == "true",
                "icon": resolve_icon(data.get("Icon", ""), os.path.splitext(fn)[0]),
                "categories": _split_list(data.get("Categories", "")),
                "keywords": kw,
                "comment": comment,
                "id": fn,
                "wmclass": data.get("StartupWMClass", ""),
            }
            seen[fn] = entry
            order.append(entry)

    # сортуємо за назвою (українська/будь-яка — casefold)
    order.sort(key=lambda e: (e["name"].casefold(), e["id"]))
    return order, hidden


def main():
    apps, hidden = collect()
    with_icon = sum(1 for a in apps if a["icon"])
    stats = {
        "apps": len(apps),
        "with_icon": with_icon,
        "without_icon": len(apps) - with_icon,
        "hidden": hidden,
        "dirs": [d for d in APP_DIRS if os.path.isdir(d)],
    }
    if "--stats" in sys.argv:
        print(json.dumps(stats, ensure_ascii=False, indent=2))
        print("\nбез іконки:", ", ".join(a["name"] for a in apps if not a["icon"])[:800])
        return
    sys.stdout.write(json.dumps(apps, ensure_ascii=False))


if __name__ == "__main__":
    main()
