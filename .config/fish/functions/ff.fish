function ff --description "fastfetch під розмір вікна"
    set -l sz (stty size </dev/tty 2>/dev/null | string split " ")
    test (count $sz) -eq 2; or set sz $LINES $COLUMNS
    set -l tmp /tmp/ff-$fish_pid.jsonc
    python3 ~/.config/fastfetch/mkcfg.py $sz[2] $sz[1] > $tmp
    and command fastfetch -c $tmp $argv
    rm -f $tmp
    set -g __ff_fresh 1
end
