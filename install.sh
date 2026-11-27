#!/usr/bin/env bash
# Встановлення dotfiles (Arch Linux + Hyprland з Lua-конфігом + Quickshell).
#   ./install.sh            — пакети + конфіги (старі конфіги зберігаються в ~/.config-backup-<дата>)
#   ./install.sh --no-pkgs  — лише конфіги, без pacman
#   ./install.sh --extras   — ще й тема SDDM, заставка завантаження Plymouth (потрібен sudo)
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
OLD_HOME="/home/voltimeter"            # шлях, під який написані конфіги — замінюється на твій $HOME
PKGS=1; EXTRAS=0
for a in "$@"; do
    case "$a" in
        --no-pkgs) PKGS=0 ;;
        --extras)  EXTRAS=1 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    esac
done

say() { printf '\e[1;36m==>\e[0m %s\n' "$*"; }

# ---------- 1. пакети ----------
if [ "$PKGS" = 1 ]; then
    command -v pacman >/dev/null || { echo "Це не Arch — встанови пакети з README вручну і запусти з --no-pkgs"; exit 1; }
    say "Встановлюю пакети (pacman)"
    sudo pacman -S --needed \
        hyprland quickshell waybar kitty fish fastfetch swaync wofi wlogout cava btop \
        hyprshot hypridle hyprpaper hyprpicker hyprpolkitagent xdg-desktop-portal-hyprland \
        wl-clipboard grim slurp jq socat libnotify brightnessctl playerctl udisks2 \
        pipewire wireplumber pavucontrol networkmanager bluez bluez-utils tmux \
        python python-pillow python-numpy ffmpeg ddcutil \
        qt6-5compat qt6-multimedia qt6-svg \
        ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts-emoji \
        dolphin celluloid elisa nwg-look
fi

# ---------- 2. конфіги ----------
TS=$(date +%Y%m%d-%H%M%S)
BK="$HOME/.config-backup-$TS"
say "Копіюю конфіги (старі — у $BK)"
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/icons"
for d in "$REPO"/.config/*; do
    n=$(basename "$d")
    if [ -e "$HOME/.config/$n" ]; then
        mkdir -p "$BK"; mv "$HOME/.config/$n" "$BK/"
    fi
    cp -a "$d" "$HOME/.config/"
done
cp -a "$REPO"/.local/bin/. "$HOME/.local/bin/"
cp -a "$REPO"/.local/share/icons/. "$HOME/.local/share/icons/"

# ---------- 3. шляхи й ім'я під тебе ----------
if [ "$HOME" != "$OLD_HOME" ]; then
    say "Міняю $OLD_HOME → $HOME у конфігах"
    grep -rIl "$OLD_HOME" "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/wallpapers_QS" \
        "$HOME/.config/quickshell-settings" "$HOME/.config/quickshell-launcher" "$HOME/.config/quickshell-cc" \
        "$HOME/.config/theme-switch" "$HOME/.config/swaync" 2>/dev/null | xargs -r sed -i "s|$OLD_HOME|$HOME|g"
fi
sed -i "s|\"name\": \"voltimeter\"|\"name\": \"$USER\"|" "$HOME/.config/wallpapers_QS/bg_sidepanel/sidepanel.json" || true

# скріншоти (Print / Shift+Print / Win+Shift+S)
PIC=$(xdg-user-dir PICTURES 2>/dev/null || true)
[ -n "$PIC" ] && [ "$PIC" != "$HOME" ] || PIC="$HOME/Pictures"
if [ "$PIC" != "$HOME/Картинки" ]; then
    sed -i "s|$HOME/Картинки/\\\\\"Знімки вікон\\\\\"|$PIC/Screenshots|g" "$HOME/.config/hypr/hyprland.lua"
    mkdir -p "$PIC/Screenshots"
else
    mkdir -p "$HOME/Картинки/Знімки вікон"
fi

chmod +x "$HOME"/.config/wallpapers_QS/tools/* "$HOME"/.config/wallpapers_QS/bg_popups/popctl \
         "$HOME"/.config/theme-switch/bin/* "$HOME"/.config/quickshell-settings/bin/* \
         "$HOME"/.config/waybar/*.sh "$HOME"/.local/bin/* 2>/dev/null || true

# тема за замовчуванням (перегенерує settings.json шпалер, кольори waybar / kitty / рамок)
"$HOME/.config/wallpapers_QS/tools/theme" set mountains >/dev/null 2>&1 || true

# ---------- 4. fish як оболонка ----------
if [ "$(basename "${SHELL:-}")" != fish ] && command -v fish >/dev/null; then
    say "Роблю fish оболонкою за замовчуванням"
    chsh -s "$(command -v fish)" || true
fi

# ---------- 5. додатково: SDDM + Plymouth ----------
if [ "$EXTRAS" = 1 ]; then
    say "Тема входу SDDM «glass»"
    sudo cp -r "$HOME/.config/wallpapers_QS/sddm-theme/glass" /usr/share/sddm/themes/
    printf '[Theme]\nCurrent=glass\n' | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
    if command -v plymouth-set-default-theme >/dev/null; then
        say "Заставка завантаження Plymouth «archglass»"
        sudo cp -r "$HOME/.config/wallpapers_QS/boot-splash/archglass" /usr/share/plymouth/themes/
        sudo plymouth-set-default-theme archglass
        echo "   Щоб заставка з'явилась: додай 'plymouth' у HOOKS (/etc/mkinitcpio.conf), 'splash quiet' у cmdline і виконай: sudo mkinitcpio -P"
    fi
fi

say "Готово! Вийди з сесії й обери Hyprland (або: Hyprland у TTY)."
echo "   Win+Q — термінал, Win+Space — програми, Pause — меню тем, Win+I — налаштування."
