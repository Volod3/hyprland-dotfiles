# fastfetch без аргументів = ff (картинка і розмір під вікно, як при старті терміналу)
function fastfetch --description "fastfetch під розмір вікна"
    if test (count $argv) -eq 0
        ff
        # ручний запуск не вважається "свіжим" екраном, тому зміна розміру вікна його не перемальовує
        set -e __ff_fresh
    else
        command fastfetch $argv
    end
end

# Ctrl+L (і пункт "Очистити термінал" в меню) більше не повертає fastfetch при зміні розміру вікна
if status is-interactive
    bind \cl 'set -e __ff_fresh; commandline -f clear-screen'
end
