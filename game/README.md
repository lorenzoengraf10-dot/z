# Cuarentena — proyecto Godot

Este es el proyecto del juego (motor Godot 4). El diseño y el roadmap completos están en `../docs/GDD.md`, `../docs/ROADMAP.md` y `../docs/MASTER_PLAN.md`.

## Cómo abrirlo

1. Instalar [Godot 4.x](https://godotengine.org/download) — la versión **normal, NO la .NET** (todo el código es GDScript). Es gratis y no requiere instalación.
2. Abrir Godot → **Import** → elegir `game/project.godot`.
3. Apretar **F5** (o el botón de play) para correr el juego.

## Controles

| Tecla | Acción |
|---|---|
| WASD / Flechas | Mover |
| Shift | Correr (rápido, **mucho ruido**, gasta energía) |
| Ctrl | Agacharse (lento, **casi sin ruido**) |
| E | Interactuar: talar árbol / pescar / **prender fogata** o echarle leña |
| Q | Comer o beber lo que tengas en la mochila |
| Espacio | Atacar (zombies y animales) |
| B | Modo construcción (**1** barricada, **2** fogata · clic izq: poner, der: sacar) |
| C | Panel de crafteo (número para fabricar) |
| M | Mapa mundial |
| F5 / F9 | Guardar / cargar partida |

También hay **botones en pantalla** (arriba a la derecha) para Mapa, Crafteo y Construir, junto al reloj del juego — por si no te acordás las teclas.

## Sistemas que ya funcionan

- **Sigilo y ruido** (`player.gd`) — caminar / correr / agacharse tienen distinto **radio de ruido**. Talar y atacar también hacen ruido. Es lo que usan zombies y animales para detectarte.
- **Zombies con IA** (`zombie.gd`) — deambulan, te detectan por **visión** (cono al frente, que se corta con paredes, árboles y barricadas) o por **oído**, te persiguen y te muerden (la mordida infecta). Se los puede matar.
- **Hordas por ruido** (`systems/horde_spawner.gd`) — cuanto más ruido hacés, más "calor" acumulás; al pasar el umbral aparece una horda desde fuera de pantalla. Hay 3 variantes: normal, corredor (rápido y débil) y resistente (lento y duro).
- **Necesidades** (`components/needs_component.gd`) — salud, hambre, sed, energía, temperatura e infección, cada una con su efecto.
- **Recolección** — talar árboles da madera; pescar da pescado y sacia la sed (pero el agua sin hervir infecta un poco).
- **Caza** (`animal.gd`) — los animales huyen si te oyen; cazarlos deja carne en el piso.
- **Crafteo** (`systems/crafting.gd` + `data/recipes.json`) — tablas, cocinar carne/pescado, vendajes.
- **Construcción** (`systems/build_system.gd`) — barricadas en cualquier lado del mapa; frenan zombies y les tapan la visión.
- **Ciclo día/noche** (`systems/day_night.gd`) — el mundo se oscurece de noche y **baja la temperatura**, así que de noche necesitás fuego. Un día completo dura 4 minutos reales (ajustable).
- **Fogata** (`campfire.gd`) — se construye con 5 madera y arranca **apagada**. Prendida: ilumina, te abriga y habilita las recetas de cocina. Consume leña; se le echa más con E.
- **Minijuego de fricción** (`ui/fire_minigame.gd`) — ver abajo.
- **Guardado/carga** (`systems/save_system.gd`) — JSON en `user://savegame.json`. Guarda también si cada fogata quedó prendida y con cuánta leña.
- **Mapa mundial** (`ui/MapScreen.tscn`) — se lee de `data/world_map.json`.

## Cómo se prende el fuego (el minijuego)

Al apretar **E** frente a una fogata apagada se abre un círculo con una aguja que gira **en sentido horario** y una zona **verde que ocupa el 15%** del círculo:

1. **Timing** — apretá **E** justo cuando la aguja pasa por el verde. Si errás, la aguja se acelera un poco y la zona verde se mueve a otro lado: apurarse sale caro.
2. **Fricción** — si acertaste, **mantené E apretado 3 segundos** mientras se llena el anillo naranja. Si soltás antes, el progreso se enfría y baja solo; si llega a cero, hay que volver a acertar el timing.

Con un **mechero** en la mochila salteás el paso 1 y solo tenés que mantener 1 segundo.

> Decisión de diseño a revisar en el playtest: **el juego se pausa** mientras el minijuego está abierto. Sin pausa sería más tenso (los zombies se te vendrían encima mientras forcejeás), pero también puede ser injusto. Es un cambio de una línea si lo quieren probar al revés.

Todo el arte es **placeholder** a propósito (cuadrados y rombos de colores). La prioridad ahora es validar que el loop es divertido; el arte real entra después respetando `../docs/ARTE_SPEC.md` (tiles 16×16, personajes 32×32).

## Qué probar primero (checklist de playtest)

1. Moverte y ver que las barras del HUD bajan solas (hambre y sed).
2. Ir hasta un árbol, apretar **E** y ver la barra de progreso → conseguir madera.
3. Ir al agua (oeste del mapa o el lago), **E** → pescar y llenar la sed.
4. **Q** para comer el pescado.
5. **B**, **1**, y colocar barricadas con clic; probar que el zombie no las atraviesa.
6. **C** y craftear una tabla.
7. Correr cerca de un zombie (Shift) y ver que te escucha aunque no te vea; después pasar agachado (Ctrl) y ver que no.
8. Correr mucho rato seguido hasta que aparezca una horda.
9. **Espacio** para pelear; cazar un animal y juntar la carne.
10. Esperar a que caiga la noche (mirá el reloj arriba a la derecha) y ver que oscurece y baja la temperatura.
11. Acercarte a la **fogata que ya está puesta cerca del spawn**, apretar **E** y probar el minijuego hasta prenderla. Ver que ilumina y que la temperatura sube al estar cerca.
12. Con la fogata prendida, abrir **C** y cocinar la carne (esa receta solo aparece habilitada al lado del fuego).
13. **B**, **2** para construir tu propia fogata donde quieras.
14. **F5**, cerrar, volver a abrir, **F9** → que vuelva todo como estaba, fogata prendida incluida.
15. Probar los **botones de arriba a la derecha** (Mapa / Crafteo / Construir).

## Cómo editar el mundo (el mapa de tiles)

El terreno se dibuja con un **TileMap** que se arma por código (`scripts/world.gd`) leyendo un mapa de texto: `data/level_prototype.txt`. Se edita con cualquier editor de texto, sin abrir el editor de tiles.

| Caracter | Tile | ¿Frena / tapa visión? |
|---|---|---|
| `.` | pasto | no |
| `=` | camino | no |
| `~` | agua | sí (acá se pesca) |
| `T` | árbol | sí (madera + tapa la visión) |
| `#` | pared | sí |

El mapa se **centra en el origen (0,0)**, que es donde spawnea el jugador — conviene dejar el centro del `.txt` despejado.

## Cómo agregar ítems y recetas

- **Ítems:** `data/items.json` (nombre, si es comestible, cuánta hambre/sed restaura, etc.).
- **Recetas:** `data/recipes.json` (qué cuesta y qué produce).

Los dos se leen solos: agregar cosas **no requiere tocar código**.

## Cómo agregar sonidos

`scripts/systems/audio_manager.gd` busca los archivos por nombre en `assets/audio/` y **no rompe si todavía no existen** (solo avisa por consola). Para que suenen, copiar archivos `.ogg`/`.wav` con estos nombres: `talar`, `pescar`, `golpe`, `comer`, `construir`, `paso`, `fuego_chispa`, `fuego_prender`, y para música `musica_ambiente.ogg`.

## Estructura de carpetas

```
game/
  project.godot
  scenes/          escenas (Main, Player, Zombie, Animal, Pickup, Barricade, UI)
  scripts/
    components/    inventario, necesidades, interacción (se cuelgan del jugador)
    systems/       construcción, crafteo, hordas, guardado, audio
    autoload/      input y base de datos de ítems
  data/            mapa del nivel, ítems, recetas, mapa mundial
  assets/          arte y sonido (tiles placeholder; el resto vacío por ahora)
```

## Nota técnica

El nodo `TileMap` figura como **deprecado en Godot 4.3+** (lo reemplaza `TileMapLayer`), pero sigue funcionando. Se usa a propósito para que el proyecto abra igual en 4.2 y en versiones más nuevas. Si en algún momento migramos, el cambio es solo en `world.gd`.
