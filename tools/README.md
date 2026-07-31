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
| `check_project.py` | que todas las rutas `res://` existan, que el `load_steps` de cada `.tscn` coincida con los recursos que declara, que los JSON parseen, y que en `world.gd` el `add_source()` vaya **antes** del `add_collision_polygon()` (el orden que dejó todo el mapa sin colisiones) |
| `check_types.py` | los errores de tipado que GDScript tira **al compilar**: `:=` que no puede inferir el tipo, y miembros de `Node2D` usados sobre variables tipadas como `Node` (el caso clásico del `for` sobre `get_nodes_in_group()`) |
| `check_data.py` | que `loot_tables.json` y `recipes.json` solo nombren ítems que existen, que los perks tengan requisitos válidos y que cada arma de fuego apunte a una munición real |
| `check_rooms.py` | que cada edificio tenga piso, paredes y puerta, que **a cada puerta se pueda llegar desde afuera** (un árbol plantado en la entrada deja la casa inservible) y que **el borde del mapa esté cerrado** |
| `check_loot.py` | que cada edificio reciba al menos un contenedor (piso pegado a pared y lejos de la puerta) |
| `check_runspawn.py` | que haya puntos de spawn aleatorio válidos y repartidos por los cuatro cuadrantes del mapa |
| `check_spawns.py` | que las entidades colocadas en `Main.tscn` no caigan sobre un tile sólido |
| `check_arte.py` | el pixel art: que sea PNG de verdad (no un JPG renombrado), que los personajes tengan transparencia, que las medidas den, que los cuadros de animación no tengan saltos y que los colores estén en la paleta. Además lista **qué falta dibujar** |

`check_loot.py` y `check_runspawn.py` aceptan un mapa como argumento
(`python3 tools/verificadores/check_loot.py otro_mapa.txt`), que es como se
prueba que el verificador realmente falla cuando el mapa está mal.

Las reglas nuevas se probaron **rompiendo el proyecto a propósito** (reordenando
las líneas de `world.gd`, plantando un árbol en la entrada de una casa y abriendo
un agujero en el borde del mapa) y confirmando que el verificador falla. Un
verificador que nunca falló no sirve de nada: hay que verlo fallar una vez.

**Ojo con lo que NO revisan:** no ejecutan el juego. Que esté todo en verde
significa que el proyecto debería *abrir*, no que se juegue bien. Eso lo dice el
playtest.

## `gen_paleta.py` — la paleta del proyecto

Genera `game/assets/paleta.gpl` (el que importa Aseprite), `paleta.png` y la
tabla en hex. Los tres dibujan con esa paleta; sin eso, tres personas sacan tres
estilos distintos y unificarlo después es rehacer, no retocar.

```bash
python3 tools/gen_paleta.py
```

Para agregar un color, se toca la lista `PALETA` del script y se vuelve a
correr. Avisar al resto antes: `check_arte.py` marca los colores de afuera.

## `gen_sprite_prueba.py` — probar el andamiaje sin tener arte

Genera un muñeco de 32×32 en las 3 direcciones y lo deja en la carpeta del
jugador. Sirve para ver **con los ojos** que el sistema anda:

```bash
python3 tools/gen_sprite_prueba.py     # abrí el juego: es un muñeco
rm -rf game/assets/sprites/jugador     # abrí de nuevo: vuelve el cuadrado azul
```

Es una prueba, no arte del juego.

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
