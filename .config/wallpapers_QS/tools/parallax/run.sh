#!/usr/bin/env bash
# Паралакс з будь-якої картинки:  ~/.config/wallpapers_QS/tools/parallax/run.sh ~/Картинки/фото.jpg
# Шари → bg_parallax_MDRG/assets/parallax_backgrounds/<ім'я>/, там же layers.json для settings.json
set -e
img="$1"; [ -f "$img" ] || { echo "Вкажи картинку: $0 фото.jpg"; exit 1; }
name=$(basename "${img%.*}")
exec ~/.local/share/parallax-venv/bin/python -I ~/.config/wallpapers_QS/tools/parallax/parallax.py "$img" \
  --screen 1920x1080 -n 5 -s 20 --anim -o ~/.config/wallpapers_QS/bg_parallax_MDRG/assets/parallax_backgrounds/"$name" "${@:2}"
