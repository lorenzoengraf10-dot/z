#!/usr/bin/env python3
"""Genera el PNG de tiles placeholder: los 9 tiles de 16x16 en una fila.

Es el arte de relleno que usa el juego mientras ustedes dibujan el propio. Cada
tile que aparezca en assets/tiles/ (pasto.png, arbol.png...) pisa al de aca.

Orden del atlas (tiene que coincidir con CHAR_TO_TILE de world.gd):
  0 pasto | 1 camino | 2 agua | 3 arbol | 4 pared
  5 piso  | 6 roca   | 7 veta | 8 puerta

⚠ SE ESCRIBE EN RGBA8 A PROPOSITO. world.gd arma el atlas con Image.blit_rect(),
que exige que las dos imagenes tengan el MISMO formato: con un PNG sin alpha no
copiaba nada y el mapa entero quedaba invisible. La conversion tambien esta en
world.gd (_listo_para_pegar), pero que el archivo ya nazca RGBA8 es una red mas.
"""
import os
import zlib, struct

TILE = 16
ORDER = ["grass", "path", "water", "tree", "wall", "floor", "rock", "ore", "door"]
# Colores de game/assets/paleta.gpl, para que el placeholder ya se vea
# coherente y el arte real no cambie la paleta del juego, solo el dibujo.
#
# Ojo con no repetir tonos entre tiles distintos: la pared era gris igual que la
# roca y en pantalla no se distinguian. Ahora la pared es LADRILLO (que ademas
# es como la llamamos siempre) y el gris queda solo para roca y veta.
BASE = {
    "grass": (44, 68, 47),      # verde oscuro
    "path":  (109, 90, 62),     # tierra / madera clara apagada
    "water": (36, 64, 92),      # agua
    "tree":  (27, 43, 24),      # verde muy oscuro
    "wall":  (112, 66, 58),     # ladrillo
    "floor": (111, 79, 47),     # madera
    "rock":  (92, 87, 81),      # gris
    "ore":   (92, 87, 81),      # gris (con vetas naranjas encima)
    "door":  (77, 56, 38),      # tierra
}
W, H = TILE * len(ORDER), TILE
px = [[(0, 0, 0) for _ in range(W)] for _ in range(H)]


def idx(name):
    return ORDER.index(name)


def put(name, x, y, color):
    if 0 <= x < TILE and 0 <= y < TILE:
        px[y][idx(name) * TILE + x] = color


for name in ORDER:
    for y in range(TILE):
        for x in range(TILE):
            put(name, x, y, BASE[name])

# camino: piedritas
for y in range(TILE):
    for x in range(TILE):
        if (x + y) % 5 == 0:
            put("path", x, y, (156, 115, 70))

# agua: rayas (ahora se camina, pero lento)
for y in range(TILE):
    if y % 4 == 0:
        for x in range(TILE):
            put("water", x, y, (58, 100, 128))

# arbol: copa + tronco
for y in range(TILE):
    for x in range(TILE):
        cx, cy = x - 8, y - 7
        if cx * cx + cy * cy <= 30:
            put("tree", x, y, (68, 98, 47))
        if 6 <= x <= 9 and y >= 12:
            put("tree", x, y, (77, 56, 38))

# pared: ladrillos
for y in range(TILE):
    for x in range(TILE):
        if y % 5 == 0 or (x + (y // 5) * 3) % 8 == 0:
            put("wall", x, y, (156, 100, 85))

# piso de madera: tablones
for y in range(TILE):
    for x in range(TILE):
        if y % 4 == 0:
            put("floor", x, y, (156, 115, 70))
        if (x + (y // 4) * 5) % 11 == 0:
            put("floor", x, y, (100, 70, 42))

# roca: bloques irregulares
for y in range(TILE):
    for x in range(TILE):
        if (x * 3 + y * 5) % 13 < 3:
            put("rock", x, y, (133, 127, 119))
        if (x * 7 + y * 2) % 17 < 2:
            put("rock", x, y, (59, 55, 51))

# mineral: roca con vetas naranjas
for y in range(TILE):
    for x in range(TILE):
        if (x * 3 + y * 5) % 13 < 3:
            put("ore", x, y, (133, 127, 119))
for (mx, my) in [(4, 4), (5, 4), (4, 5), (10, 6), (11, 6), (6, 11), (7, 11), (11, 11)]:
    put("ore", mx, my, (232, 168, 60))
    put("ore", mx + 1, my + 1, (138, 82, 32))

# puerta: umbral, marco a los costados
for y in range(TILE):
    for x in range(TILE):
        if x < 3 or x > 12:
            put("door", x, y, (46, 35, 24))
for y in range(TILE):
    if y % 3 == 0:
        for x in range(3, 13):
            put("door", x, y, (156, 115, 70))

# borde sutil por tile, para ver la grilla
for i, name in enumerate(ORDER):
    for x in range(TILE):
        for y in (0, TILE - 1):
            c = px[y][i * TILE + x]
            px[y][i * TILE + x] = tuple(int(v * 0.72) for v in c)
    for y in range(TILE):
        for x in (0, TILE - 1):
            c = px[y][i * TILE + x]
            px[y][i * TILE + x] = tuple(int(v * 0.72) for v in c)


def write_png(path, pixels, w, h):
    """Escribe RGBA8 (tipo de color 6). Los tiles son opacos: alpha = 255."""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw += bytes(pixels[y][x]) + b"\xff"

    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        return c + struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)   # 6 = RGBA
    idat = zlib.compress(bytes(raw), 9)
    open(path, "wb").write(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))


out = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "game", "assets", "tiles", "placeholder_tiles.png")
write_png(out, px, W, H)
print(f"PNG: {out} ({W}x{H}, {len(ORDER)} tiles)")
for i, n in enumerate(ORDER):
    print(f"  {i} {n}")
