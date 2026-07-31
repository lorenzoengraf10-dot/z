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

# Cada puerta tiene que tener por donde llegar desde afuera.
#
# Mientras nada colisionaba esto no molestaba: entrabas atravesando la pared.
# Con las paredes frenando de verdad, un arbol plantado justo en la entrada
# deja el edificio inservible, y no se nota hasta que caminas hasta ahi.
SOLID = set("T#RO")
tapadas = []
for y in range(H):
    for x in range(W):
        if at(x, y) != DOOR:
            continue
        # El lado de afuera es el vecino que no es piso ni pared.
        afuera = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if at(x + dx, y + dy) not in (FLOOR, WALL)]
        if not afuera:
            tapadas.append(f"la puerta ({x},{y}) esta rodeada de pared y piso: no da a ningun lado")
        elif all(at(cx, cy) in SOLID for cx, cy in afuera):
            que = ", ".join(f"{at(cx, cy)!r} en ({cx},{cy})" for cx, cy in afuera)
            tapadas.append(f"la puerta ({x},{y}) esta tapada desde afuera por {que}")
print(f"puertas revisadas: {sum(1 for y in range(H) for x in range(W) if at(x, y) == DOOR)}")
problems += tapadas

# El borde del mapa no puede ser caminable.
#
# El anillo de arboles se dibujaba antes que la costa y la costa se lo comia:
# el borde oeste entero era agua caminable y te ibas nadando al vacio.
borde = []
for x in range(W):
    for y in (0, H - 1):
        if at(x, y) not in SOLID and at(x, y) != "~":
            borde.append((x, y, at(x, y)))
for y in range(H):
    for x in (0, W - 1):
        if at(x, y) not in SOLID and at(x, y) != "~":
            borde.append((x, y, at(x, y)))
if borde:
    problems.append(f"el borde del mapa esta abierto en {len(borde)} celdas, "
                    f"por ejemplo {borde[:4]}")
else:
    print("borde del mapa: cerrado")

if problems:
    print("\nPROBLEMAS:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("\nTodas las habitaciones tienen piso, paredes y al menos una puerta.")
