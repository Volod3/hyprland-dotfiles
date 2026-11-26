#!/usr/bin/env bash
# Хвилька cava для waybar — замість вбудованого модуля "cava"
# (waybar з Arch зібраний без нього: "Unknown module: cava").
# Виклик з waybar:  ~/.config/waybar/cava.sh [смуг] [кадрів/с]
# Потрібна сама cava:  sudo pacman -S cava

bars_count="${1:-12}"
framerate="${2:-30}"
glyphs=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)   # окремими елементами — не залежить від локалі (UTF-8 чи ні)

command -v cava >/dev/null 2>&1 || { echo "cava не встановлена"; exit 1; }

# в ігровому режимі хвилька не потрібна — не крадемо процесор у гри (waybar перезапустить скрипт пізніше)
if grep -qs '"active": true' "$HOME/.cache/gamemode.json" "$HOME/.cache/eco.json"; then echo ""; sleep 20; exit 0; fi

# Свій конфіг (у пам'яті, а не в ~/.config/cava/config, щоб не заважати звичайній cava в терміналі)
conf="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava.conf"
cat > "$conf" <<EOF
[general]
bars = $bars_count
framerate = $framerate
[input]
method = pipewire
source = auto
[smoothing]
noise_reduction = 77
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
frame_delimiter = 10
EOF

# cava віддає рядки на кшталт "0;3;7;2;" — перетворюємо цифри 0..7 на ▁..█
dict="s/;//g"
for i in 0 1 2 3 4 5 6 7; do
    dict="$dict;s/$i/${glyphs[$i]}/g"
done

# exec: скрипт сам стає процесом cava, тож коли waybar його зупиняє — cava не лишається висіти у фоні
exec cava -p "$conf" > >(exec sed -u "$dict")
