#!/usr/bin/env python3
"""Verifica el spawn aleatorio de cada partida.

Repite el criterio de run_manager._is_good_spawn(): pasto o camino, con las 8
celdas de alrededor libres de solidos, y a 4 celdas del borde. Si no hay
suficientes puntos asi, o estan todos en la misma esquina, el spawn aleatorio
deja de tener gracia (o directamente falla y te deja en el centro siempre).

Se le puede pasar otro mapa por argumento (lo usa la prueba del verificador).
"""
import sys
import os

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

MAP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(GAME, "data", "level_prototype.txt")
SOLID = set("T#RO")      # el agua no es solida, pero tampoco es spawn valido
WALKABLE = (".", "=")
MARGIN = 4               # el mismo margen que run_manager.gd
MIN_TOTAL = 1500
MIN_PER_QUADRANT = 150

lines = [l.rstrip("\n") for l in open(MAP) if l.strip("\n")]
H = len(lines)
W = max(len(l) for l in lines)


def at(x, y):
    if 0 <= y < H and 0 <= x < len(lines[y]):
        return lines[y][x]
    return "#"     # fuera del mapa cuenta como solido, igual que world.is_solid_cell


spawns = []
for y in range(MARGIN, H - MARGIN):
    for x in range(MARGIN, W - MARGIN):
        if at(x, y) not in WALKABLE:
            continue
        if any(at(x + dx, y + dy) in SOLID for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
            continue
        spawns.append((x, y))

# Interiores de edificios: nadie tiene que aparecer encerrado en una casa.
floor_cells = {(x, y) for y in range(H) for x in range(W) if at(x, y) == ","}

quads = {"NO": 0, "NE": 0, "SO": 0, "SE": 0}
for x, y in spawns:
    quads[("N" if y < H // 2 else "S") + ("O" if x < W // 2 else "E")] += 1

print(f"Mapa {W}x{H}")
print(f"puntos de spawn validos: {len(spawns)}")
print("por cuadrante:", quads)

problems = []
if len(spawns) < MIN_TOTAL:
    problems.append(f"solo {len(spawns)} puntos de spawn (minimo {MIN_TOTAL})")
for key, n in quads.items():
    if n < MIN_PER_QUADRANT:
        problems.append(f"el cuadrante {key} tiene {n} puntos (minimo {MIN_PER_QUADRANT})")
inside = set(spawns) & floor_cells
if inside:
    problems.append(f"{len(inside)} puntos de spawn caen dentro de un edificio")

# El bucle de run_manager prueba 300 celdas al azar: con esta densidad la chance
# de no encontrar ninguna tiene que ser practicamente cero.
usable = (H - 2 * MARGIN) * (W - 2 * MARGIN)
density = len(spawns) / float(usable)
print(f"densidad: {density:.1%} de las celdas del interior del mapa")
if density < 0.10:
    problems.append(f"densidad muy baja ({density:.1%}): 300 intentos pueden no alcanzar")

if problems:
    print("\nPROBLEMAS:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("\nEl spawn aleatorio tiene de donde elegir en todo el mapa.")
