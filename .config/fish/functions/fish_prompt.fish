function fish_prompt
    set -l last_duration $CMD_DURATION
    set -l realhome ~
    set -l pwd_styled (string replace "$realhome" "~" $PWD)
    set_color 89b4fa
    echo -n ""
    set_color -o -b 89b4fa 111625
    echo -n " 󰉋 $pwd_styled "
    set_color normal
    set_color -b normal 89b4fa
    echo -n " "
    if test -n "$last_duration"; and test $last_duration -gt 100
        set -l secs (math --scale=2 "$last_duration / 1000")
        set_color 45475a
        echo -n ""
        set_color -b 45475a cdd6f4
        echo -n " 󱦟 "$secs"s "
        set_color -b normal 45475a
        echo -n ""
    end
    echo ""
    set_color 89dceb
    echo -n "❯ "
    set_color normal
end
