from kittens.tui.handler import result_handler


def main(args):
    pass


def get_text():
    try:
        from kitty.fast_data_types import get_clipboard_string
        return get_clipboard_string()
    except Exception:
        pass
    try:
        from kitty.clipboard import get_clipboard_string
        return get_clipboard_string()
    except Exception:
        return None


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    text = get_text()
    if not text:
        fallback = getattr(boss, "paste_from_clipboard", None)
        if fallback:
            fallback()
        return
    if isinstance(text, bytes):
        text = text.decode("utf-8", "replace")
    try:
        if not w.screen.is_using_alternate_linebuf():
            cols = max(int(w.screen.columns), 1)
            rows = max(int(w.screen.lines), 1)
            need = 4  # запас на приглашення
            for line in text.replace("\r\n", "\n").split("\n"):
                need += max(1, -(-len(line.expandtabs(4)) // cols))
            if need > rows:
                from kitty.fast_data_types import get_options, os_window_font_size
                cur = float(os_window_font_size(w.os_window_id))
                base = float(get_options().font_size)
                new = cur * rows / need
                new = max(new, base * 0.6, 8.0)
                if new < cur - 0.2:
                    pass
    except Exception:
        pass
    paste = getattr(w, "paste_with_actions", None) or w.paste_text
    paste(text)
