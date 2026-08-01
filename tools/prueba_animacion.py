#!/usr/bin/env python3
"""Mira una animación de un personaje sin abrir Godot, y busca errores típicos.

Los errores de animación son de los que no se ven mirando un cuadro suelto: un
píxel que se escapó en uno solo de los ocho, un cuadro que quedó 2 px más a la
derecha, una numeración con un hueco. En movimiento se ven como un parpadeo o
un tirón, y cuesta muchísimo darse cuenta de cuál de los cuadros es.

Uso:
    python3 tools/prueba_animacion.py zombi_resistente abajo
    python3 tools/prueba_animacion.py zombi_resistente          (las 3 direcciones)

Deja un PNG con los cuadros en fila y ampliados, para mirarlos uno al lado del
otro. El fucsia marca lo transparente.
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "game", "assets", "sprites")
DIRECCIONES = ("abajo", "arriba", "lado")
MAX_FRAMES = 24
ESCALA = 8
FONDO = (255, 0, 255)   ## fucsia = transparente


def leer_png(path):
    """(ancho, alto, pixeles RGBA) de un PNG de 8 bits sin entrelazar."""
    d = open(path, "rb").read()
    if not d.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("no es un PNG")
    ancho, alto = struct.unpack(">II", d[16:24])
    profundidad, tipo, entrelazado = d[24], d[25], d[28]
    if profundidad != 8 or tipo not in (2, 6) or entrelazado != 0:
        raise ValueError("hace falta un PNG de 8 bits RGB o RGBA, sin entrelazar")

    idat = b""
    pos = 8
    while pos < len(d):
        n = struct.unpack(">I", d[pos:pos + 4])[0]
        if d[pos + 4:pos + 8] == b"IDAT":
            idat += d[pos + 8:pos + 8 + n]
        pos += 12 + n

    canales = 4 if tipo == 6 else 3
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
        px.append([tuple(linea[x * canales:(x + 1) * canales])
                   + ((255,) if canales == 3 else ())
                   for x in range(ancho)])
        anterior = linea
    return ancho, alto, px


def escribir_png(path, filas):
    alto = len(filas)
    ancho = len(filas[0])
    crudo = b"".join(b"\x00" + b"".join(bytes(p) for p in fila) for fila in filas)

    def chunk(tag, payload):
        cuerpo = tag + payload
        return (struct.pack(">I", len(payload)) + cuerpo
                + struct.pack(">I", zlib.crc32(cuerpo) & 0xFFFFFFFF))

    open(path, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(crudo, 9))
        + chunk(b"IEND", b""))


def bbox(px, ancho, alto):
    """(x0, x1, y0, y1) de lo que NO es transparente, o None si está vacío."""
    xs = [x for y in range(alto) for x in range(ancho) if px[y][x][3] > 0]
    if not xs:
        return None
    ys = [y for y in range(alto) for x in range(ancho) if px[y][x][3] > 0]
    return min(xs), max(xs), min(ys), max(ys)


def sueltos(px, ancho, alto):
    """Píxeles opacos sin ningún vecino opaco (los 8 de alrededor)."""
    encontrados = []
    for y in range(alto):
        for x in range(ancho):
            if px[y][x][3] == 0:
                continue
            vecino = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < ancho and 0 <= ny < alto and px[ny][nx][3] > 0:
                        vecino = True
                        break
                if vecino:
                    break
            if not vecino:
                encontrados.append((x, y))
    return encontrados


def revisar(personaje, direccion):
    """Devuelve la cantidad de problemas encontrados."""
    carpeta = os.path.join(SPRITES, personaje)
    if not os.path.isdir(carpeta):
        print(f"  no existe {os.path.relpath(carpeta, ROOT)}")
        return 0

    # Igual que sprite_directional.gd: primero los numerados, si no el suelto.
    rutas = []
    i = 1
    while i <= MAX_FRAMES:
        p = os.path.join(carpeta, f"{direccion}_{i}.png")
        if not os.path.exists(p):
            break
        rutas.append(p)
        i += 1
    if not rutas:
        p = os.path.join(carpeta, direccion + ".png")
        if os.path.exists(p):
            rutas = [p]
    if not rutas:
        return 0

    print(f"\n=== {personaje}/{direccion} — {len(rutas)} cuadro(s) ===")
    problemas = 0

    # Un hueco en la numeracion corta la animacion sin avisar.
    numerados = [f for f in os.listdir(carpeta)
                 if f.startswith(direccion + "_") and f.endswith(".png")]
    if len(numerados) > len(rutas):
        print(f"  MAL: hay {len(numerados)} archivos numerados pero la cuenta se corta "
              f"en _{len(rutas)} — falta {direccion}_{len(rutas) + 1}.png")
        problemas += 1

    cuadros = []
    for path in rutas:
        try:
            cuadros.append((os.path.basename(path),) + leer_png(path))
        except (ValueError, Exception) as e:
            print(f"  MAL: {os.path.basename(path)}: {e}")
            problemas += 1
    if not cuadros:
        return problemas

    medidas = {(c[1], c[2]) for c in cuadros}
    if len(medidas) > 1:
        print(f"  MAL: los cuadros no miden todos igual: {sorted(medidas)}")
        problemas += 1

    # Todos los bbox y cual se sale del molde. Es lo que delata un pixel que
    # se escapo: un cuadro que ocupa mas ancho que todos los demas.
    cajas = []
    for nombre, ancho, alto, px in cuadros:
        caja = bbox(px, ancho, alto)
        cajas.append((nombre, caja))
        for x, y in sueltos(px, ancho, alto):
            print(f"  MAL: {nombre}: pixel suelto en ({x},{y}), sin nada alrededor")
            problemas += 1

    # Un cuadro que se sale del molde de los demas, y encima con MUY pocos
    # pixeles en esa punta, es casi siempre un resbalon del lapiz. Asi
    # apareció el que tenia el zombi pesado: un solo pixel 1 columna mas a la
    # derecha que los otros 7 cuadros.
    #
    # Ojo con la sensibilidad: que una pose llegue mas abajo es NORMAL (una
    # pierna estirada), por eso no alcanza con mirar la caja. Lo que delata al
    # resbalon es que en esa fila o columna del borde haya casi nada.
    validas = [c for _, c in cajas if c]
    if validas:
        medio = len(validas) // 2
        limite = (sorted(c[0] for c in validas)[medio],
                  sorted(c[1] for c in validas)[medio],
                  sorted(c[2] for c in validas)[medio],
                  sorted(c[3] for c in validas)[medio])
        for (nombre, ancho, alto, px), (_, caja) in zip(cuadros, cajas):
            if caja is None:
                continue
            for lado in range(4):
                # 0 = izquierda, 1 = derecha, 2 = arriba, 3 = abajo
                if lado < 2 and (caja[lado] < limite[0] if lado == 0
                                 else caja[lado] > limite[1]):
                    col = caja[lado]
                    puntos = [(col, y) for y in range(alto) if px[y][col][3] > 0]
                elif lado >= 2 and (caja[lado] < limite[2] if lado == 2
                                    else caja[lado] > limite[3]):
                    ren = caja[lado]
                    puntos = [(x, ren) for x in range(ancho) if px[ren][x][3] > 0]
                else:
                    continue
                # Un solo pixel mas afuera que TODOS los demas cuadros: eso es
                # un resbalon. Con dos ya puede ser la punta de una bota o de
                # un dedo estirado, que es legitimo, asi que no se avisa.
                if len(puntos) == 1:
                    x, y = puntos[0]
                    print(f"  MAL: {nombre}: pixel suelto en ({x},{y}) — se sale "
                          "del molde de los otros cuadros")
                    problemas += 1

    # Repetir un cuadro es normal (ida y vuelta por la misma pose), asi que
    # esto es informativo, no un problema.
    for i in range(len(cuadros)):
        for j in range(i + 1, len(cuadros)):
            if cuadros[i][3] == cuadros[j][3]:
                print(f"  ok: {cuadros[i][0]} y {cuadros[j][0]} son el mismo dibujo")

    for nombre, caja in cajas:
        if caja:
            print(f"  {nombre}: x {caja[0]}-{caja[1]}, y {caja[2]}-{caja[3]} "
                  f"(apoya en la fila {caja[3]})")

    # --- la tira ampliada, para mirarla ---
    ancho, alto = cuadros[0][1], cuadros[0][2]
    filas = []
    for y in range(alto):
        fila = []
        for _, _, _, px in cuadros:
            for x in range(ancho):
                r, g, b, a = px[y][x]
                fila += [(r, g, b) if a > 0 else FONDO] * ESCALA
            fila += [(40, 40, 40)] * ESCALA   # separador entre cuadros
        filas += [fila] * ESCALA

    salida = os.path.join(ROOT, f"animacion_{personaje}_{direccion}.png")
    escribir_png(salida, filas)
    print(f"  -> {os.path.relpath(salida, ROOT)} (el fucsia seria transparente)")
    return problemas


if len(sys.argv) < 2:
    print(__doc__)
    sys.exit(2)

personaje = sys.argv[1]
direcciones = [sys.argv[2]] if len(sys.argv) > 2 else list(DIRECCIONES)

total = sum(revisar(personaje, d) for d in direcciones)
print()
if total:
    print(f"{total} cosa(s) para revisar.")
    sys.exit(1)
print("Sin problemas.")
