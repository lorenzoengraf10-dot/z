#!/usr/bin/env python3
"""Revisa el pixel art antes de que rompa el juego.

Los errores de arte fallan raro: el sprite no aparece, o aparece con un cuadrado
de fondo, o la animacion se corta a la mitad, y no hay ningun mensaje de error.
Este verificador los caza leyendo los PNG, sin abrir Godot.

Ademas muestra QUE FALTA, que es la forma mas simple de ver como viene el arte.

Uso:  python3 tools/verificadores/check_arte.py
      python3 tools/verificadores/check_arte.py otra/carpeta   (para probarlo)
"""
import os
import re
import struct
import sys
import zlib

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

ASSETS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(GAME, "assets")

TILE_SIZE = 16
CHAR_SIZE = 32
DIRECCIONES = ("abajo", "arriba", "lado")

# Lo que el juego espera NO se escribe aca: se lee del codigo, para que las dos
# listas no puedan separarse nunca. Si alguien agrega un tile o un personaje, el
# verificador se entera solo.


def nombres_de_tiles():
    """Saca los nombres de archivo del diccionario TILE_NAMES de world.gd."""
    src = open(os.path.join(GAME, "scripts", "world.gd"), encoding="utf-8").read()
    bloque = re.search(r'const TILE_NAMES\s*:=\s*\{(.*?)\}', src, re.S)
    if not bloque:
        print("check_arte: no encontre TILE_NAMES en world.gd", file=sys.stderr)
        return []
    return re.findall(r':\s*"([^"]+)"', bloque.group(1))


def nombres_de_personajes():
    """Saca los sprite_name de las escenas que usan SpriteDirectional."""
    escenas = os.path.join(GAME, "scenes")
    nombres = []
    for archivo in sorted(os.listdir(escenas)):
        if not archivo.endswith(".tscn"):
            continue
        src = open(os.path.join(escenas, archivo), encoding="utf-8").read()
        if "sprite_directional.gd" not in src:
            continue
        for nombre in re.findall(r'^sprite_name\s*=\s*"([^"]+)"', src, re.M):
            nombres.append(nombre)
    return nombres


def nombres_de_variantes_con_arte_propio():
    """Sprites que usan algunas variantes en vez del personaje base.

    No aparecen en ningún .tscn porque se asignan por código al spawnear (ver
    SPRITE_OVERRIDE en horde_spawner.gd), así que hay que leerlos de ahí para
    que esta lista no se desactualice.
    """
    path = os.path.join(GAME, "scripts", "systems", "horde_spawner.gd")
    if not os.path.exists(path):
        return []
    src = open(path, encoding="utf-8").read()
    bloque = re.search(r'const SPRITE_OVERRIDE\s*:=\s*\{(.*?)\}', src, re.S)
    if not bloque:
        return []
    return re.findall(r':\s*"([^"]+)"', bloque.group(1))


TILES = nombres_de_tiles()
PERSONAJES = nombres_de_personajes() + nombres_de_variantes_con_arte_propio()

errors = []
warns = []


# ---------------------------------------------------------------- lectura PNG
def leer_png(path):
    """Devuelve (ancho, alto, tiene_alpha, colores) o levanta ValueError.

    Se lee a mano porque en esta maquina no hay Pillow. Alcanza con el chunk
    IHDR para las medidas, y con descomprimir IDAT para los colores.
    """
    data = open(path, "rb").read()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        if data[:3] == b"\xff\xd8\xff":
            raise ValueError("es un JPG con nombre de PNG")
        raise ValueError("no es un PNG")

    ancho, alto = struct.unpack(">II", data[16:24])
    profundidad = data[24]
    tipo_color = data[25]
    entrelazado = data[28]
    # tipo 6 = RGBA, 4 = gris+alpha, 3 = paleta (puede tener alpha via tRNS)
    tiene_alpha = tipo_color in (4, 6) or b"tRNS" in data

    colores = set()
    # Solo sacamos los colores del caso comun (RGBA/RGB, 8 bits, sin entrelazar).
    if profundidad == 8 and tipo_color in (2, 6) and entrelazado == 0:
        idat = b""
        pos = 8
        while pos < len(data):
            largo = struct.unpack(">I", data[pos:pos + 4])[0]
            tag = data[pos + 4:pos + 8]
            if tag == b"IDAT":
                idat += data[pos + 8:pos + 8 + largo]
            pos += 12 + largo
        try:
            crudo = zlib.decompress(idat)
        except zlib.error:
            return ancho, alto, tiene_alpha, colores

        canales = 4 if tipo_color == 6 else 3
        stride = ancho * canales
        anterior = bytearray(stride)
        offset = 0
        for _ in range(alto):
            if offset >= len(crudo):
                break
            filtro = crudo[offset]
            linea = bytearray(crudo[offset + 1:offset + 1 + stride])
            offset += 1 + stride
            # Deshacer el filtro por scanline (los 5 tipos del formato PNG).
            for i in range(len(linea)):
                a = linea[i - canales] if i >= canales else 0
                b = anterior[i]
                c = anterior[i - canales] if i >= canales else 0
                if filtro == 1:
                    linea[i] = (linea[i] + a) & 0xFF
                elif filtro == 2:
                    linea[i] = (linea[i] + b) & 0xFF
                elif filtro == 3:
                    linea[i] = (linea[i] + (a + b) // 2) & 0xFF
                elif filtro == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                    linea[i] = (linea[i] + pred) & 0xFF
            for x in range(ancho):
                px = linea[x * canales:(x + 1) * canales]
                if canales == 4 and px[3] == 0:
                    continue          # transparente: no cuenta como color usado
                colores.add((px[0], px[1], px[2]))
            anterior = linea

    return ancho, alto, tiene_alpha, colores


def cargar_paleta():
    path = os.path.join(GAME, "assets", "paleta.gpl")
    if not os.path.exists(path):
        return set()
    paleta = set()
    for linea in open(path, encoding="utf-8"):
        partes = linea.split()
        if len(partes) >= 3 and all(p.isdigit() for p in partes[:3]):
            paleta.add(tuple(int(p) for p in partes[:3]))
    return paleta


PALETA = cargar_paleta()


def revisar(path, esperado, necesita_alpha):
    """Revisa un PNG. `esperado` es el lado en pixeles."""
    rel = os.path.relpath(path, ASSETS)
    try:
        ancho, alto, tiene_alpha, colores = leer_png(path)
    except ValueError as e:
        errors.append(f"{rel}: {e} — hay que exportarlo como PNG de verdad "
                      "(ver docs/ARTE_SPEC.md)")
        return
    except Exception as e:
        errors.append(f"{rel}: no se pudo leer ({e})")
        return

    if (ancho, alto) != (esperado, esperado):
        errors.append(f"{rel}: mide {ancho}x{alto} y tiene que medir "
                      f"{esperado}x{esperado}")

    if necesita_alpha and not tiene_alpha:
        errors.append(f"{rel}: no tiene transparencia — en el juego se va a ver "
                      "un cuadrado de fondo alrededor del personaje")

    if PALETA and colores:
        fuera = colores - PALETA
        if fuera:
            muestra = ", ".join("#%02x%02x%02x" % c for c in sorted(fuera)[:4])
            warns.append(f"{rel}: {len(fuera)} color(es) fuera de la paleta ({muestra}"
                         f"{'...' if len(fuera) > 4 else ''})")


# ------------------------------------------------------------------- recorrido
print("=== ARTE ===")

tiles_dir = os.path.join(ASSETS, "tiles")
faltan_tiles = []
hay_tiles = 0
for nombre in TILES:
    path = os.path.join(tiles_dir, nombre + ".png")
    if os.path.exists(path):
        revisar(path, TILE_SIZE, necesita_alpha=False)
        hay_tiles += 1
    else:
        faltan_tiles.append(nombre)
print(f"tiles: {hay_tiles}/{len(TILES)}")

sprites_dir = os.path.join(ASSETS, "sprites")
faltan_sprites = []
hay_sprites = 0
total_sprites = len(PERSONAJES) * len(DIRECCIONES)

for personaje in PERSONAJES:
    carpeta = os.path.join(sprites_dir, personaje)
    for direccion in DIRECCIONES:
        quieto = os.path.join(carpeta, direccion + ".png")
        cuadros = []
        i = 1
        while True:
            f = os.path.join(carpeta, f"{direccion}_{i}.png")
            if not os.path.exists(f):
                break
            cuadros.append(f)
            i += 1

        if cuadros:
            hay_sprites += 1
            for f in cuadros:
                revisar(f, CHAR_SIZE, necesita_alpha=True)
            # Un hueco en la numeracion corta la animacion sin avisar.
            sueltos = [f for f in os.listdir(carpeta)
                       if f.startswith(direccion + "_") and f.endswith(".png")] \
                      if os.path.isdir(carpeta) else []
            if len(sueltos) > len(cuadros):
                errors.append(
                    f"{personaje}/{direccion}: hay {len(sueltos)} cuadros pero la "
                    f"numeracion se corta en _{len(cuadros)} — falta _{len(cuadros) + 1}")
            if os.path.exists(quieto):
                warns.append(f"{personaje}/{direccion}: estan el animado y el quieto "
                             f"({direccion}.png); manda el animado")
        elif os.path.exists(quieto):
            hay_sprites += 1
            revisar(quieto, CHAR_SIZE, necesita_alpha=True)
        else:
            faltan_sprites.append(f"{personaje}/{direccion}")

print(f"direcciones de personaje: {hay_sprites}/{total_sprites}")

# ------------------------------------------------- el placeholder de los tiles
#
# El placeholder tiene que tener alpha (RGBA) aunque sea todo opaco. Godot arma
# el atlas en FORMAT_RGBA8 y blit_rect() no copia nada si los formatos no
# coinciden: falla EN SILENCIO y el mapa entero se ve como un color plano. Ya
# paso una vez, con el placeholder guardado como RGB.
placeholder = os.path.join(ASSETS, "tiles", "placeholder_tiles.png")
if not os.path.exists(placeholder):
    errors.append("falta assets/tiles/placeholder_tiles.png — sin el, los tiles que "
                  "todavia no tienen arte quedan transparentes "
                  "(se regenera con: python3 tools/gen_tiles_placeholder.py)")
else:
    try:
        ancho, alto, tiene_alpha, _ = leer_png(placeholder)
        if not tiene_alpha:
            errors.append("placeholder_tiles.png esta guardado SIN alpha. El atlas de "
                          "world.gd es RGBA8 y blit_rect() exige el mismo formato: si no "
                          "coincide no copia nada y el mapa se ve como un color plano. "
                          "Regeneralo con: python3 tools/gen_tiles_placeholder.py")
        esperado = TILE_SIZE * len(TILES)
        if (ancho, alto) != (esperado, TILE_SIZE):
            errors.append(f"placeholder_tiles.png mide {ancho}x{alto} y tendria que medir "
                          f"{esperado}x{TILE_SIZE} ({len(TILES)} tiles de {TILE_SIZE}px)")
    except ValueError as e:
        errors.append(f"placeholder_tiles.png: {e}")

# ------------------------------------------------------------------- resultado
if faltan_tiles or faltan_sprites:
    print("\n-- todavia se dibujan como placeholder --")
    if faltan_tiles:
        print("   tiles:   " + ", ".join(faltan_tiles))
    if faltan_sprites:
        print("   sprites: " + ", ".join(faltan_sprites))

if warns:
    print("\n=== AVISOS ===")
    for w in warns:
        print("  -", w)

print("\n=== ERRORES ===")
if errors:
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("(ninguno)")
