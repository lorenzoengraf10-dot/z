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
| E | Interactuar: abrir/cerrar puerta · **revisar contenedor** · prender fogata o echarle leña · talar · pescar · **picar roca** |
| Q | Comer o beber lo que tengas en la mochila |
| **R** | **Vendarte** (corta el sangrado; usa vendaje o, si no tenés, un trapo) |
| Espacio | Atacar con lo que tengas equipado |
| **I** o Tab | **Inventario** (equipar armas, consumir) — **pausa el juego** |
| B | Modo construcción (barricada / fogata / mesa · clic izq: poner, der: sacar) |
| C | Panel de crafteo |
| M | **Mapa** (se destapa caminando) — **pausa el juego** |
| F5 / F9 | Guardar / cargar partida |

También hay **botones en pantalla** (arriba a la derecha) para Mapa, Crafteo y Construir, junto al reloj del juego — por si no te acordás las teclas.

### Qué pausa y qué no

- **El inventario y el mapa pausan** el juego: podés mirar tranquilo qué llevás y dónde estás.
- **El minijuego de la fogata NO pausa**: mientras hacés fricción el mundo sigue y los zombies se te pueden venir encima. Solo te quedás quieto (no podés moverte). Si te apuran, **Escape** cancela.

## El loop de la partida

El juego arrancó como un survival de mapa fijo y ahora se parece bastante a
**Mini DAYZ**: cada partida es una vida, y cuando morís se pierde todo menos lo
que aprendiste.

1. **Aparecés en un punto al azar del mapa.** No hay campamento inicial: te toca
   donde te toca, y lo primero es orientarte con **M**.
2. **Entrás a los edificios a saquear.** Cada casa, galpón o granja tiene
   contenedores (armario, cajón, botiquín, caja militar). Se revisan con **E**,
   tardan un par de segundos, **hacen ruido** y **solo se pueden revisar una vez**.
3. **No te entra todo.** La mochila tiene lugares contados: arrancás con 8 y las
   mochilas que encontrás te suben la capacidad. Elegir qué dejar es parte del juego.
4. **Te van a morder.** Zombies y lobos te hacen **sangrar**, que es lo que más
   rápido te mata. Se corta con **R** (vendaje o trapo).
5. **Te morís.** Aparece el resumen de la partida y, si llegaste a algún hito,
   **desbloqueás un perk** que te queda para siempre.
6. **Volvés a empezar** en otro punto del mapa, un poquito más fuerte.

### Muerte permanente y perks

Lo que se pierde al morir: inventario, posición, todo lo construido.
Lo que **no** se pierde: las estadísticas acumuladas y los perks, que viven en
`user://perfil.json` (aparte del guardado normal, `user://savegame.json`).

Los perks están en `data/perks.json` y se desbloquean por hitos:

| Perk | Qué hace | Se desbloquea con |
|---|---|---|
| Sangre fría | Sangrás un 40% más lento | 3 días sobrevividos |
| Espalda ancha | +3 lugares en la mochila | 7 días sobrevividos |
| Pisada liviana | Hacés 25% menos de ruido | 25 zombies matados |
| Explorador | El mapa arranca con los edificios marcados | 30 lugares saqueados |
| Estómago de hierro | La comida cruda te saca la mitad de salud | 60 zombies matados |
| Veterano | Empezás con cuchillo y 2 vendajes | 15 días sobrevividos |

Agregar un perk es editar el JSON **y** enchufar su efecto en
`_apply_perks()` de `scripts/systems/run_manager.gd` (que es donde se traduce el
id a un número del jugador).

## Sistemas que ya funcionan

- **Sigilo y ruido** (`player.gd`) — caminar / correr / agacharse tienen distinto **radio de ruido**. Talar y atacar también hacen ruido. Es lo que usan zombies y animales para detectarte.
- **Zombies con IA** (`zombie.gd`) — deambulan, te detectan por **visión** (cono al frente, que se corta con paredes, árboles y barricadas) o por **oído**, te persiguen y te muerden (la mordida casi siempre te hace **sangrar**). Se los puede matar.
- **Hordas por ruido** (`systems/horde_spawner.gd`) — cuanto más ruido hacés, más "calor" acumulás; al pasar el umbral aparece una horda desde fuera de pantalla. Hay 3 variantes: normal, corredor (rápido y débil) y resistente (lento y duro).
- **Lobos** (`wolf.gd`) — más rápidos que vos corriendo, **cazan en manada** (el que te ve avisa a los que tenga cerca) y su mordida casi siempre te hace sangrar. Contra ellos correr no alcanza: o los ves venir de lejos, o te encerrás.
- **Contenedores de loot** (`container.gd` + `systems/loot_system.gd` + `data/loot_tables.json`) — se reparten solos al arrancar, pegados a las paredes de cada edificio y nunca tapando la puerta. Qué sale de cada tipo se edita en el JSON, sin tocar código.
- **Armas de fuego** — pistola, escopeta y rifle gastan **munición** y hacen muchísimo ruido: disparar te trae una horda casi seguro. El HUD te muestra cuántas balas te quedan.
- **Sangrado** — necesidad propia, con barra que parpadea en el HUD. No para solo (baja muy de a poco): hay que vendarse con **R**.
- **Mochila con capacidad** (`components/inventory_component.gd`) — cada unidad ocupa un lugar. El HUD muestra `Mochila 6/8` y avisa cuando algo no entró.
- **Necesidades** (`components/needs_component.gd`) — salud, hambre, sed, energía, temperatura y **sangrado**, cada una con su efecto.
  - *Nota de diseño:* había también una barra de **infección** y se sacó. Hacía lo mismo que el sangrado (drenar salud despacio después de una mordida) pero más lento, y con las dos juntas eran 7 barras que nadie miraba. Lo que hacía quedó repartido: las mordidas sangran más (60% de probabilidad en vez de 45%), y la comida cruda y el agua sin hervir **pegan directo a la salud**.
- **Recolección** — talar árboles da madera; pescar da pescado y sacia la sed (pero el agua sin hervir te saca 6 de salud: hervirla sigue valiendo la pena).
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
- **Guardado/carga** (`systems/save_system.gd`) — JSON en `user://savegame.json`. Guarda necesidades, mochila, tiles modificados, construcciones, puertas, qué contenedores ya revisaste, la niebla del mapa y si cada fogata quedó prendida y con cuánta leña. **El perfil (perks) va aparte**, en `user://perfil.json`.
- **Mapa real con niebla** (`scripts/map_screen.gd`) — dibuja el terreno tal como está (si talaste un árbol, el mapa lo refleja) y **arranca tapado**: se destapa con lo que caminás. El punto verde sos vos; las fogatas prendidas que hayas visto salen en naranja. El perk *Explorador* te marca los edificios desde el arranque. La niebla se guarda con la partida.
- **Partidas con muerte permanente** (`systems/run_manager.gd`) — spawn al azar, estadísticas de la partida, resumen al morir y perks que quedan entre partidas.

## Cómo se prende el fuego (el minijuego)

Al apretar **E** frente a una fogata apagada se abre un círculo con una aguja que gira **en sentido horario** y una zona **verde que ocupa el 15%** del círculo:

1. **Timing** — apretá **E** justo cuando la aguja pasa por el verde. Si errás, la aguja se acelera un poco y la zona verde se mueve a otro lado: apurarse sale caro.
2. **Fricción** — si acertaste, **mantené E apretado 3 segundos** mientras se llena el anillo naranja. Si soltás antes, el progreso se enfría y baja solo; si llega a cero, hay que volver a acertar el timing.

Con un **mechero** en la mochila salteás el paso 1 y solo tenés que mantener 1 segundo.

> Decisión de diseño a revisar en el playtest: **el juego se pausa** mientras el minijuego está abierto. Sin pausa sería más tenso (los zombies se te vendrían encima mientras forcejeás), pero también puede ser injusto. Es un cambio de una línea si lo quieren probar al revés.

Todo el arte es **placeholder** a propósito (cuadrados y rombos de colores). La prioridad ahora es validar que el loop es divertido; el arte real entra después respetando `../docs/ARTE_SPEC.md` (tiles 16×16, personajes 32×32).

## Qué probar primero (checklist de playtest)

**Lo primero de todo:** arrancá el juego dos o tres veces seguidas y fijate que
**aparecés en un lugar distinto cada vez**. Si siempre caés en el mismo punto,
algo falló en `run_manager.gd`.

1. Abrir el **mapa (M)**: el juego se tiene que congelar y tenés que ver un
   círculo destapado alrededor tuyo, con el punto verde en el medio. Caminar un
   rato, volver a abrirlo y ver que el área destapada creció.
2. Moverte y ver que las barras del HUD bajan solas (hambre y sed).
3. **Meterte al agua** y comprobar que te frena bastante.
4. Buscar un **edificio**: desde afuera se ve el techo, al entrar tiene que
   desaparecer y verse el interior.
5. Adentro, pararte al lado de un **contenedor** y apretar **E**: barra de
   progreso, y al terminar te dice qué encontraste. Volver a apretar **E** sobre
   el mismo: tiene que decir *"Ya revisaste eso"*.
6. Llenar la mochila hasta que el HUD diga `8/8` y probar levantar algo más:
   tiene que avisar que no entra. Buscar una **mochila** en el loot y ver que
   sube la capacidad.
7. Dejar que un zombie te muerda unas cuantas veces hasta que arranque el
   **sangrado**: la barra roja tiene que aparecer y **parpadear**, y la salud
   bajar sostenido. Apretar **R** para vendarte.
8. Ir hasta un árbol, apretar **E** → madera. Después **E** en el agua → pescar:
   fijate que **la salud baja un poco** (tomaste agua sucia). Comer el pescado
   crudo desde **I** también tiene que sacarte salud; cocinarlo, no.
9. **I** para abrir el inventario: el juego se tiene que **congelar**.
10. **B** → poner una **mesa de trabajo** (8 madera). **C** al lado → craftear un **pico**.
11. Picar una **roca** y una **veta naranja** → piedra y metal.
12. Craftear un arma, equiparla desde **I** y ver que el HUD muestra "En mano".
13. Si encontrás un **arma de fuego** con munición: disparar y ver que (a) baja
    el contador de balas del HUD, (b) te aparece una horda enseguida. Vaciar la
    munición y ver que avisa "Sin ...".
14. Cerrar una **puerta** con **E** teniendo un zombie afuera: no tiene que pasar.
15. Encontrar un **lobo**: tiene que correr más rápido que vos y, si hay otros
    cerca, venirte todos juntos.
16. Correr mucho rato seguido hasta que aparezca una horda.
17. Esperar el **atardecer** y la noche, y después el **amanecer**.
18. Prender la **fogata** con **E** (el juego **no** se pausa). Con la fogata
    prendida, **C** → cocinar la carne.
19. **F5**, cerrar, volver a abrir, **F9** → que vuelva todo: fogata prendida,
    puertas, arma equipada, contenedores ya revisados y la niebla del mapa.
20. **Dejarte morir.** Tiene que aparecer la pantalla de resumen con los días,
    los zombies, los lobos y los lugares saqueados. Apretar *Empezar de nuevo* y
    ver que arranca otra partida **en otro lugar del mapa**.
21. Sobrevivir 3 días para desbloquear el primer perk. Al morir, el resumen tiene
    que anunciarlo en amarillo, y la partida siguiente ya tiene que tenerlo puesto.

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
  scenes/          escenas (Main, Player, Zombie, Wolf, Animal, Container, UI)
  scripts/
    components/    inventario, necesidades, interacción (se cuelgan del jugador)
    systems/       construcción, crafteo, hordas, loot, partidas, guardado, audio
    autoload/      input y base de datos de ítems
  data/            mapa del nivel, ítems, recetas, tablas de loot, perks
  assets/          arte y sonido (tiles placeholder; el resto vacío por ahora)
```

## Nota técnica

El nodo `TileMap` figura como **deprecado en Godot 4.3+** (lo reemplaza `TileMapLayer`), pero sigue funcionando. Se usa a propósito para que el proyecto abra igual en 4.2 y en versiones más nuevas. Si en algún momento migramos, el cambio es solo en `world.gd`.

## Antes de subir cambios

En la máquina de desarrollo hay verificadores estáticos que revisan lo que se
puede revisar **sin abrir Godot** (rutas rotas, tipos que GDScript rechaza al
compilar, mapas mal armados):

```bash
python3 tools/verificadores/run_all.py
```

No reemplazan probar el juego, pero evitan subir algo que ni siquiera abre.
