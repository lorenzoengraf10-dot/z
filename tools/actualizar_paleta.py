#!/usr/bin/env python3
"""Suma a la paleta del proyecto cualquier color nuevo que aparezca en el arte.

La paleta arrancó siendo una restriccion ("no dibujar con colores de afuera"),
y el equipo decidio que sea otra cosa: un **catalogo compartido que crece**. Si
hace falta un color por lo estetico, se usa, y despues se corre esto:

    python3 tools/actualizar_paleta.py

Recorre todos los PNG de assets/tiles/ y assets/sprites/, junta los colores que
aparecen de verdad, y agrega a la paleta los que todavia no esten. Regenera:

    game/assets/paleta.gpl   el que importan Aseprite / LibreSprite / GIMP
    game/assets/paleta.png   la tira de muestras
    docs/ARTE_SPEC.md        la tabla de colores (entre las marcas PALETA)

Lo importante es que **no toca ningun dibujo**: solo anota los colores para que
los tres puedan cargar la misma paleta y elegir de ahi en vez de inventar un
tono parecido pero distinto cada uno.

Opciones:
    --dry-run    dice que agregaria, sin escribir nada
"""
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "game", "assets")
GPL = os.path.join(ASSETS, "paleta.gpl")
PNG = os.path.join(ASSETS, "paleta.png")
SPEC = os.path.join(ROOT, "docs", "ARTE_SPEC.md")

## Entre estas marcas se reescribe la tabla del doc.
MARCA_INI = "<!-- PALETA:INICIO (generado por tools/actualizar_paleta.py) -->"
MARCA_FIN = "<!-- PALETA:FIN -->"

COLS = 8
DRY = "--dry-run" in sys.argv


# ------------------------------------------------------------------ lectura PNG
def leer_colores(path):
    """Colores opacos de un PNG de 8 bits sin entrelazar. Set de (r,g,b)."""
    d = open(path, "rb").read()
    if not d.startswith(b"\x89PNG\r\n\x1a\n"):
        return set()
    ancho, alto = struct.unpack(">II", d[16:24])
    profundidad, tipo, entrelazado = d[24], d[25], d[28]
    if profundidad != 8 or tipo not in (2, 6) or entrelazado != 0:
        return set()

    idat = b""
    pos = 8
    while pos < len(d):
        n = struct.unpack(">I", d[pos:pos + 4])[0]
        if d[pos + 4:pos + 8] == b"IDAT":
            idat += d[pos + 8:pos + 8 + n]
        pos += 12 + n
    try:
        crudo = zlib.decompress(idat)
    except zlib.error:
        return set()

    canales = 4 if tipo == 6 else 3
    stride = ancho * canales
    colores = set()
    anterior = bytearray(stride)
    off = 0
    for _ in range(alto):
        if off >= len(crudo):
            break
        filtro = crudo[off]
        linea = bytearray(crudo[off + 1:off + 1 + stride])
        off += 1 + stride
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
        for x in range(ancho):
            q = linea[x * canales:(x + 1) * canales]
            # Lo transparente no cuenta: no es un color, es la ausencia de uno.
            if canales == 3 or q[3] > 0:
                colores.add((q[0], q[1], q[2]))
        anterior = linea
    return colores


def escribir_png(path, filas, ancho, alto, escala):
    crudo = b""
    for y in range(alto):
        for _ in range(escala):
            linea = b"\x00"
            for x in range(ancho):
                linea += bytes(filas[y][x]) * escala
            crudo += linea

    def chunk(tag, payload):
        cuerpo = tag + payload
        return (struct.pack(">I", len(payload)) + cuerpo
                + struct.pack(">I", zlib.crc32(cuerpo) & 0xFFFFFFFF))

    open(path, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", ancho * escala, alto * escala,
                                     8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(crudo, 9))
        + chunk(b"IEND", b""))


# ------------------------------------------------------------- nombrar un color
FAMILIAS = [
    (15, "Rojo"), (45, "Naranja"), (70, "Amarillo"), (160, "Verde"),
    (200, "Celeste"), (255, "Azul"), (290, "Violeta"), (335, "Magenta"),
    (360, "Rojo"),
]


def nombrar(rgb):
    """Un nombre legible para un color nuevo, del tipo 'Azul oscuro'."""
    r, g, b = (v / 255.0 for v in rgb)
    alto, bajo = max(r, g, b), min(r, g, b)
    croma = alto - bajo

    if croma < 0.08:
        escala = ["Negro", "Gris muy oscuro", "Gris oscuro", "Gris",
                  "Gris claro", "Blanco"]
        return escala[min(int(alto * len(escala)), len(escala) - 1)]

    if alto == r:
        tono = (60 * ((g - b) / croma)) % 360
    elif alto == g:
        tono = 60 * ((b - r) / croma) + 120
    else:
        tono = 60 * ((r - g) / croma) + 240

    familia = next(nombre for limite, nombre in FAMILIAS if tono <= limite)
    if alto < 0.30:
        return familia + " muy oscuro"
    if alto < 0.55:
        return familia + " oscuro"
    if alto > 0.88 and croma > 0.55:
        return familia + " brillante"
    if alto > 0.80:
        return familia + " claro"
    return familia


# ------------------------------------------------------------------- la paleta
def leer_gpl():
    """[(nombre, (r,g,b))] en el orden del archivo."""
    if not os.path.exists(GPL):
        return []
    paleta = []
    for linea in open(GPL, encoding="utf-8"):
        if linea.startswith("#") or not linea.strip():
            continue
        partes = linea.split(None, 3)
        if len(partes) >= 3 and all(p.isdigit() for p in partes[:3]):
            rgb = tuple(int(p) for p in partes[:3])
            nombre = partes[3].strip() if len(partes) > 3 else nombrar(rgb)
            paleta.append((nombre, rgb))
    return paleta


def pngs_del_arte():
    """Los PNG dibujados a mano. Los placeholder NO cuentan.

    Los placeholder los genera un script con sombreado calculado, así que
    traen decenas de marrones y negros casi iguales que nadie eligió. Si
    entraran a la paleta, la llenarían de ruido y taparían los colores que sí
    eligió alguien.
    """
    for carpeta in ("tiles", "sprites"):
        base = os.path.join(ASSETS, carpeta)
        for raiz, _, archivos in os.walk(base):
            for archivo in sorted(archivos):
                if not archivo.lower().endswith(".png"):
                    continue
                if archivo.lower().startswith("placeholder"):
                    continue
                yield os.path.join(raiz, archivo)


paleta = leer_gpl()
conocidos = {rgb for _, rgb in paleta}
print(f"paleta actual: {len(paleta)} colores")

nuevos = {}
revisados = 0
for path in pngs_del_arte():
    revisados += 1
    for rgb in leer_colores(path):
        if rgb not in conocidos:
            nuevos.setdefault(rgb, os.path.relpath(path, ASSETS))

print(f"revisados: {revisados} PNG de assets/tiles/ y assets/sprites/")

if not nuevos:
    print("\nNo hay colores nuevos: la paleta ya cubre todo el arte.")
    sys.exit(0)

# Nombres unicos, con un numero al final si se repite la familia.
usados = {nombre for nombre, _ in paleta}
agregados = []
for rgb in sorted(nuevos, key=lambda c: (-max(c), c)):
    base = nombrar(rgb)
    nombre, n = base, 2
    while nombre in usados:
        nombre = f"{base} {n}"
        n += 1
    usados.add(nombre)
    agregados.append((nombre, rgb))

print(f"\n{len(agregados)} color(es) nuevo(s):")
for nombre, rgb in agregados:
    print("  #%02x%02x%02x  %-20s (visto en %s)"
          % (rgb[0], rgb[1], rgb[2], nombre, nuevos[rgb]))

if DRY:
    print("\n--dry-run: no se escribio nada.")
    sys.exit(0)

paleta += agregados

# --- .gpl ---
gpl = ["GIMP Palette", "Name: Cuarentena", f"Columns: {COLS}",
       "# Paleta del proyecto. En Aseprite: menu de la paleta -> Load Palette.",
       "#",
       "# La paleta CRECE: si te hace falta un color que no esta, usalo y despues",
       "# corre  python3 tools/actualizar_paleta.py  para que lo tengan todos.",
       "# Este archivo se genera solo, no lo edites a mano.", "#"]
for nombre, (r, g, b) in paleta:
    gpl.append("%3d %3d %3d\t%s" % (r, g, b, nombre))
open(GPL, "w", encoding="utf-8").write("\n".join(gpl) + "\n")

# --- .png ---
filas_n = (len(paleta) + COLS - 1) // COLS
muestras = [[(18, 16, 15) for _ in range(COLS)] for _ in range(filas_n)]
for i, (_, rgb) in enumerate(paleta):
    muestras[i // COLS][i % COLS] = rgb
escribir_png(PNG, muestras, COLS, filas_n, escala=32)

# --- la tabla del doc ---
tabla = ["| Color | Hex | | Color | Hex |", "|---|---|---|---|---|"]
mitad = (len(paleta) + 1) // 2
for i in range(mitad):
    izq = paleta[i]
    fila = f"| {izq[0]} | `#{izq[1][0]:02x}{izq[1][1]:02x}{izq[1][2]:02x}` |"
    if i + mitad < len(paleta):
        der = paleta[i + mitad]
        fila += f" | {der[0]} | `#{der[1][0]:02x}{der[1][1]:02x}{der[1][2]:02x}` |"
    else:
        fila += " | | |"
    tabla.append(fila)

if os.path.exists(SPEC):
    doc = open(SPEC, encoding="utf-8").read()
    if MARCA_INI in doc and MARCA_FIN in doc:
        nuevo = MARCA_INI + "\n" + "\n".join(tabla) + "\n" + MARCA_FIN
        doc = re.sub(re.escape(MARCA_INI) + r".*?" + re.escape(MARCA_FIN),
                     lambda _: nuevo, doc, flags=re.S)
        open(SPEC, "w", encoding="utf-8").write(doc)
        print(f"\ntabla actualizada en {os.path.relpath(SPEC, ROOT)}")
    else:
        print(f"\nOjo: no encontre las marcas PALETA en {os.path.relpath(SPEC, ROOT)};"
              " la tabla del doc quedo sin actualizar.")

print(f"\nPaleta: {len(paleta)} colores")
print(f"  -> {os.path.relpath(GPL, ROOT)}")
print(f"  -> {os.path.relpath(PNG, ROOT)} ({COLS * 32}x{filas_n * 32})")
print("\nAvisenle al resto que vuelvan a cargar la paleta en Aseprite/Piskel.")
