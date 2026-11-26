import Quickshell
import Quickshell.Io
import QtQuick
import "modules"

Scope {
    id: root

    property var cfg: ({})

    // Якщо pet.json на мить став невалідним (ти його саме редагуєш) —
    // лишаємо попередній конфіг, а не скидаємо кішку до дефолтів.
    // У pet.json можна писати коментарі (// та /* */) і кому після останнього елемента.
    function applyCfg() {
        try {
            const txt = cfgFile.text()
            if (!txt || !txt.trim().length) return
            const c = JSON.parse(stripJsonc(txt))
            if (c === null || typeof c !== "object" || Array.isArray(c)) {
                console.warn("[desktop_pet] у pet.json має бути об'єкт { ... }, лишаю попередній конфіг")
                return
            }
            root.cfg = c
        } catch (e) {
            console.warn("[desktop_pet] Помилка читання pet.json, лишаю попередній конфіг: " + (e.message || e))
        }
    }

    // JSON з коментарями та зайвими комами -> звичайний JSON (вміст "рядків" не чіпається)
    function stripJsonc(s) {
        let a = ""
        for (let i = 0; i < s.length; i++) {
            const c = s[i]
            if (c === '"') {
                let j = i + 1
                while (j < s.length && s[j] !== '"') j += (s[j] === "\\") ? 2 : 1
                a += s.slice(i, j + 1)
                i = j
            } else if (c === "/" && s[i + 1] === "/") {
                while (i + 1 < s.length && s[i + 1] !== "\n") i++
            } else if (c === "/" && s[i + 1] === "*") {
                const e = s.indexOf("*/", i + 2)
                i = e < 0 ? s.length : e + 1
            } else {
                a += c
            }
        }
        let b = ""
        for (let i = 0; i < a.length; i++) {
            const c = a[i]
            if (c === '"') {
                let j = i + 1
                while (j < a.length && a[j] !== '"') j += (a[j] === "\\") ? 2 : 1
                b += a.slice(i, j + 1)
                i = j
            } else if (c === ",") {
                let j = i + 1
                while (j < a.length && /\s/.test(a[j])) j++
                if (a[j] !== "}" && a[j] !== "]") b += c
            } else {
                b += c
            }
        }
        return b
    }

    FileView {
        id: cfgFile
        path: Quickshell.shellPath("pet.json")
        blockLoading: true
        watchChanges: true
        onLoaded: root.applyCfg()
        onFileChanged: reload()
    }

    Component.onCompleted: applyCfg()

    PetWindow {
        id: petWin
        cfg: root.cfg
    }

    IpcHandler {
        target: "pet"

        function toggle(): void {
            if (petWin.isShattered || !petWin.visible) petWin.restoreFromShatter()
            else petWin.visible = false
        }

        function show(): void {
            if (petWin.isShattered || !petWin.visible) petWin.restoreFromShatter()
            else petWin.poke()
        }

        function hide(): void {
            petWin.visible = false
        }

        function poke(): void {
            petWin.poke()
        }

        function restart(): void {
            petWin.restartShell()
        }

        function say(text: string): void {
            petWin.say(text)
        }

        function timer(minutes: real): void {
            petWin.startTimer(minutes)
        }

        function stopwatch(): void {
            petWin.toggleStopwatch()
        }

        function stoptimer(): void {
            petWin.stopTimer()
        }

        // мозок: qs ... ipc call pet ask "як справи?"  /  ipc call pet chat
        function ask(text: string): void {
            petWin.doAction("ask:" + text)
        }

        function chat(): void {
            petWin.doAction("chat")
        }

        function action(name: string): void {
            petWin.doAction(name)
        }
    }
}
