------------------
---- MONITORS ----
------------------


hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1.0",
})


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "dolphin"
local menu = "wofi"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function ()
  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_welcome/shell.qml")      -- заставка входу (сама закривається)
  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_osd/shell.qml")          -- спливаючі віконця (гучність, зарядка, флешки…)
  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_themes/shell.qml")       -- меню тем (Pause / Break)
  --hl.exec_cmd("hyprpaper")
  hl.exec_cmd("sh -c 'dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE && systemctl --user restart hermes-gateway'")

  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_parallax_MDRG/shell.qml")
  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_sidepanel/shell.qml")
  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_pet/shell.qml")
  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_popups/shell.qml")   -- вікна мережі / Bluetooth / системи з waybar
  hl.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/clipd watch")                -- історія буфера обміну
  hl.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_clipboard/shell.qml")      -- вікно буфера обміну (Win+V)
  hl.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/remote-desktop")             -- керування з телефона (VNC лише через Tailscale)
  hl.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/powerd watch")               -- економія, відеокарта для програм, ліміт заряду
  -- автоматичний ігровий режим: у грі ховає пета, вивантажує модель, вимикає паралакс і блюр
  hl.exec_cmd("sh -c 'rm -f ~/.cache/gamemode.json; exec ~/.config/wallpapers_QS/tools/gamemode watch'")
  -- сон / вимкнення екрана (hypridle) і нічний режим — з налаштувань (Win+I → Живлення, Екран)
  hl.exec_cmd("/home/voltimeter/.config/quickshell-settings/bin/usettings startup")
  -- hl.exec_cmd("nm-applet")   -- замінено власними вікнами мережі/Bluetooth у waybar
  hl.exec_cmd("systemctl --user start swaync")   -- лише через systemd (інакше два екземпляри змагаються і служба падає)
  hl.exec_cmd("waybar")
  hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
  -- hl.exec_cmd("~/.config/hypr/razer-mic.sh")  -- скрипта немає на цьому ПК
  hl.exec_cmd("/usr/lib/pam_kwallet_init")   -- розблоковує KWallet паролем входу (ключ від SDDM/PAM); не запускати kwalletd6 напряму
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

--hl.env("XCURSOR_SIZE", "20")
--hl.env("HYPRCURSOR_SIZE", "20")
hl.env("QT_QPA_PLATFORMTHEME", "kde")

-- Курсор Zhao-cursor не встановлений — розкоментуй, коли поставиш
-- hl.env("XCURSOR_THEME", "Zhao-cursor")
-- hl.env("HYPRCURSOR_THEME", "Zhao-cursor")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            --active_border = { colors = {"rgba(2f02e0ff)", "rgba(9f06d6ff)"}, angle =90 },
            --active_border = { colors = {"rgba(0099e6ff)", "rgba(9f06d6ff)", "rgba(ff4fd8ff)", "rgba(0099e6ff)"}, angle = 90},
            --active_border = { colors = {"rgba(ff0000ff)", "rgba(ffff00ff)", "rgba(00ff00ff)", "rgba(00ffffff)", "rgba(0000ffff)", "rgba(ff00ffff)", "rgba(ff0000ff)"}, angle = 45 }, -- rainbow
            --active_border = { colors = {"rgba(00f0ffff)", "rgba(ff2bd6ff)", "rgba(7b2dffff)", "rgba(00f0ffff)"}, angle = 45 }, -- neon
            --active_border = { colors = {"rgba(ff5f6dff)", "rgba(ffc371ff)", "rgba(c83cffff)", "rgba(ff5f6dff)"}, angle = 45 }, -- sunrise
            --active_border = { colors = {"rgba(00f0ffff)", "rgba(ff2bd6ff)", "rgba(0d0221ff)", "rgba(0d0221ff)", "rgba(0d0221ff)", "rgba(00f0ffff)"}, angle = 0 }, -- comet
            active_border = { colors = {"rgba(003991ff)", "rgba(3C00BAff)", "rgba(0d0221ff)", "rgba(0d0221ff)", "rgba(0d0221ff)", "rgba(003991ff)"}, angle = 0 }, -- comet neon blue
            inactive_border = "rgba(a10276ff)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 14,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        -- розмиття під напівпрозорими панелями (waybar, бокова панель, вікна, сповіщення);
        -- звичайні вікна непрозорі (opacity 1.0), тож на них не впливає
        blur = {
            enabled   = true,
            size      = 8,
            passes    = 3,
            vibrancy  = 0.18,
            noise     = 0.012,
            popups    = true,
        },

        --blur = {
        --    enabled        = true,
        --    size           = 8,
        --    passes         = 1,
        --    ignore_opacity = true,   -- блюр не слабшає, коли вікно прозоре
        --    noise          = 0.02,
        --    brightness     = 0.9,
        --    contrast       = 1.2,
        --    vibrancy       = 0.5,
        --    vibrancy_darkness = 0.3,
        --},
    },

    animations = {
        enabled = true,
    },
})




--------------------------------- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0.0, 0.0},   {1.0, 1.0}   } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- jelly
hl.curve("jelly", {type = "spring",mass = 1,stiffness = 170,  dampening = 9,  })
hl.curve("jellySoft", { type = "spring", mass = 1, stiffness = 120, dampening = 14 })
hl.curve("jellyMove", { type = "spring", mass = 1, stiffness = 150, dampening = 8 })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 2.0,  bezier = "easeInOutCubic", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })




---------------- workspase
-- hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
-- hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
-- hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })


-- hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })
-- hl.animation({ leaf = "workspaces", enabled = true, speed = 5, spring = "jellyMove", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade 20%" })




---------------- windows
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 2.2,  bezier = "easeInOutCubic", style = "popin 90%" })   -- плавніше, ніж лінійно

--hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6, spring = "jelly",     style = "popin 60%" })
--hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5, spring = "jellySoft", style = "popin 70%" })
--hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, spring = "jelly" })
--hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, spring = "jellyMove" })

hl.animation({ leaf = "borderangle", enabled = true, speed = 50, bezier = "linear", style = "loop" })





-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        disable_splash_rendering = true,
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
        animate_mouse_windowdragging = true,  -- анімація при перетягуванні
        animate_manual_resizes = true,
        allow_session_lock_restore = true,   -- якщо екран блокування впаде — Win+L/сон запустить його знову
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us, ua",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse = 1,

        numlock_by_default = true,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- комбінації на Win; сама клавіша Win (натиснути й відпустити) — бокова панель

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
-- closeWindowBind:set_enabled(false)

--------------------------------
------------ KEYBIND -----------
--------------------------------

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())

hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("pavucontrol"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("google-chrome-stable"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("Telegram"))
-- hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("flatpak run com.ktechpit.whatsie"))  -- Whatsie не встановлений
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("dolphin"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("wofi --show drun"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("kate"))                -- текстовий редактор
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("code"))       -- Visual Studio Code
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/lock"))   -- заблокувати екран
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("/home/voltimeter/.config/theme-switch/bin/hypr-settings"))   -- налаштування Hyprland

hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup toggle power"))   -- меню живлення (раніше одразу виходило з сесії)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_clipboard/shell.qml ipc call clipboard toggle"))   -- буфер обміну, як Meta+V у KDE
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))   -- плаваюче вікно (раніше було на Win+V)
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + ALT + P", hl.dsp.window.pseudo())   -- «псевдоплитка» (вікно свого розміру по центру); було Win+P — легко натиснути випадково
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "0"}))
hl.bind("F11", hl.dsp.window.fullscreen({ mode = "0" }))                 -- на весь екран / назад (будь-яке вікно, і в ігровому режимі)
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "1" }))   -- розгорнути (з панеллю) / назад

-- Натиснути й відпустити Win (без інших клавіш) — бокова панель
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_sidepanel/shell.qml ipc call sidepanel toggle"), { release = true })
-- Copilot-клавіша ноутбука (шле Win+Shift+F23)
hl.bind("SUPER + SHIFT + F23", hl.dsp.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_sidepanel/shell.qml ipc call sidepanel toggle"))


hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region --freeze -o /home/voltimeter/Картинки/\"Знімки вікон\" && ~/.config/wallpapers_QS/tools/sfx screenshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m region --freeze -o /home/voltimeter/Картинки/\"Знімки вікон\" && ~/.config/wallpapers_QS/tools/sfx screenshot"))   -- виділити зону мишкою (Esc — скасувати)
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output -m active -o /home/voltimeter/Картинки/\"Знімки вікон\" && ~/.config/wallpapers_QS/tools/sfx screenshot"))   -- одразу весь активний екран, без «заморожування» й кліку


-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + A",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 80, y = 0, relative = true}))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -80, y = 0, relative = true}))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -80, relative = true}))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 80, relative = true}))


-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl volume up"),   { locked = true, repeating = true })   -- + спливаюче віконце (bg_osd)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl volume down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl volume mute"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl mic mute"),    { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl brightness down"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",  hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl kbd up"),   { locked = true, repeating = true })   -- підсвітка клавіатури
hl.bind("XF86KbdBrightnessDown",hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl kbd down"), { locked = true, repeating = true })
hl.bind("XF86KbdLightOnOff",    hl.dsp.exec_cmd("/home/voltimeter/.config/wallpapers_QS/tools/osdctl kbd cycle"), { locked = true })

-- Кришка ноутбука: дію вибирають у налаштуваннях (Win+I → Живлення). logind кришку ігнорує.
local usettings = "/home/voltimeter/.config/quickshell-settings/bin/usettings"
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(usettings .. " lid close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(usettings .. " lid open"),  { locked = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("Pause", hl.dsp.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_themes/shell.qml ipc call themes toggle"))   -- меню тем
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Кнопка живлення (було в hyprland.conf)
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("qs -p /home/voltimeter/.config/wallpapers_QS/bg_popups/shell.qml ipc call popup toggle power"))   -- меню живлення (замість wlogout)



--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
suppressMaximizeRule:set_enabled(false)   -- вимкнено: програми можуть розгортати вікна (кнопка □, подвійний клік по заголовку)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})


--hl.window_rule({
--    name  = "glass-windows",
--    match = { class = "^(org\\.kde\\.dolphin|org\\.gnome\\.Settings|pavucontrol|org\\.pulseaudio\\.pavucontrol|discord)$" },
--    opacity = "1.0 0.7",
--})


-- hl.window_rule({
--     name  = "make-all-windows-float",
--     match = { class = ".*" },
--     float = true,
-- })


-------------------------------------------------
---- БЛЮР ПІД ПАНЕЛЯМИ (скло) ----
-------------------------------------------------
-- waybar, бокова панель, пошук програм, вікна мережі/Bluetooth/системи/звуку, налаштування, сповіщення
for _, ns in ipairs({ "waybar", "sidepanel", "sidepanel-apps", "popups", "clipboard", "kittymenu", "osd", "themes", "hypr-settings", "swaync-control-center", "swaync-notification-window" }) do
    hl.layer_rule({ name = "blur-" .. ns, match = { namespace = "^" .. ns .. "$" }, blur = true, ignore_alpha = 0.2 })
end

-------------------------------------------------
---- НАЛАШТУВАННЯ З ЗАСТОСУНКУ (Win+I) ----
-------------------------------------------------
-- user-settings.lua пише застосунок налаштувань; помилка в ньому не ламає весь конфіг
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/gpu-env.lua")   -- відеокарта для програм (генерує tools/powerd)
local okUS, errUS = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/user-settings.lua")
if not okUS then print("user-settings.lua: " .. tostring(errUS)) end

-- рамки вікон у кольорах теми (генерує tools/theme)
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/theme.lua")
