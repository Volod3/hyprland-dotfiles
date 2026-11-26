function ffoff --description "зсув картинки в пікселях (0-20), далі перемалювати"
    sed -i "s/^OFFSET = .*/OFFSET = $argv[1]/" ~/.config/fastfetch/mkcfg.py
    cf
end
