#!/usr/bin/env python3
"""Conversor Markdown -> HTML acotado a lo que usa LEGAL_Y_PRIVACIDAD.md:
encabezados, citas, tablas, listas (con anidado y checkboxes), negrita,
codigo inline y links."""
import html
import re
import sys


def inline(text):
    """Formato dentro de una linea. Se escapa primero para no romper el HTML."""
    out = html.escape(text)
    # codigo inline (antes que negrita, para no formatear adentro del codigo)
    out = re.sub(r'`([^`]+)`', r'<code>\1</code>', out)
    out = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', out)
    # cursiva: va despues de la negrita, cuando ya no quedan ** sueltos
    out = re.sub(r'(?<!\*)\*([^*\n]+)\*(?!\*)', r'<em>\1</em>', out)
    # links [texto](url)
    out = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', out)
    return out


def is_table_sep(line):
    return bool(re.match(r'^\s*\|[\s:|-]+\|\s*$', line)) and '-' in line


def split_row(line):
    cells = line.strip().strip('|').split('|')
    return [c.strip() for c in cells]


def convert(md):
    lines = md.split('\n')
    out = []
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        stripped = line.strip()

        # linea en blanco
        if not stripped:
            i += 1
            continue

        # encabezados
        m = re.match(r'^(#{1,6})\s+(.*)$', stripped)
        if m:
            level = len(m.group(1))
            out.append(f'<h{level}>{inline(m.group(2))}</h{level}>')
            i += 1
            continue

        # cita (>)
        if stripped.startswith('>'):
            buf = []
            while i < n and lines[i].strip().startswith('>'):
                buf.append(re.sub(r'^\s*>\s?', '', lines[i]))
                i += 1
            out.append('<blockquote>' + inline(' '.join(b.strip() for b in buf)) + '</blockquote>')
            continue

        # tabla
        if stripped.startswith('|') and i + 1 < n and is_table_sep(lines[i + 1]):
            header = split_row(lines[i])
            i += 2
            body = []
            while i < n and lines[i].strip().startswith('|'):
                body.append(split_row(lines[i]))
                i += 1
            t = ['<table>', '<thead><tr>']
            for cell in header:
                t.append(f'<th>{inline(cell)}</th>')
            t.append('</tr></thead><tbody>')
            for row in body:
                t.append('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in row) + '</tr>')
            t.append('</tbody></table>')
            out.append(''.join(t))
            continue

        # listas (con vinetas o numeradas)
        if re.match(r'^\s*([-*]|\d+\.)\s+', line):
            ordered = bool(re.match(r'^\s*\d+\.\s+', line))
            block, i = parse_list(lines, i, ordered)
            out.append(block)
            continue

        # parrafo: junta lineas hasta un blanco o hasta que empiece otro bloque
        buf = []
        while i < n and lines[i].strip():
            s = lines[i].strip()
            if re.match(r'^(#{1,6})\s', s) or s.startswith('>') or s.startswith('|') \
               or re.match(r'^\s*[-*]\s+', lines[i]) or re.match(r'^\s*\d+\.\s+', lines[i]):
                break
            buf.append(s)
            i += 1
        if buf:
            out.append('<p>' + inline(' '.join(buf)) + '</p>')
        else:
            i += 1

    return '\n'.join(out)


def parse_list(lines, start, ordered):
    """Devuelve (html, indice_siguiente).

    Maneja tres cosas que aparecen en el documento:
      - items normales y checkboxes
      - sublistas indentadas
      - lineas de continuacion (texto del item que sigue en la linea de abajo)
    """
    n = len(lines)
    i = start
    base_indent = len(lines[i]) - len(lines[i].lstrip())
    tag = 'ol' if ordered else 'ul'
    # Guardamos el texto CRUDO de cada item y recien al final le aplicamos el
    # formato inline: si no, una negrita partida en dos lineas (**algo\notro**)
    # nunca se cierra y queda sin convertir.
    raws = []      # markdown crudo de cada item
    prefixes = []  # html fijo que va antes (el cuadradito del checkbox)
    subs = []      # html de la sublista colgada de cada item

    def next_nonblank(idx):
        for j in range(idx, n):
            if lines[j].strip():
                return j
        return None

    while i < n:
        line = lines[i]

        if not line.strip():
            # Un blanco corta la lista salvo que despues siga otro item.
            j = next_nonblank(i + 1)
            if j is None:
                break
            j_indent = len(lines[j]) - len(lines[j].lstrip())
            if j_indent >= base_indent and re.match(r'^\s*([-*]|\d+\.)\s+', lines[j]):
                i += 1
                continue
            break

        indent = len(line) - len(line.lstrip())
        if indent < base_indent:
            break

        marker = re.match(r'^\s*(?:[-*]|\d+\.)\s+(.*)$', line)

        if indent == base_indent and marker:
            content = marker.group(1)
            cb = re.match(r'^\[([ xX])\]\s*(.*)$', content)
            if cb:
                mark = '&#9745;' if cb.group(1).lower() == 'x' else '&#9744;'
                prefixes.append(f'<span class="cb">{mark}</span> ')
                raws.append(cb.group(2))
            else:
                prefixes.append('')
                raws.append(content)
            subs.append('')
            i += 1
            continue

        if indent > base_indent and marker:
            sub, i = parse_list(lines, i, ordered=bool(re.match(r'^\s*\d+\.', line)))
            if subs:
                subs[-1] += sub
            else:
                prefixes.append('')
                raws.append('')
                subs.append(sub)
            continue

        if indent > base_indent and not marker:
            # Continuacion del item: se pega al crudo del ultimo item.
            if raws:
                raws[-1] += ' ' + line.strip()
            i += 1
            continue

        break

    body = ''.join(
        f'<li>{prefixes[k]}{inline(raws[k])}{subs[k]}</li>' for k in range(len(raws))
    )
    return f'<{tag}>{body}</{tag}>', i


CSS = """
@page { size: A4; margin: 18mm 16mm 18mm 16mm; }
* { box-sizing: border-box; }
body {
  font-family: "DejaVu Sans", "Noto Color Emoji", sans-serif;
  font-size: 10.5pt; line-height: 1.55; color: #1c1c20; margin: 0;
}
h1 {
  font-size: 21pt; margin: 0 0 4pt; color: #0f1a2b;
  border-bottom: 2.5pt solid #b34a3a; padding-bottom: 6pt;
}
h2 {
  font-size: 14pt; margin: 20pt 0 6pt; color: #0f1a2b;
  border-bottom: 0.7pt solid #ccc; padding-bottom: 3pt;
  page-break-after: avoid;
}
h3 { font-size: 11.5pt; margin: 13pt 0 4pt; color: #b34a3a; page-break-after: avoid; }
p { margin: 6pt 0; text-align: justify; }
strong { color: #0f1a2b; }
code {
  font-family: "DejaVu Sans Mono", monospace; font-size: 8.8pt;
  background: #f0f0f3; padding: 1pt 3pt; border-radius: 2pt;
}
a { color: #1c4f8c; text-decoration: none; }
blockquote {
  margin: 10pt 0; padding: 8pt 11pt; background: #fdf3e7;
  border-left: 3pt solid #d98b3a; font-size: 10pt;
}
table {
  width: 100%; border-collapse: collapse; margin: 9pt 0;
  font-size: 9.2pt; page-break-inside: avoid;
}
th {
  background: #2b3a4f; color: #fff; text-align: left;
  padding: 5pt 6pt; font-weight: bold;
}
td { padding: 5pt 6pt; border-bottom: 0.5pt solid #dcdce2; vertical-align: top; }
tbody tr:nth-child(even) { background: #f7f7fa; }
ul, ol { margin: 6pt 0; padding-left: 17pt; }
li { margin: 3pt 0; }
li > ul, li > ol { margin: 3pt 0; }
.cb { font-family: "DejaVu Sans", sans-serif; color: #666; }
/* En las listas de tareas el cuadradito ya hace de vineta */
li:has(> .cb) { list-style: none; margin-left: -11pt; }
.footer {
  margin-top: 22pt; padding-top: 7pt; border-top: 0.7pt solid #ccc;
  font-size: 8pt; color: #777; text-align: center;
}
"""


def main():
    src, dst = sys.argv[1], sys.argv[2]
    md = open(src, encoding='utf-8').read()
    body = convert(md)
    page = f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<title>Legal y privacidad — Cuarentena</title>
<style>{CSS}</style></head>
<body>
{body}
<div class="footer">Proyecto Cuarentena · documento interno del equipo · generado desde docs/LEGAL_Y_PRIVACIDAD.md</div>
</body></html>"""
    open(dst, 'w', encoding='utf-8').write(page)
    print(f"HTML -> {dst} ({len(body)} chars)")


if __name__ == '__main__':
    main()
