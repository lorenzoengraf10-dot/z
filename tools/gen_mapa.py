#!/usr/bin/env python3
"""Mapa 160x100 hecho a mano: costa al oeste, lago, tres pueblos, una zona
industrial, una granja y canteras al este.

Es mas grande que el anterior (120x76) porque ahora el jugador aparece en un
punto al azar en cada partida: hace falta que haya cosas repartidas por todos
lados, no solo alrededor del centro.

Leyenda: . pasto | = camino | ~ agua | T arbol | # pared | , piso
         R roca | O veta de mineral | D puerta
"""
import math
import os
import random

random.seed(2026)

W, H = 160, 100
OFF_X, OFF_Y = W // 2, H // 2
SOLID = set("T#RO")
TILE = 16

g = [["." for _ in range(W)] for _ in range(H)]


def rect(top, left, h, w, ch):
    for y in range(top, top + h):
        for x in range(left, left + w):
            if 0 <= y < H and 0 <= x < W:
                g[y][x] = ch


def blob(cy, cx, ry_, rx_, ch, density, only_on=(".",)):
    for y in range(cy - ry_, cy + ry_ + 1):
        for x in range(cx - rx_, cx + rx_ + 1):
            if 2 <= y < H - 2 and 2 <= x < W - 2 and g[y][x] in only_on:
                dy, dx = (y - cy) / float(ry_), (x - cx) / float(rx_)
                if dy * dy + dx * dx <= 1.0 and random.random() < density:
                    g[y][x] = ch


# El anillo de arboles del borde se dibuja AL FINAL del archivo, no aca: si se
# dibuja antes, la costa lo pisa y el mapa queda abierto por el oeste (era el
# bug de "te salis del mapa nadando").

# --- Costa al oeste, con borde irregular ---
for y in range(H):
    shore = 10 + int(3 * random.random()) + int(4 * math.sin(y / 7.0))
    for x in range(0, shore):
        g[y][x] = "~"

# --- Lago interior al sudoeste ---
for y in range(58, 80):
    for x in range(22, 50):
        dy, dx = (y - 69) / 10.0, (x - 36) / 13.0
        if dy * dy + dx * dx <= 1.0:
            g[y][x] = "~"

# --- Rio que baja del lago al mar ---
ry, rx = 79, 33
while ry < H - 4 and rx > 14:
    g[ry][rx] = "~"
    g[ry][rx + 1] = "~"
    ry += 1
    if ry % 3 == 0:
        rx -= 1

# --- Bosques grandes: son la cobertura, lo que te deja moverte sin que te vean ---
blob(14, 40, 10, 22, "T", 0.62)
blob(16, 118, 11, 21, "T", 0.58)
blob(46, 30, 11, 13, "T", 0.58)
blob(88, 62, 9, 24, "T", 0.58)
blob(70, 108, 11, 19, "T", 0.52)
blob(36, 68, 7, 10, "T", 0.45)
blob(60, 136, 9, 12, "T", 0.5)
blob(92, 96, 6, 16, "T", 0.5)

# --- Arboledas sueltas, para que el campo abierto no sea una cancha de futbol ---
for cy, cx in [(8, 26), (10, 70), (12, 92), (22, 34), (28, 78), (32, 128),
               (42, 100), (44, 134), (54, 68), (58, 108), (60, 34), (64, 128),
               (72, 26), (74, 88), (82, 118), (90, 140), (94, 66), (20, 148),
               (48, 84), (66, 46)]:
    blob(cy, cx, random.randint(2, 4), random.randint(3, 6), "T", 0.65)

# --- Charcos: agua potable lejos de la costa (y pesca de emergencia) ---
for cy, cx, r in [(30, 108, 3), (58, 62, 3), (86, 96, 3), (18, 60, 2)]:
    blob(cy, cx, r, r + 2, "~", 1.0)

# --- Roca y mineral al este (para la mineria) ---
blob(38, 146, 16, 11, "R", 0.72)
blob(76, 148, 13, 9, "R", 0.7)
blob(38, 146, 12, 8, "O", 0.14, only_on=("R",))
blob(76, 148, 10, 7, "O", 0.14, only_on=("R",))
# canteras chicas repartidas, para poder minar sin cruzar medio mapa
for cy, cx in [(30, 62), (62, 90), (86, 34), (20, 96)]:
    blob(cy, cx, 4, 5, "R", 0.8)
    blob(cy, cx, 3, 3, "O", 0.22, only_on=("R",))

# --- Caminos ---
for x in range(2, W - 2):
    g[50][x] = "="              # ruta principal este-oeste
for y in range(2, H - 2):
    g[y][80] = "="              # ruta principal norte-sur
for x in range(46, 140):
    g[24][x] = "="              # calle del pueblo norte
for x in range(46, 140):
    g[76][x] = "="              # calle del pueblo sur
for y in range(24, 77):
    g[y][46] = "="              # transversal oeste (zona industrial)
for y in range(24, 77):
    g[y][118] = "="             # transversal este (granja)
for x in range(80, 128):
    g[88][x] = "="              # camino a la granja


def building(top, left, h, w, door_side="S"):
    """Paredes + piso de madera + una puerta D en el lado indicado."""
    rect(top, left, h, w, "#")
    rect(top + 1, left + 1, h - 2, w - 2, ",")
    if door_side == "S":
        g[top + h - 1][left + w // 2] = "D"
    elif door_side == "N":
        g[top][left + w // 2] = "D"
    elif door_side == "W":
        g[top + h // 2][left] = "D"
    else:
        g[top + h // 2][left + w - 1] = "D"


# --- Pueblo norte (el mas grande) ---
building(14, 50, 7, 11, "S")
building(14, 64, 6, 10, "S")
building(14, 90, 7, 12, "S")
building(14, 106, 6, 10, "S")
building(28, 50, 8, 12, "N")
building(28, 66, 6, 9, "N")
building(28, 88, 7, 11, "N")
building(28, 104, 6, 10, "N")
building(16, 128, 8, 9, "W")

# --- Pueblo sur ---
building(66, 56, 7, 10, "S")
building(66, 70, 6, 9, "S")
building(66, 96, 7, 11, "S")
building(80, 58, 6, 9, "N")
building(80, 70, 7, 10, "N")
building(80, 96, 6, 10, "N")

# --- Zona industrial al oeste: galpones grandes, mas loot y mas zombies ---
building(34, 22, 11, 18, "E")
building(34, 56, 10, 16, "W")
building(50, 22, 9, 15, "E")
building(56, 56, 8, 14, "W")

# --- Granja al sudeste ---
building(84, 106, 8, 13, "N")
building(84, 124, 6, 10, "N")
# Ojo: no puede bajar mas, o el anillo de arboles del borde (filas 98-99) le
# come la pared de abajo y el edificio queda abierto.
building(92, 112, 5, 9, "S")

# --- Puesto aislado al noreste, lejos de todo ---
building(8, 138, 6, 9, "S")

# --- Cabana suelta al sur del lago ---
building(88, 46, 5, 8, "E")


# --- Despejar la entrada de cada puerta -------------------------------------
# Los bosques se dibujan antes que los edificios, asi que a veces queda un arbol
# (o una veta) justo en la celda de afuera de una puerta. Mientras nada
# colisionaba no molestaba; con las paredes frenando de verdad, esa casa queda
# sin entrada. Despejamos dos celdas hacia afuera para que se pueda llegar.
despejadas = 0
for y in range(H):
    for x in range(W):
        if g[y][x] != "D":
            continue
        # El lado de afuera es el vecino que no es piso ni pared.
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if g[y + dy][x + dx] in ",#":
                continue
            for paso in (1, 2):
                ny, nx = y + dy * paso, x + dx * paso
                if 2 <= ny < H - 2 and 2 <= nx < W - 2 and g[ny][nx] in SOLID:
                    g[ny][nx] = "."
                    despejadas += 1


# --- Anillo de arboles del borde (ULTIMO, para que nada lo pise) -------------
# Donde el borde da al mar lo dejamos agua: un paredon de arboles en el medio
# del oceano queda feo. Lo que cierra el mapa ahi es la pared invisible que arma
# world.gd (_build_boundary), que no depende del dibujo.
for x in range(W):
    for y in (0, 1, H - 2, H - 1):
        if g[y][x] != "~":
            g[y][x] = "T"
for y in range(H):
    for x in (0, 1, W - 2, W - 1):
        if g[y][x] != "~":
            g[y][x] = "T"

lines = ["".join(r) for r in g]
out = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "game", "data", "level_prototype.txt")
open(out, "w").write("\n".join(lines) + "\n")


# ======================= verificacion =======================
def world_of(col, row):
    return ((col - OFF_X) * TILE, (row - OFF_Y) * TILE)


fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


print(f"Mapa {W}x{H} -> {out}")
counts = {}
for row in g:
    for ch in row:
        counts[ch] = counts.get(ch, 0) + 1
print("tiles:", {k: v for k, v in sorted(counts.items(), key=lambda kv: -kv[1])})

# 1. Todas las filas del mismo largo
check(len({len(l) for l in lines}) == 1, "hay filas de distinto largo")
check(len(lines) == H, "faltan filas")

# 2. Interiores: flood fill desde el borde con la puerta como pared
blocked = {(x, y) for y in range(H) for x in range(W)
           if g[y][x] in SOLID or g[y][x] == "D"}
seen = set()
stack = ([(x, y) for x in range(W) for y in (0, H - 1)]
         + [(x, y) for y in range(H) for x in (0, W - 1)])
while stack:
    x, y = stack.pop()
    if (x, y) in seen or (x, y) in blocked or not (0 <= x < W and 0 <= y < H):
        continue
    seen.add((x, y))
    stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

interior = [(x, y) for y in range(H) for x in range(W)
            if g[y][x] not in SOLID and g[y][x] != "D" and (x, y) not in seen]
print("celdas de interior (flood fill):", len(interior))
check(len(interior) > 200, "el flood fill no detecto los interiores")

# 3. Edificios: componentes conexas de piso ','
floor_cells = {(x, y) for y in range(H) for x in range(W) if g[y][x] == ","}
pending = set(floor_cells)
rooms = []
while pending:
    start = pending.pop()
    group = [start]
    stack = [start]
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) in pending:
                pending.discard((nx, ny))
                group.append((nx, ny))
                stack.append((nx, ny))
    rooms.append(group)

print("edificios detectados:", len(rooms))
check(len(rooms) == 24, f"esperaba 24 edificios, hay {len(rooms)}")

for i, room in enumerate(rooms):
    xs = [c[0] for c in room]
    ys = [c[1] for c in room]
    doors = 0
    loot_spots = 0
    for (x, y) in room:
        touches_wall = False
        touches_door = False
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            ch = g[ny][nx]
            if ch == "#":
                touches_wall = True
            elif ch == "D":
                touches_door = True
                doors += 1
        if touches_wall and not touches_door:
            loot_spots += 1
    tag = f"edificio {i} en ({min(xs)},{min(ys)})-({max(xs)},{max(ys)})"
    check(doors >= 1, f"{tag}: no tiene puerta")
    check(loot_spots >= 1, f"{tag}: no tiene lugar para contenedores")
    # todo lo que rodea al piso tiene que ser pared, puerta u otro piso
    for (x, y) in room:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            check(g[ny][nx] in "#,D", f"{tag}: piso abierto al exterior en ({nx},{ny})")

# 3.b Cada puerta tiene que tener por donde llegar desde afuera
print(f"celdas despejadas frente a las puertas: {despejadas}")
tapadas = []
for y in range(H):
    for x in range(W):
        if g[y][x] != "D":
            continue
        afuera = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if g[y + dy][x + dx] not in ",#"]
        if not afuera or all(g[cy][cx] in SOLID for cx, cy in afuera):
            tapadas.append((x, y))
check(not tapadas, f"puertas sin acceso desde afuera: {tapadas}")

# 3.c El borde del mapa no puede ser caminable (solido o agua, nada mas)
borde_abierto = []
for x in range(W):
    for y in (0, H - 1):
        if g[y][x] not in SOLID and g[y][x] != "~":
            borde_abierto.append((x, y, g[y][x]))
for y in range(H):
    for x in (0, W - 1):
        if g[y][x] not in SOLID and g[y][x] != "~":
            borde_abierto.append((x, y, g[y][x]))
check(not borde_abierto, f"el borde del mapa esta abierto en {borde_abierto[:6]}")

# 4. Puntos de spawn validos (mismo criterio que run_manager._is_good_spawn)
margin = 4
spawns = []
for y in range(margin, H - margin):
    for x in range(margin, W - margin):
        if g[y][x] not in (".", "="):
            continue
        if any(g[y + dy][x + dx] in SOLID
               for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
            continue
        spawns.append((x, y))

print("puntos de spawn validos:", len(spawns))
check(len(spawns) >= 1500, f"pocos puntos de spawn ({len(spawns)})")

# repartidos: cada cuadrante tiene que tener su parte
quads = {"NO": 0, "NE": 0, "SO": 0, "SE": 0}
for x, y in spawns:
    key = ("N" if y < H // 2 else "S") + ("O" if x < W // 2 else "E")
    quads[key] += 1
print("spawns por cuadrante:", quads)
for key, n in quads.items():
    check(n >= 150, f"el cuadrante {key} tiene solo {n} puntos de spawn")

# ningun spawn cae dentro de un edificio
inside = {c for room in rooms for c in room}
check(not (set(spawns) & inside), "hay spawns dentro de un edificio")

# 5. Los caminos principales se cruzan y son transitables
check(g[50][80] == "=", "el cruce principal no es camino")

# 6. Hay agua accesible (para pescar) y roca (para minar) en cada mitad
def has_near(ch, x0, x1, y0, y1):
    return any(g[y][x] == ch for y in range(y0, y1) for x in range(x0, x1))


check(has_near("~", 2, W // 2, 2, H - 2), "no hay agua en la mitad oeste")
check(has_near("R", W // 2, W - 2, 2, H - 2), "no hay roca en la mitad este")
check(has_near("R", 2, W // 2, 2, H - 2), "no hay roca en la mitad oeste")

print()
if fails:
    print("FALLOS:")
    for f in fails:
        print("  -", f)
    raise SystemExit(1)
print("OK: mapa valido")

# --- posiciones sugeridas para Main.tscn ---
def find_free(near_col, near_row, want=(".", "=")):
    for rad in range(0, 22):
        for dy in range(-rad, rad + 1):
            for dx in range(-rad, rad + 1):
                y, x = near_row + dy, near_col + dx
                if not (3 <= y < H - 3 and 3 <= x < W - 3):
                    continue
                if g[y][x] in want and (x, y) in seen:
                    if not any(g[y + a][x + b] in SOLID
                               for a in (-1, 0, 1) for b in (-1, 0, 1)):
                        return (x, y)
    return None


print("\n-- posiciones para Main.tscn --")
wanted = {
    "Campfire": (76, 52), "Workbench": (76, 54),
    "Zombie": (60, 22), "Zombie2": (100, 30), "Zombie3": (72, 74),
    "Zombie4": (40, 46), "Zombie5": (118, 60), "Zombie6": (110, 86),
    "Animal": (56, 92), "Animal2": (128, 40), "Animal3": (30, 60),
    "Wolf": (42, 16), "Wolf2": (46, 14), "Wolf3": (60, 90), "Wolf4": (108, 70),
    "Pickup": (78, 48), "Pickup2": (84, 56), "Pickup3": (74, 44),
}
for name, (c, r) in wanted.items():
    spot = find_free(c, r)
    col, row = spot
    wx, wy = world_of(col, row)
    print(f'{name}: position = Vector2({wx}, {wy})   # celda ({col},{row}) {g[row][col]!r}')
