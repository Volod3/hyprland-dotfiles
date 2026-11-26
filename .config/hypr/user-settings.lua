-- Згенеровано застосунком «Налаштування» (Win+I). Вручну не редагуй — перезапишеться.
-- Підключається в кінці hyprland.lua, тож перекриває значення звідти.

hl.config({ input = { repeat_rate = 25 } })
hl.config({ misc = { mouse_move_enables_dpms = false } })
hl.config({ misc = { key_press_enables_dpms = true } })
hl.config({ misc = { vrr = 0 } })
hl.config({ decoration = { dim_inactive = false } })
hl.config({ cursor = { inactive_timeout = 0.0 } })
hl.config({ input = { accel_profile = "flat" } })
hl.config({ input = { sensitivity = 0.45 } })
hl.config({ input = { numlock_by_default = true } })
hl.config({ general = { resize_on_border = true } })
hl.env("XCURSOR_THEME", "Minimal")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Minimal")
hl.env("HYPRCURSOR_SIZE", "24")
