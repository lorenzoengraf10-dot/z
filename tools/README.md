# tools/

Utilidades del proyecto (no son parte del juego).

## `md2html.py` — pasar un documento a PDF

Convierte un `.md` del proyecto a HTML con estilo de impresión, para después
sacar un PDF. Se usó para generar `docs/Cuarentena-Legal-y-Privacidad.pdf`.

Si editan el `.md`, se regenera el PDF así:

```bash
# 1) markdown -> html
python3 tools/md2html.py docs/LEGAL_Y_PRIVACIDAD.md /tmp/legal.html

# 2) html -> pdf (con Chrome o Chromium instalado)
chromium --headless --no-pdf-header-footer \
  --print-to-pdf=docs/Cuarentena-Legal-y-Privacidad.pdf /tmp/legal.html
```

En Windows el segundo paso es lo mismo, apuntando al `chrome.exe`; o abrir el
HTML en el navegador y usar **Imprimir → Guardar como PDF** (queda igual, porque
el estilo de impresión ya está en el HTML).

Soporta lo que usan nuestros documentos: encabezados, citas, tablas, listas con
anidado y checkboxes, negrita, cursiva, código inline y links. No es un
conversor de Markdown completo, es a medida de estos archivos.
