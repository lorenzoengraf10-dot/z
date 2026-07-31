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
| E | Interactuar: abrir/cerrar puerta · prender fogata o echarle leña · talar · pescar · **picar roca** |
| Q | Comer o beber lo que tengas en la mochila |
| Espacio | Atacar con lo que tengas equipado |
| **I** o Tab | **Inventario** (equipar armas, consumir) — **pausa el juego** |
| B | Modo construcción (barricada / fogata / mesa · clic izq: poner, der: sacar) |
| C | Panel de crafteo |
| M | Mapa mundial |
| F5 / F9 | Guardar / cargar partida |

También hay **botones en pantalla** (arriba a la derecha) para Mapa, Crafteo y Construir, junto al reloj del juego — por si no te acordás las teclas.

### Qué pausa y qué no

- **El inventario pausa** el juego: podés mirar tranquilo qué llevás.
- **El minijuego de la fogata NO pausa**: mientras hacés fricción el mundo sigue y los zombies se te pueden venir encima. Solo te quedás quieto (no podés moverte). Si te apuran, **Escape** cancela.

## Sistemas que ya funcionan

- **Sigilo y ruido** (`player.gd`) — caminar / correr / agacharse tienen distinto **radio de ruido**. Talar y atacar también hacen ruido. Es lo que usan zombies y animales para detectarte.
- **Zombies con IA** (`zombie.gd`) — deambulan, te detectan por **visión** (cono al frente, que se corta con paredes, árboles y barricadas) o por **oído**, te persiguen y te muerden (la mordida infecta). Se los puede matar.
- **Hordas por ruido** (`systems/horde_spawner.gd`) — cuanto más ruido hacés, más "calor" acumulás; al pasar el umbral aparece una horda desde fuera de pantalla. Hay 3 variantes: normal, corredor (rápido y débil) y resistente (lento y duro).
- **Necesidades** (`components/needs_component.gd`) — salud, hambre, sed, energía, temperatura e infección, cada una con su efecto.
- **Recolección** — talar árboles da madera; pescar da pescado y sacia la sed (pero el agua sin hervir infecta un poco).
- **Caza** (`animal.gd`) — los animales huyen si te oyen; cazarlos deja carne en el piso.
- **Minería** — con un **pico** podés picar las rocas y las **vetas de mineral** (las manchas naranjas de la zona rocosa al este) para sacar piedra y metal. Sin pico no se puede. Picar hace **más ruido que talar**.
- **Crafteo** (`systems/crafting.gd` + `data/recipes.json`) — hace falta estar **al lado de una mesa de trabajo**; las recetas de cocina piden además una fogata prendida. Cada receta muestra cuánto tenés de cada material (`Madera 2/3`).
- **Armas** — se craftean (cuchillo, lanza, hacha, bate con clavos, pico) y se **equipan desde el inventario**. Cada una tiene su daño, alcance, ruido y velocidad: el bate mata de un golpe pero se escucha de lejos, el cuchillo es rápido y silencioso. El hacha tala más rápido y el pico habilita minar.
- **Construcción** (`systems/build_system.gd`) — barricadas, fogatas y mesas de trabajo en cualquier lado del mapa; las barricadas frenan zombies y les tapan la visión.
- **Puertas** (`door.gd`) — los edificios tienen puerta. Con **E** la abrís y la cerrás, y **cerrada frena a los zombies y les corta la visión**: encerrarte es una defensa real.
- **Techos** (`systems/roof_system.gd`) — desde afuera ves el techo tapando el edificio; al entrar se oculta y ves el interior.
- **El agua ya no es una pared**: se puede cruzar, pero te deja a menos de la mitad de velocidad. Ojo con meterte al agua escapando de una horda.
- **Ciclo día/noche con amanecer y atardecer** (`systems/day_night.gd`) — el mundo cambia de color según la hora: **noche** azul profundo → **amanecer** rosa cálido (05:00-07:30) → **día** → **atardecer** naranja (18:00-21:00) → noche. De noche además **baja la temperatura**, así que necesitás fuego. Un día completo dura 4 minutos reales (ajustable con `day_seconds`).
  - Los colores salen de la tabla `SKY` arriba del script: para cambiar cómo se ve el atardecer alcanza con tocar esa tabla, sin tocar la lógica.
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
2. **Meterte al agua** y comprobar que te frena bastante (antes era una pared).
3. Ir hasta un árbol, apretar **E** → madera. Después **E** en el agua → pescar y llenar la sed.
4. **I** para abrir el inventario: el juego se tiene que **congelar**. Mirá lo que llevás y cerralo.
5. **B** → aparece el panel de construcción abajo. Poner una **mesa de trabajo** (8 madera).
6. **C** al lado de la mesa → ahora sí se puede craftear. Fabricar un **pico**.
7. Ir a la zona rocosa (este del mapa) y **E** sobre una roca → piedra. Buscar las **vetas naranjas** → metal.
8. Craftear un arma (lanza o hacha), abrir **I** y **equiparla**. Ver que el HUD muestra "En mano" y que pega más fuerte.
9. Entrar a una de las **casas**: desde afuera se ve el techo, al entrar tiene que desaparecer y verse el interior.
10. Pararte en la puerta y apretar **E** para cerrarla. Con un zombie afuera, comprobar que **no puede pasar**.
11. Correr cerca de un zombie (Shift) y ver que te escucha aunque no te vea; después pasar agachado (Ctrl) y ver que no.
12. Correr mucho rato seguido hasta que aparezca una horda.
13. Esperar el **atardecer** (naranja) y la noche: tiene que oscurecer y bajar la temperatura. Después el **amanecer** (rosa).
14. Prender la **fogata que está cerca del spawn** con **E**. Ojo: el juego **no se pausa**, así que fijate que no haya zombies cerca. Ver que ilumina y abriga.
15. Con la fogata prendida, **C** → cocinar la carne (esa receta solo se habilita al lado del fuego).
16. **F5**, cerrar, volver a abrir, **F9** → que vuelva todo como estaba: fogata prendida, puertas, arma equipada.

## Cómo editar el mundo (el mapa de tiles)

El terreno se dibuja con un **TileMap** que se arma por código (`scripts/world.gd`) leyendo un mapa de texto: `data/level_prototype.txt`. Se edita con cualquier editor de texto, sin abrir el editor de tiles.

| Caracter | Tile | ¿Frena / tapa visión? |
|---|---|---|
| `.` | pasto | no |
| `=` | camino | no |
| `~` | agua | **no**: se camina, pero a menos de la mitad de velocidad (acá se pesca) |
| `T` | árbol | sí (da madera + tapa la visión) |
| `#` | pared | sí |
| `,` | piso de madera | no — **define el interior de un edificio** (de acá salen los techos) |
| `D` | puerta | depende: cerrada frena, abierta no |
| `R` | roca | sí (se pica con pico → piedra) |
| `O` | veta de mineral | sí (se pica con pico → metal) |

**Para dibujar un edificio nuevo:** paredes `#` alrededor, piso `,` adentro y al menos una puerta `D` en la pared. El techo y la puerta aparecen solos.

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
