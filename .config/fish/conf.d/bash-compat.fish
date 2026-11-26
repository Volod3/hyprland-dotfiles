# bash-compat.fish: звичні bash-команди у fish (кладеться в ~/.config/fish/conf.d/)
# Те, що fish уміє сам: VAR=x cmd, &&, ||, $(...), source, alias.

# export VAR=val  /  export VAR  /  export PATH=/a:/b  /  export (без аргументів = список)
function export --description "bash-подібний export"
    if test (count $argv) -eq 0
        set -x
        return
    end
    for arg in $argv
        if string match -q -- '-*' $arg
            continue
        end
        if string match -q -- '*=*' $arg
            set -l name (string split -m1 = -- $arg)[1]
            set -l val (string split -m1 = -- $arg)[2]
            if string match -q -r -- 'PATH$' $name
                set -gx $name (string split : -- $val)
            else
                set -gx $name $val
            end
        else
            set -gx $arg $$arg
        end
    end
end

# unset VAR [VAR...]
function unset --description "bash-подібний unset"
    for name in $argv
        set -e $name
    end
end

# !! та !$ (спрацьовують після пробілу/початку, як абревіатури)
function __bc_last_cmd
    echo $history[1]
end

function __bc_last_arg
    set -l parts (string split ' ' -- $history[1])
    echo $parts[-1]
end

if status is-interactive
    abbr -a '!!' --position anywhere --function __bc_last_cmd
    abbr -a '!$' --position anywhere --function __bc_last_arg
end
