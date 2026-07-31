#!/usr/bin/env python3
"""Verifica el sistema de techos: que cada edificio del mapa quede detectado
como habitacion (por su piso de madera) y tenga al menos una puerta."""
import sys
import os

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

lines = [l.rstrip("\n") for l in open(os.path.join(GAME, "data", "level_prototype.txt")) if l.strip("\n")]
H = len(lines); W = max(len(l) for l in lines)
FLOOR, WALL, DOOR = ",", "#", "D"

def at(x, y):
    if 0 <= y < H and 0 <= x < len(lines[y]):
        return lines[y][x]
    return " "

# habitaciones = componentes conexas de piso de madera (lo mismo que hace roof_system.gd)
seen = set()
rooms = []
for y in range(H):
    for x in range(W):
        if at(x, y) != FLOOR or (x, y) in seen:
            continue
        stack, cells = [(x, y)], []
        while stack:
            cx, cy = stack.pop()
            if (cx, cy) in seen or at(cx, cy) != FLOOR:
                continue
            seen.add((cx, cy)); cells.append((cx, cy))
            stack += [(cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)]
        rooms.append(cells)

print(f"Mapa {W}x{H}")
print(f"habitaciones detectadas: {len(rooms)}")
problems = []
for i, cells in enumerate(rooms):
    # puertas pegadas a la habitacion
    doors = set()
    walls = 0
    for (x, y) in cells:
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            c = at(x+dx, y+dy)
            if c == DOOR:
                doors.add((x+dx, y+dy))
            elif c == WALL:
                walls += 1
    print(f"  #{i}: {len(cells):3d} celdas de piso · {len(doors)} puerta(s)")
    if not doors:
        problems.append(f"la habitacion #{i} no tiene puerta: no se puede entrar")
    if walls == 0:
        problems.append(f"la habitacion #{i} no tiene paredes alrededor")

total_floor = sum(len(c) for c in rooms)
print(f"total celdas de piso: {total_floor}")

if problems:
    print("\nPROBLEMAS:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("\nTodas las habitaciones tienen piso, paredes y al menos una puerta.")
