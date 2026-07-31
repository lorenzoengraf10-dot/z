#!/usr/bin/env python3
"""Genera un muñeco de prueba de 32x32 en las 3 direcciones.

Sirve para comprobar que el andamiaje de sprites anda, ANTES de tener el arte
propio. Es una prueba, no arte del juego: el dibujo real lo hacen ustedes.

    python3 tools/gen_sprite_prueba.py          # aparece el muñeco
    rm -rf game/assets/sprites/jugador          # vuelve el cuadrado azul

Abriendo el juego entre un comando y el otro se ve el sistema completo: el PNG
aparece en la carpeta y el jugador cambia solo, sin tocar una linea de codigo.
"""
import os
import struct
import sys
import zlib

TRANSP = (0, 0, 0, 0)


def png_rgba(path, px, w, h):
    raw = b""
    for y in range(h):
        raw += b"\x00" + b"".join(bytes(px[y][x]) for x in range(w))

    def chunk(tag, data):
        body = tag + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xffffffff))

    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(raw, 9))
    out += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(out)


def hexa(v, a=255):
    return (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), a)


# Colores sacados de game/assets/paleta.gpl
PIEL     = hexa("9c7346")
ROPA     = hexa("2c4423")
ROPA_OSC = hexa("1b2b18")
PELO     = hexa("2e2318")
BOTA     = hexa("241f1d")
OJO      = hexa("12100f")


def muneco(direccion):
    """Un muñeco simple de 32x32 con los pies en la fila 24, como pide el spec."""
    px = [[TRANSP for _ in range(32)] for _ in range(32)]

    def rect(x0, y0, x1, y1, color):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= y < 32 and 0 <= x < 32:
                    px[y][x] = color

    # Piernas y botas: apoyan justo en la fila 24.
    rect(13, 19, 15, 24, ROPA_OSC)
    rect(17, 19, 19, 24, ROPA_OSC)
    rect(13, 23, 15, 24, BOTA)
    rect(17, 23, 19, 24, BOTA)
    # Torso
    rect(12, 12, 20, 20, ROPA)
    rect(12, 12, 20, 13, ROPA_OSC)     # hombros
    # Brazos
    rect(10, 13, 11, 19, ROPA)
    rect(21, 13, 22, 19, ROPA)
    # Cabeza
    rect(13, 5, 19, 12, PIEL)

    if direccion == "abajo":
        rect(13, 5, 19, 7, PELO)
        px[9][15] = OJO
        px[9][17] = OJO
    elif direccion == "arriba":
        rect(13, 5, 19, 11, PELO)      # de espaldas: se ve todo el pelo
    else:                               # lado, mirando a la DERECHA
        rect(13, 5, 19, 7, PELO)
        rect(13, 5, 15, 10, PELO)      # la nuca queda a la izquierda
        px[9][18] = OJO
        rect(20, 8, 21, 10, PIEL)      # la nariz asoma

    return px


RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POR_DEFECTO = os.path.join(RAIZ, "game", "assets", "sprites", "jugador")
destino = sys.argv[1] if len(sys.argv) > 1 else POR_DEFECTO
for direccion in ("abajo", "arriba", "lado"):
    png_rgba(os.path.join(destino, direccion + ".png"), muneco(direccion), 32, 32)
    print("escrito", os.path.join(destino, direccion + ".png"))
