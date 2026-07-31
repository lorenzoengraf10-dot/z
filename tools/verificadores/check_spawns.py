#!/usr/bin/env python3
"""Verifica que las entidades de Main.tscn esten sobre tiles caminables."""
import re, sys
import os

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

lines = [l.rstrip("\n") for l in open(os.path.join(GAME, "data", "level_prototype.txt")) if l.strip("\n")]
H = len(lines); W = max(len(l) for l in lines)
off_x, off_y = W // 2, H // 2
SOLID = set("T#RO")   # el agua ya NO es solida: se camina lento

def char_at(wx, wy):
    col = int(round(wx / 16.0)) + off_x
    row = int(round(wy / 16.0)) + off_y
    if not (0 <= row < H and 0 <= col < len(lines[row])):
        return None
    return lines[row][col]

src = open(os.path.join(GAME, "scenes", "Main.tscn")).read()
blocks = re.split(r'\n(?=\[node )', src)

bad = []
print(f"Mapa {W}x{H}, centro=({off_x},{off_y})\n")
print("Jugador (0,0):", repr(char_at(0, 0)))
if char_at(0, 0) in SOLID:
    bad.append("Player spawnea en tile solido")

for b in blocks:
    m = re.match(r'\[node name="([^"]+)"', b)
    if not m:
        continue
    name = m.group(1)
    pm = re.search(r'^position = Vector2\(([-\d.]+), *([-\d.]+)\)', b, re.M)
    if not pm:
        continue
    x, y = float(pm.group(1)), float(pm.group(2))
    ch = char_at(x, y)
    status = "OK " if ch not in SOLID and ch is not None else "MAL"
    print(f"{status} {name:12} ({x:6.0f},{y:6.0f}) -> {ch!r}")
    if ch in SOLID or ch is None:
        bad.append(f"{name} en {ch!r}")

print()
if bad:
    print("PROBLEMAS:", bad); sys.exit(1)
print("Todas las entidades sobre tiles caminables.")
