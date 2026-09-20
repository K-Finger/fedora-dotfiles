#!/usr/bin/env bash
# Searchable cheat sheet of Hyprland keybinds, parsed from hyprland.lua.

python3 - "${HYPRLAND_LUA:-$HOME/.config/hypr/hyprland.lua}" <<'EOF' | fuzzel --dmenu -p "keys> " -w 70 -l 20 >/dev/null
import re, sys

src = open(sys.argv[1]).read()

# Friendly descriptions, first match wins.
DESC = [
    (r'exec_cmd\(terminal\)', 'Open terminal'),
    (r'exec_cmd\(fileManager\)', 'Open file manager'),
    (r'exec_cmd\(menu\)', 'App launcher'),
    (r'power-menu', 'Power menu'),
    (r'keybinds\.sh', 'Show this keybind list'),
    (r'hyprlock', 'Lock screen'),
    (r'hyprshutdown|dsp\.exit', 'Log out of Hyprland'),
    (r'grim -g', 'Screenshot region to clipboard'),
    (r'window\.close', 'Close window'),
    (r'window\.float', 'Toggle floating'),
    (r'window\.pseudo', 'Toggle pseudo-tile'),
    (r'layout\("togglesplit"\)', 'Toggle split direction'),
    (r'toggle_special', 'Toggle scratchpad'),
    (r'move\(\{ workspace = "special:magic"', 'Move window to scratchpad'),
    (r'window\.drag', 'Drag window with mouse'),
    (r'window\.resize', 'Resize window with mouse'),
    (r'focus\(\{ direction = "(\w+)"', lambda m: f'Focus window {m.group(1)}'),
    (r'focus\(\{ workspace = "e\+1"', 'Next workspace'),
    (r'focus\(\{ workspace = "e-1"', 'Previous workspace'),
    (r'AUDIO_SINK@ \d+%\+', 'Volume up'),
    (r'AUDIO_SINK@ \d+%-', 'Volume down'),
    (r'AUDIO_SINK@ toggle', 'Mute'),
    (r'AUDIO_SOURCE@ toggle', 'Mute microphone'),
    (r'brightnessctl.*\+', 'Brightness up'),
    (r'brightnessctl.*-', 'Brightness down'),
    (r'playerctl next', 'Next track'),
    (r'playerctl previous', 'Previous track'),
    (r'playerctl play-pause', 'Play / pause'),
]

def balanced(text, start):
    """Return the text inside the parens that open at text[start]."""
    depth, i, in_str = 0, start, None
    while i < len(text):
        c = text[i]
        if in_str:
            if c == '\\':
                i += 1
            elif c == in_str:
                in_str = None
        elif c in '"\'':
            in_str = c
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return text[start + 1:i]
        i += 1
    return None

def split_args(body):
    args, depth, cur, in_str = [], 0, '', None
    for i, c in enumerate(body):
        if in_str:
            cur += c
            if c == in_str and body[i - 1] != '\\':
                in_str = None
            continue
        if c in '"\'':
            in_str = c
        elif c in '({[':
            depth += 1
        elif c in ')}]':
            depth -= 1
        elif c == ',' and depth == 0:
            args.append(cur.strip()); cur = ''; continue
        cur += c
    args.append(cur.strip())
    return args

def key_of(expr):
    # Only literal strings joined with mainMod; skip anything computed (loop vars).
    parts = [p.strip() for p in expr.split('..')]
    out = []
    for p in parts:
        if p == 'mainMod':
            out.append('SUPER')
        elif len(p) >= 2 and p[0] == p[-1] and p[0] in '"\'':
            out.append(p[1:-1])
        else:
            return None
    k = ''.join(out)
    return ' + '.join(w if w.startswith('XF86') else w.capitalize() if w.isupper() and len(w) > 1 else w
                      for w in [x.strip() for x in k.split('+')]).replace('Super', 'Super')

def describe(action):
    flat = ' '.join(action.split())
    for pat, d in DESC:
        m = re.search(pat, flat)
        if m:
            return d(m) if callable(d) else d
    m = re.search(r'exec_cmd\((.*)\)', flat)
    return ('Run: ' + m.group(1).strip('"\'')) if m else flat[:60]

rows = []
for m in re.finditer(r'hl\.bind\(', src):
    # Skip commented-out lines.
    line_start = src.rfind('\n', 0, m.start()) + 1
    if src[line_start:m.start()].lstrip().startswith('--'):
        continue
    body = balanced(src, m.end() - 1)
    if body is None:
        continue
    args = split_args(body)
    if len(args) < 2:
        continue
    key = key_of(args[0])
    if key:
        rows.append((key, describe(args[1])))

# The workspace loop uses a computed key, so list it by hand.
if re.search(r'for i = 1, 10 do', src):
    rows.append(('Super + 1-0', 'Go to workspace 1-10'))
    rows.append(('Super + Shift + 1-0', 'Move window to workspace 1-10'))

seen, uniq = set(), []
for r in rows:
    if r not in seen:
        seen.add(r); uniq.append(r)

w = max(len(k) for k, _ in uniq)
for k, d in uniq:
    print(f'{k:<{w}}   {d}')
EOF
