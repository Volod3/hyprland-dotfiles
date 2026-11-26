import os
os.environ["QT_QPA_PLATFORM"] = "xcb"
import fcntl
import subprocess
import sys
import time

# одне меню за раз. Раніше другий запуск тихо виходив — і якщо перше меню зависло (Xwayland-меню
# Hyprland не закриває кліком повз нього), нове вже ніяк не відкривалось. Тепер старе закривається.
LOCK = "/tmp/kitty-ctxmenu.lock"
lock = open(LOCK, "a+")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError:
    try:
        lock.seek(0)
        old = int(lock.read().strip() or 0)
        if old > 1:
            os.kill(old, 15)
    except (ValueError, OSError):
        pass
    for _ in range(20):                      # чекаємо, поки старе меню відпустить блокування
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except OSError:
            time.sleep(0.05)
    else:
        sys.exit(0)
lock.seek(0); lock.truncate(); lock.write(str(os.getpid())); lock.flush()

try:
    from PyQt6.QtWidgets import QApplication, QMenu
    from PyQt6.QtGui import QAction, QCursor, QIcon
    from PyQt6.QtCore import QTimer
except ImportError:
    from PyQt5.QtWidgets import QApplication, QMenu, QAction
    from PyQt5.QtGui import QCursor, QIcon
    from PyQt5.QtCore import QTimer


def act(*a):
    subprocess.run(["kitten", "@", "action", *a])


def clear_all():
    # шрифт назад -> Ctrl+L у fish (лишається приглашення з директорією) -> чистимо історію
    act("change_font_size", "current", "0")
    time.sleep(0.25)
    act("send_text", "all", "\\x0c")
    time.sleep(0.25)
    act("clear_terminal", "scrollback", "active")


app = QApplication(sys.argv)
menu = QMenu()


def add(text, icon, shortcut, fn):
    a = QAction(QIcon.fromTheme(icon), text, menu)
    if shortcut:
        a.setShortcut(shortcut)
    a.triggered.connect(lambda: fn())
    menu.addAction(a)


add("Копіювати", "edit-copy", "Ctrl+C", lambda: act("copy_to_clipboard"))
add("Вставити", "edit-paste", "Ctrl+V", lambda: act("kitten", "smartpaste.py"))
menu.addSeparator()
add("Очистити термінал", "edit-clear-all", None, clear_all)
add("Скинути розмір шрифту", "zoom-original", "Ctrl+Shift+Backspace", lambda: act("change_font_size", "current", "0"))
add("Перечитати конфіг", "view-refresh", "Ctrl+Shift+F5", lambda: act("load_config_file"))

# ── щоб меню ніколи не «висіло» ──
#  • мишу прибрали з меню на ~1.5 с — закрити
#  • у меню так і не зайшли — закрити через 4 с
#  • у будь-якому разі не довше 15 с
state = {"away": 0, "seen": False, "t": 0}
def pointer():
    """Справжня позиція курсора від Hyprland: Xwayland не бачить курсор над Wayland-вікнами
    (QCursor.pos() «застигає», і меню думало, що курсор досі над ним)."""
    try:
        x, y = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True, timeout=1).stdout.split(",")
        return int(float(x)), int(float(y))
    except Exception:  # noqa: BLE001
        p = QCursor.pos(); return p.x(), p.y()
def watchdog():
    state["t"] += 1
    x, y = pointer()
    g = menu.geometry()
    inside = g.x() - 6 <= x <= g.x() + g.width() + 6 and g.y() - 6 <= y <= g.y() + g.height() + 6
    if inside:
        state["seen"] = True
        state["away"] = 0
    else:
        state["away"] += 1
    if (state["seen"] and state["away"] >= 6) or (not state["seen"] and state["away"] >= 16) or state["t"] >= 60:
        menu.close()
        app.quit()
timer = QTimer()
timer.timeout.connect(watchdog)
timer.start(250)                             # 4 рази на секунду: away 6 ≈ 1.5 с, 16 ≈ 4 с, t 60 = 15 с
menu.aboutToHide.connect(lambda: QTimer.singleShot(0, app.quit))

# позиція — від Hyprland: kitty тепер рідна Wayland-програма, і Xwayland (через який працює меню)
# не знає, де курсор (меню відкривалось би не там)
try:
    from PyQt6.QtCore import QPoint
except ImportError:
    from PyQt5.QtCore import QPoint
px, py = pointer()
run = getattr(menu, "exec", None) or menu.exec_
run(QPoint(px, py))
