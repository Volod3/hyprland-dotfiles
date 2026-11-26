#!/bin/sh
choice=$(kdialog --title "kitty" --menu "Дія" \
  copy "Копіювати" \
  paste "Вставити" \
  clear "Очистити термінал" \
  reload "Перечитати конфіг kitty")
[ -z "$choice" ] && exit 0
case "$choice" in
  copy)   kitten @ action copy_to_clipboard ;;
  paste)  kitten @ action paste_from_clipboard ;;
  clear)  kitten @ action clear_terminal to_cursor_scroll active ;;
  reload) kitten @ action load_config_file ;;
esac
