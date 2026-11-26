/* Меню вибору теми — скляна панель у кольорі активної теми.
   @ACCENT@ / @ACCENT_RGB@ / @BG@ підставляє theme-switch при перемиканні. */

window {
    margin: 0;
    padding: 0;
    border: 1px solid @ACCENT@;
    border-radius: 20px;
    background-color: @BG@;
    background-image: linear-gradient(
        160deg,
        rgba(@ACCENT_RGB@, 0.16) 0%,
        rgba(@ACCENT_RGB@, 0.04) 42%,
        rgba(0, 0, 0, 0) 100%
    );
    box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.06) inset;
    font-family: JetBrainsMonoNerdFont, Roboto, sans-serif;
}

#outer-box {
    margin: 12px;
    background: transparent;
}

#input {
    margin: 0 0 10px 0;
    padding: 10px 14px;
    min-height: 22px;
    border: none;
    border-radius: 14px;
    color: #eef6ff;
    background-color: rgba(@ACCENT_RGB@, 0.12);
    caret-color: @ACCENT@;
    font-size: 15px;
}

#inner-box {
    margin: 0;
    background: transparent;
}

#scroll {
    margin: 0;
    background: transparent;
}

#entry {
    padding: 12px 16px;
    margin: 3px 0;
    border-radius: 14px;
    background-color: rgba(255, 255, 255, 0.03);
}

#img {
    min-width: 28px;
    min-height: 28px;
    margin-right: 12px;
    border-radius: 8px;
}

#entry:hover {
    background-color: rgba(@ACCENT_RGB@, 0.12);
}

#entry:selected {
    background-color: rgba(@ACCENT_RGB@, 0.24);
    border-left: 3px solid @ACCENT@;
}

#text {
    color: #d8e6f8;
    font-size: 15px;
    font-weight: 500;
}

#entry:selected #text {
    color: #ffffff;
    font-weight: 700;
}

#text:selected {
    color: #ffffff;
}
