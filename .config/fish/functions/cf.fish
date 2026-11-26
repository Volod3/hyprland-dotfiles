function cf --description "перемалювати fastfetch"
    printf "\e[?2026h\e[H\e[2J\e[3J"
    ff
    printf "\e[?2026l"
end
