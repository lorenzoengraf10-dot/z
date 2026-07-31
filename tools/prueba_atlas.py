#!/usr/bin/env python3
"""Replica lo que hace world.gd._build_atlas() y dibuja el resultado.

Existe por el bug de "no se ve nada del mapa": el atlas quedaba entero
transparente y el juego abria igual, sin un solo mensaje de error. Como aca no
se puede correr Godot, esto arma el mismo atlas en Python y contesta las dos
preguntas que importan:

  1. ¿Quedo algun tile transparente?  (es lo que revisa _verify_atlas() adentro
     del juego)
  2. ¿Se distinguen los 9 entre si?   (si dos salen del mismo color, en pantalla
     no se nota la diferencia aunque tecnicamente esten bien)

Ademas deja un PNG ampliado para mirarlo con los ojos. El fucsia marca lo
transparente.

Uso:  python3 tools/prueba_atlas.py [salida.png]

No prueba a Godot: prueba la logica. La prueba de verdad es abrir el proyecto.
"""
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD_GD = os.path.join(ROOT, "game", "scripts", "world.gd")
PLACEHOLDER = os.path.join(ROOT, "game", "assets", "tiles", "placeholder_tiles.png")
SALIDA = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "atlas_resultado.png")

TILE = 16
## Cuanto se agranda cada pixel en el PNG de salida, para poder mirarlo.
ESCALA = 12
## Diferencia minima entre los promedios de dos tiles para considerarlos
## distinguibles de un vistazo.
MIN_DIFERENCIA = 12


def tiles_de_world_gd():
    """(indice, nombre) de cada tile, leidos de CHAR_TO_TILE y TILE_NAMES.

    Se leen del codigo y no se escriben aca, igual que en check_arte.py: si
    alguien agrega un tile, esta prueba se entera sola.
    """
    src = open(WORLD_GD, encoding="utf-8").read()

    def bloque(nombre):
        m = re.search(r"const %s\s*:=\s*\{(.*?)\}" % nombre, src, re.S)
        if not m:
            sys.exit("prueba_atlas: no encontre %s en world.gd" % nombre)
        return m.group(1)

    nombres = dict(re.findall(r"(\w+)\s*:\s*\"([^\"]+)\"", bloque("TILE_NAMES")))
    indices = dict(re.findall(r"(\w+)\s*:\s*(\d+)", bloque("CHAR_TO_TILE")))
    return sorted((int(i), nombres.get(k, k)) for k, i in indices.items())


def leer_png(path):
    """(ancho, alto, canales, pixeles) de un PNG de 8 bits sin entrelazar."""
    d = open(path, "rb").read()
    ancho, alto = struct.unpack(">II", d[16:24])
    canales = 4 if d[25] == 6 else 3
    idat = b""
    pos = 8
    while pos < len(d):
        n = struct.unpack(">I", d[pos:pos + 4])[0]
        if d[pos + 4:pos + 8] == b"IDAT":
            idat += d[pos + 8:pos + 8 + n]
        pos += 12 + n

    crudo = zlib.decompress(idat)
    px = []
    anterior = bytearray(ancho * canales)
    off = 0
    for _ in range(alto):
        filtro = crudo[off]
        linea = bytearray(crudo[off + 1:off + 1 + ancho * canales])
        off += 1 + ancho * canales
        for i in range(len(linea)):
            a = linea[i - canales] if i >= canales else 0
            b = anterior[i]
            c = anterior[i - canales] if i >= canales else 0
            if filtro == 1:
                linea[i] = (linea[i] + a) & 255
            elif filtro == 2:
                linea[i] = (linea[i] + b) & 255
            elif filtro == 3:
                linea[i] = (linea[i] + (a + b) // 2) & 255
            elif filtro == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                linea[i] = (linea[i] + (a if pa <= pb and pa <= pc
                                        else (b if pb <= pc else c))) & 255
        px.append([tuple(linea[x * canales:(x + 1) * canales]) + ((255,) if canales == 3 else ())
                   for x in range(ancho)])
        anterior = linea
    return ancho, alto, canales, px


def escribir_png(path, filas):
    """Guarda una grilla de (r,g,b) como PNG RGB."""
    alto = len(filas)
    ancho = len(filas[0])
    crudo = b""
    for fila in filas:
        crudo += b"\x00" + b"".join(bytes(p) for p in fila)

    def chunk(tag, payload):
        cuerpo = tag + payload
        return (struct.pack(">I", len(payload)) + cuerpo
                + struct.pack(">I", zlib.crc32(cuerpo) & 0xFFFFFFFF))

    open(path, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(crudo, 9))
        + chunk(b"IEND", b""))


tiles = tiles_de_world_gd()
ancho, alto, canales, base = leer_png(PLACEHOLDER)
print("placeholder: %dx%d, %s" % (ancho, alto, "RGBA" if canales == 4 else "RGB (SIN alpha)"))

# El atlas destino, RGBA8 y transparente, igual que en world.gd.
atlas = [[(0, 0, 0, 0)] * ancho for _ in range(TILE)]

# ⚠ Aca esta el bug reproducido: Image.blit_rect() de Godot SOLO copia si los
# dos formatos coinciden. Si el placeholder viene RGB y el atlas es RGBA, no
# copia nada, no tira excepcion, y el mapa entero se ve de un color plano.
if canales != 4:
    print("!! blit_rect NO copiaria nada: el origen es RGB y el destino RGBA8.")
    print("   Regenera el placeholder con: python3 tools/gen_tiles_placeholder.py")
else:
    for indice, _ in tiles:
        for y in range(TILE):
            for x in range(TILE):
                atlas[y][indice * TILE + x] = base[y][indice * TILE + x]

# 1. Que ningun tile haya quedado transparente (lo mismo que _verify_atlas()).
vacios = [nombre for indice, nombre in tiles
          if all(atlas[y][indice * TILE + x][3] == 0
                 for y in range(TILE) for x in range(TILE))]
print("tiles transparentes:", ", ".join(vacios) if vacios else "ninguno")

# 2. Que se distingan entre si.
promedios = []
for indice, nombre in tiles:
    ps = [atlas[y][indice * TILE + x] for y in range(TILE) for x in range(TILE)]
    prom = tuple(sum(p[c] for p in ps) // len(ps) for c in range(3))
    promedios.append((nombre, prom))
    print("  %-8s promedio rgb%s  colores distintos: %d" % (nombre, prom, len(set(ps))))

iguales = ["%s/%s" % (a[0], b[0])
           for i, a in enumerate(promedios) for b in promedios[i + 1:]
           if sum(abs(a[1][c] - b[1][c]) for c in range(3)) < MIN_DIFERENCIA]
print("pares casi identicos:", ", ".join(iguales) if iguales else "ninguno")

# Render ampliado para mirarlo.
filas = []
for y in range(TILE):
    fila = []
    for x in range(ancho):
        r, g, b, a = atlas[y][x]
        fila += [(r, g, b) if a > 0 else (255, 0, 255)] * ESCALA   # fucsia = transparente
    filas += [fila] * ESCALA
escribir_png(SALIDA, filas)
print("\nrender -> %s (el fucsia seria transparente)" % SALIDA)

sys.exit(1 if vacios or iguales else 0)
