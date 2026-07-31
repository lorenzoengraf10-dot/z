#!/usr/bin/env python3
"""Verifica que el reparto de contenedores funcione en el mapa actual.

Repite el mismo criterio que loot_system.gd: un contenedor va en una celda de
piso que toca una pared y que NO esta al lado de la puerta. Si un edificio no
tiene ni un lugar asi, se entra a un edificio vacio y el loop se rompe.

Se le puede pasar otro mapa por argumento (lo usa la prueba del verificador).
"""
import sys
import os

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

MAP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(GAME, "data", "level_prototype.txt")
FLOOR, WALL, DOOR = ",", "#", "D"
# Los mismos numeros que loot_system.gd.
CELLS_PER_CONTAINER = 7
MAX_PER_BUILDING = 4
MIN_ROOM_CELLS = 4      # loot_system ignora los grupos de piso mas chicos

lines = [l.rstrip("\n") for l in open(MAP) if l.strip("\n")]
H = len(lines)
W = max(len(l) for l in lines)


def at(x, y):
    if 0 <= y < H and 0 <= x < len(lines[y]):
        return lines[y][x]
    return " "


# --- Edificios = componentes conexas de piso ---
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
            seen.add((cx, cy))
            cells.append((cx, cy))
            stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
        rooms.append(cells)

problems = []
total_containers = 0
print(f"Mapa {W}x{H} · edificios con piso: {len(rooms)}")

for i, cells in enumerate(rooms):
    if len(cells) < MIN_ROOM_CELLS:
        problems.append(
            f"edificio #{i}: solo {len(cells)} celdas de piso, loot_system.gd lo ignora"
        )
        continue

    spots = 0
    for (x, y) in cells:
        touches_wall = touches_door = False
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c = at(x + dx, y + dy)
            if c == WALL:
                touches_wall = True
            elif c == DOOR:
                touches_door = True
        if touches_wall and not touches_door:
            spots += 1

    wanted = max(1, min(len(cells) // CELLS_PER_CONTAINER, MAX_PER_BUILDING))
    placed = min(wanted, spots)
    total_containers += placed
    x0 = min(c[0] for c in cells)
    y0 = min(c[1] for c in cells)
    print(f"  #{i:2d} en ({x0:3d},{y0:3d}): {len(cells):3d} piso · "
          f"{spots:3d} lugares · {placed} contenedor(es)")
    if placed == 0:
        problems.append(
            f"edificio #{i} en ({x0},{y0}): no entra ningun contenedor "
            "(no hay piso pegado a pared lejos de la puerta)"
        )

print(f"\ncontenedores que se van a repartir: {total_containers}")
if total_containers < 20:
    problems.append(f"solo {total_containers} contenedores en todo el mapa: hay poco que saquear")

if problems:
    print("\nPROBLEMAS:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("Todos los edificios reciben al menos un contenedor.")
