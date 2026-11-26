#!/usr/bin/env python3
"""Перефарбовує kitty.conf та кольори рамок у hyprland.lua під обрану тему."""
import re
import sys


def apply_kitty(conf_path, colors_path):
    keep = {}
    order = []
    with open(colors_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, val = line.partition(" ")
            keep[key] = val.strip()
            order.append(key)

    with open(conf_path, encoding="utf-8") as f:
        lines = f.readlines()

    seen = set()
    out = []
    for line in lines:
        m = re.match(r"^(\s*)([A-Za-z_][\w_]*)\s+(\S+)\s*$", line.rstrip("\n"))
        if m and m.group(2) in keep:
            key = m.group(2)
            out.append(f"{key:<22} {keep[key]}\n")
            seen.add(key)
        else:
            out.append(line)

    missing = [k for k in order if k not in seen]
    if missing:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        out.append("\n# --- кольори теми (додано theme-switch) ---\n")
        for k in missing:
            out.append(f"{k:<22} {keep[k]}\n")

    with open(conf_path, "w", encoding="utf-8") as f:
        f.writelines(out)
    print(f"kitty: {len(seen)} keys updated, {len(missing)} added")


def apply_hypr(lua_path, a1, a2, angle, inactive):
    with open(lua_path, encoding="utf-8") as f:
        lines = f.readlines()

    n = 0
    for i, line in enumerate(lines):
        code = line.split("--")[0]
        stripped = code.strip()
        if stripped.startswith("active_border") and "=" in stripped:
            indent = re.match(r"^(\s*)", line).group(1)
            lines[i] = (
                f'{indent}active_border   = {{ colors = {{"{a1}", "{a2}"}}, angle = {angle} }},\n'
            )
            n += 1
        elif stripped.startswith("inactive_border") and "=" in stripped:
            indent = re.match(r"^(\s*)", line).group(1)
            lines[i] = f'{indent}inactive_border = "{inactive}",\n'
            n += 1

    with open(lua_path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    print(f"hypr: {n} border lines updated")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "kitty":
        apply_kitty(sys.argv[2], sys.argv[3])
    elif cmd == "hypr":
        apply_hypr(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
    else:
        sys.exit(f"unknown command {cmd}")
