#!/usr/bin/env python3
"""Genera la paleta del proyecto en los formatos que hacen falta.

Los tres van a dibujar por separado. Sin una paleta comun, sale un juego con
tres estilos distintos y unificarlo despues es REHACER, no retocar. Por eso la
paleta se define antes de dibujar el primer pixel.

Salidas:
  game/assets/paleta.gpl   -> el que Aseprite / GIMP / LibreSprite importan
  game/assets/paleta.png   -> una tira para tener a mano y para el doc
  (la tabla en hex se imprime, va a docs/ARTE_SPEC.md)

Criterio de los colores: el GDD pide tono "apagado / de colapso". Nada de
colores puros y saturados. Cada familia tiene 4 pasos (oscuro -> claro) para
poder sombrear sin inventar colores en el momento.
"""
import os
import struct
import zlib

# --- La paleta ---------------------------------------------------------------
# Agrupada por familia. El nombre es el que se usa al hablar entre nosotros.
PALETA = [
    ("Negro",           "12100f"),
    ("Sombra",          "241f1d"),
    ("Gris oscuro",     "3b3733"),
    ("Gris",            "5c5751"),
    ("Gris claro",      "857f77"),
    ("Hueso",           "bab3a6"),
    ("Blanco sucio",    "e6e0d2"),

    ("Verde muy oscuro", "1b2b18"),
    ("Verde oscuro",    "2c4423"),
    ("Verde",           "44622f"),
    ("Verde claro",     "6b8a3e"),

    ("Tierra oscura",   "2e2318"),
    ("Tierra",          "4d3826"),
    ("Madera",          "6f4f2f"),
    ("Madera clara",    "9c7346"),
    ("Arena",           "c2a066"),

    ("Agua profunda",   "16273d"),
    ("Agua",            "24405c"),
    ("Agua clara",      "3a6480"),
    ("Cielo",           "6f97a8"),

    ("Ladrillo oscuro", "4a2c25"),
    ("Ladrillo",        "70423a"),
    ("Ladrillo claro",  "9c6455"),

    ("Sangre",          "6e1414"),
    ("Rojo",            "a82a24"),
    ("Rojo claro",      "d4544a"),

    ("Oxido",           "8a5220"),
    ("Naranja",         "c8802c"),
    ("Fuego",           "e8a83c"),
    ("Amarillo",        "e6cf6a"),

    ("Violeta oscuro",  "38264a"),
    ("Violeta",         "5c4470"),
]


def hex_to_rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def png(path, pixels, w, h, scale=1):
    """Escribe un PNG RGB sin dependencias externas (no hay Pillow acá)."""
    raw = b""
    for y in range(h):
        for _ in range(scale):
            line = b"\x00"
            for x in range(w):
                line += bytes(pixels[y][x]) * scale
            raw += line

    def chunk(tag, data):
        body = tag + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xffffffff))

    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 2, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(raw, 9))
    out += chunk(b"IEND", b"")
    open(path, "wb").write(out)


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "game", "assets")
os.makedirs(ASSETS, exist_ok=True)

# --- .gpl: el formato que importa Aseprite -----------------------------------
gpl = ["GIMP Palette", "Name: Cuarentena", "Columns: 8",
       "# Paleta del proyecto. En Aseprite: menu de la paleta -> Load Palette.",
       "# NO dibujar con colores de afuera de esta lista.", "#"]
for nombre, valor in PALETA:
    r, g, b = hex_to_rgb(valor)
    gpl.append("%3d %3d %3d\t%s" % (r, g, b, nombre))
open(os.path.join(ASSETS, "paleta.gpl"), "w").write("\n".join(gpl) + "\n")

# --- .png: una tira de muestras ----------------------------------------------
COLS = 8
filas = (len(PALETA) + COLS - 1) // COLS
pixels = [[(18, 16, 15) for _ in range(COLS)] for _ in range(filas)]
for i, (_, valor) in enumerate(PALETA):
    pixels[i // COLS][i % COLS] = hex_to_rgb(valor)
png(os.path.join(ASSETS, "paleta.png"), pixels, COLS, filas, scale=32)

# --- La tabla para el doc ----------------------------------------------------
print(f"Paleta de {len(PALETA)} colores")
print(f"  -> {os.path.join(ASSETS, 'paleta.gpl')}")
print(f"  -> {os.path.join(ASSETS, 'paleta.png')} ({COLS * 32}x{filas * 32})")
print()
print("| Color | Hex |")
print("|---|---|")
for nombre, valor in PALETA:
    print(f"| {nombre} | `#{valor}` |")
