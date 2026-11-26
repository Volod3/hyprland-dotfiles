#!/usr/bin/env bash

pgrep -x wofi >/dev/null && { pkill -x wofi; exit 0; }

WALLPAPER_SHELL="$HOME/.config/wallpapers_QS/bg_parallax_MDRG/shell.qml"
WALLPAPER_PATTERN="qs.*${WALLPAPER_SHELL}"

PANEL_SHELL="$HOME/.config/wallpapers_QS/bg_sidepanel/shell.qml"
PANEL_PATTERN="qs.*${PANEL_SHELL}"

current=$(powerprofilesctl get)
mark() { [ "$current" = "$1" ] && echo "● " || echo "   "; }

if pgrep -f "$WALLPAPER_PATTERN" > /dev/null; then
  wp_status="●  Вбити шпалери (QS)"
else
  wp_status="   Запустити шпалери (QS)"
fi

if pgrep -f "$PANEL_PATTERN" > /dev/null; then
  panel_status="●  Вбити панель (QS)"
else
  panel_status="   Запустити панель (QS)"
fi

choice=$(printf '%s\n' \
  "$(mark performance)󰓅  Продуктивність" \
  "$(mark balanced)󰾅  Збалансований" \
  "$(mark power-saver)󰌪  Енергозбереження" \
  "$wp_status" \
  "$panel_status" \
  | wofi --dmenu --prompt "Режим живлення" \
         --width 320 --height 270 \
         --hide-search --cache-file /dev/null)

case "$choice" in
  *Продуктивність*)    profile=performance; brightness=100; do_power=true ;;
  *Збалансований*)     profile=balanced;    brightness="50";  do_power=true ;;
  *Енергозбереження*)  profile=power-saver; brightness=10;  do_power=true ;;
  *шпалери*)
    if pgrep -f "$WALLPAPER_PATTERN" > /dev/null; then
      pkill -f "$WALLPAPER_PATTERN"
      notify-send -i dialog-information "Шпалери (QS)" "Шпалери зупинено"
    else
      setsid -f qs -p "$WALLPAPER_SHELL" >/dev/null 2>&1
      notify-send -i dialog-information "Шпалери (QS)" "Шпалери запущено"
    fi
    exit 0
    ;;
  *панель*)
    if pgrep -f "$PANEL_PATTERN" > /dev/null; then
      pkill -f "$PANEL_PATTERN"
      notify-send -i dialog-information "Панель (QS)" "Панель зупинено"
    else
      setsid -f qs -p "$PANEL_SHELL" >/dev/null 2>&1
      notify-send -i dialog-information "Панель (QS)" "Панель запущено"
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac

if [ "$do_power" = true ]; then
  if powerprofilesctl set "$profile"; then
    [ -n "$brightness" ] && brightnessctl set "${brightness}%" >/dev/null
    notify-send -i battery "Режим живлення" "Профіль: $profile${brightness:+, яскравість $brightness%}"
  else
    notify-send -u critical "Режим живлення" "Не вдалося встановити профіль $profile"
  fi
fi
