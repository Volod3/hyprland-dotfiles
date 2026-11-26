#!/bin/bash
# Старе меню на wofi замінено вікном у стилі робочого столу (bg_popups → power).
exec qs -p /home/voltimeter/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup toggle power
