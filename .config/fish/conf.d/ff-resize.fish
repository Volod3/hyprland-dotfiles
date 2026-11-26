function __ff_unfresh --on-event fish_preexec
    set -e __ff_fresh
end

function __ff_autoresize --on-signal WINCH
    set -q __ff_fresh; or return
    set -q __ff_busy; and return
    string length -q -- (commandline); and return
    set -g __ff_busy 1
    set -l last ""
    while test "$last" != (stty size </dev/tty)
        set last (stty size </dev/tty)
        sleep 0.35
    end
    cf
    commandline -f repaint
    set -e __ff_busy
end
