#!/usr/bin/env bash
# Значки мережі й Bluetooth для waybar (JSON: text / tooltip / class).
#   netbt.sh net   — Ethernet / Wi-Fi / немає з'єднання
#   netbt.sh bt    — вимкнено / увімкнено / підключено (з назвою пристрою)
# Клік по значку відкриває вікно: qs -p ~/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup toggle net|bt

json() { printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$3"; }

case "$1" in
  net)
    line=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null | grep -E '^(ethernet|wifi):connected' | head -n1)
    type=${line%%:*}
    name=${line#*:connected:}
    if [ "$type" = ethernet ]; then
      json "󰈀" "Дротове: $name" "ethernet"
    elif [ "$type" = wifi ]; then
      sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')
      ic="󰤨"; [ "${sig:-0}" -lt 75 ] && ic="󰤥"; [ "${sig:-0}" -lt 50 ] && ic="󰤢"; [ "${sig:-0}" -lt 25 ] && ic="󰤟"
      json "$ic" "Wi-Fi: $name (${sig}%)" "wifi"
    else
      json "󰤮" "Немає з'єднання" "disconnected"
    fi
    ;;
  bt)
    if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
      json "󰂲" "Bluetooth вимкнено" "off"
    else
      dev=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)
      if [ -n "$dev" ]; then
        json "󰂱" "Підключено: $dev" "connected"
      else
        json "󰂯" "Bluetooth увімкнено" "on"
      fi
    fi
    ;;
esac
