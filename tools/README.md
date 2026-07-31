# tools/

Utilidades del proyecto (no son parte del juego). Todas son Python 3 sin
dependencias: se corren con `python3 tools/...` desde la raíz del repo.

## `verificadores/` — revisar el proyecto sin abrir Godot

```bash
python3 tools/verificadores/run_all.py        # todos, resumido
python3 tools/verificadores/run_all.py -v     # con la salida completa
```

| Verificador | Qué revisa |
|---|---|
| `check_project.py` | que todas las rutas `res://` existan, que el `load_steps` de cada `.tscn` coincida con los recursos que declara, y que los JSON parseen |
| `check_types.py` | los errores de tipado que GDScript tira **al compilar**: `:=` que no puede inferir el tipo, y miembros de `Node2D` usados sobre variables tipadas como `Node` (el caso clásico del `for` sobre `get_nodes_in_group()`) |
| `check_data.py` | que `loot_tables.json` y `recipes.json` solo nombren ítems que existen, que los perks tengan requisitos válidos y que cada arma de fuego apunte a una munición real |
| `check_rooms.py` | que cada edificio del mapa tenga piso, paredes y al menos una puerta |
| `check_loot.py` | que cada edificio reciba al menos un contenedor (piso pegado a pared y lejos de la puerta) |
| `check_runspawn.py` | que haya puntos de spawn aleatorio válidos y repartidos por los cuatro cuadrantes del mapa |
| `check_spawns.py` | que las entidades colocadas en `Main.tscn` no caigan sobre un tile sólido |

`check_loot.py` y `check_runspawn.py` aceptan un mapa como argumento
(`python3 tools/verificadores/check_loot.py otro_mapa.txt`), que es como se
prueba que el verificador realmente falla cuando el mapa está mal.

**Ojo con lo que NO revisan:** no ejecutan el juego. Que esté todo en verde
significa que el proyecto debería *abrir*, no que se juegue bien. Eso lo dice el
playtest.

## `gen_mapa.py` — regenerar el mapa del nivel

Escribe `game/data/level_prototype.txt` (160×100) y verifica lo que generó:
edificios cerrados con puerta, puntos de spawn repartidos, agua y roca en las dos
mitades. Al final imprime las posiciones sugeridas, en coordenadas de mundo, para
las entidades de `Main.tscn`.

```bash
python3 tools/gen_mapa.py
```

El mapa también se puede editar **a mano** con cualquier editor de texto (es la
forma normal de tocarlo: la leyenda está en `game/README.md`). El generador es
para cuando hace falta rehacerlo entero; si lo corrés, pisa los cambios manuales.

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
