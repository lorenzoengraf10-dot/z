# Cuarentena — proyecto Godot

Este es el proyecto del juego (motor Godot 4). El diseño y el roadmap completos están en `../docs/GDD.md`, `../docs/ROADMAP.md` y `../docs/MASTER_PLAN.md`.

## Cómo abrirlo

1. Instalar [Godot 4.x](https://godotengine.org/download) — la versión **normal, NO la .NET** (todo el código es GDScript). Es gratis y no requiere instalación.
2. Abrir Godot → **Import** → elegir `game/project.godot`.
3. Apretar **F5** (o el botón de play) para correr el juego.

## Cómo bajar los cambios nuevos (sin rehacer nada)

**Bajar el ZIP de vuelta cada vez no hace falta y encima es peor**: te da una
carpeta nueva, tenés que volver a importar el proyecto en Godot, y si vos
tocaste algo se pierde.

La forma correcta es tener **una sola carpeta** que se actualiza sola.

### Con GitHub Desktop (lo más simple, y es lo que recomiendo)

Se hace **una vez**:

1. Instalar [GitHub Desktop](https://desktop.github.com) (gratis, Windows y Mac).
2. **File → Clone repository** → pestaña **URL** → pegar la dirección del repo.
3. Elegir dónde guardarlo. Esa carpeta pasa a ser **el** proyecto: importala en
   Godot desde ahí y no toques más la vieja.

Y de ahí en adelante, cada vez que suba algo:

- Abrir GitHub Desktop → botón **Fetch origin** → si hay algo nuevo se
  convierte en **Pull origin** → clic. Listo, tardá 2 segundos.
- Volvés a Godot y apretás F5. **Ya está actualizado**, no hay que reimportar
  nada.

### Con la consola (si preferís)

```bash
cd carpeta-del-proyecto
git pull origin main
```

### Dos cosas que conviene saber

- **No se pierden las partidas guardadas.** Godot las guarda **fuera** de la
  carpeta del proyecto (en `%APPDATA%\Godot\app_userdata\` en Windows), así que
  actualizar no te borra ni la partida ni los perks que desbloqueaste.
- **Cerrá Godot antes de actualizar** y volvé a abrirlo después. No es
  obligatorio, pero si Godot está abierto mientras cambian los archivos a veces
  se marea y hay que reiniciarlo igual.
- Si tocaste archivos vos y el `pull` se queja, **no borres nada**: avisá y lo
  vemos. Casi siempre es un archivo que los dos cambiamos y se arregla en un
  minuto.

Para el **pixel art** es el mismo camino al revés: ustedes ponen los PNG en la
carpeta, GitHub Desktop los muestra como cambios, escriben una línea de qué
hicieron y **Push origin**. Ver `../docs/ARTE_SPEC.md`.

## Controles

El juego es **para PC**: te movés con el teclado y **apuntás con el mouse**.
Mirás siempre hacia donde está el cursor, sin importar para dónde camines.

| Tecla | Acción |
|---|---|
| WASD / Flechas | Mover |
| **Mouse** | **Apuntar** (el jugador mira siempre al cursor) |
| **Clic izq** o Espacio | Atacar o disparar con lo que tengas equipado |
| Shift | Correr (rápido, **mucho ruido**, gasta energía) |
| Ctrl | Agacharse (lento, **casi sin ruido**) |
| E | Interactuar: abrir/cerrar puerta · revisar contenedor · guardar/sacar de un cofre o armario · prender fogata o echarle leña · talar · picar roca o veta |
| **T** | **Tomar agua** del lago (llena el recipiente si lo tenés, si no toma directo y sucia) |
| E (parado en el agua) | **Pescar** con caña — abre el minijuego de burbujas |
| **F** | Cambiar de mano: pasar el arma **en mano** entre cuerpo a cuerpo y de fuego |
| Q | Comer o beber lo que tengas en la mochila |
| R | Curarte: si sangrás te venda (vendaje o trapo); si no, usa un **botiquín** |
| I o Tab | Inventario (equipar armas, consumir, **tirar objetos**) — **pausa el juego** |
| B | Modo construcción (muros / fogata / mesa / cofre · clic izq: poner **o reparar**, der: sacar) |
| C | Panel de crafteo |
| M | Mapa (se destapa caminando) — **pausa el juego** |
| **H** o F1 | **Ayuda con todos los controles** — **pausa el juego** |
| F5 / F9 | Guardar / cargar partida |

No hace falta acordarse de nada: **H** abre la lista completa dentro del juego,
y hay botones en pantalla (arriba a la derecha) para Mapa, Crafteo, Construir y
la ayuda, al lado del reloj.

### No hace falta adivinar qué hace la E

Cuando te acercás a algo usable aparece un **cartelito flotante** sobre el
objeto: *"E — Revisar armario"*, *"E — Abrir puerta"*, *"E — Talar árbol"*, con
un recuadro marcando exactamente qué vas a usar. Si te falta la herramienta, te
lo dice ahí mismo (*"Necesitás un pico"*).

### Qué pausa y qué no

- **El inventario, el mapa y la ayuda pausan** el juego.
- **El minijuego de la fogata NO pausa**: mientras hacés fricción el mundo sigue y los zombies se te pueden venir encima. Solo te quedás quieto (no podés moverte). Si te apuran, **Escape** cancela.

## Cómo leer la pantalla

- **Arriba a la izquierda**: las necesidades, con ícono, barra y porcentaje. La
  que está por debajo del 25% se resalta y el resto queda apagada, así de un
  vistazo ves qué te está matando. El **sangrado** parpadea cuando está activo.
- **Debajo**: el estado de **sigilo** (`○ oculto` / `◒ te escucharon` / `◉ TE
  VEN`), la mochila con su capacidad y el arma **en mano** (cuerpo a cuerpo o de
  fuego, se cambia con **F**) con su munición si es de fuego. Lo que no está en
  mano pero tenés equipado queda **guardado** en sus propios casilleros — ni el
  arma ni la munición ocupan lugar de la mochila.
- **Arriba a la derecha**: el día, la hora, la fase (☀ 🌇 🌙 🌅) y los botones.
- **Abajo a la derecha**: el **minimapa**, con la misma niebla que el mapa
  grande. Los enemigos aparecen ahí **solo si ya te detectaron**.
- **Arriba de tu cabeza**: una **barra de ruido** chiquita que muestra cuánto te
  escuchan, tomando **correr = 100%**: agachado 25%, caminando 50%, talando o
  atacando 75%. Va de verde a amarillo a rojo, desaparece cuando estás en
  silencio y **parpadea llena** si un disparo se pasa de la escala.
- **Sobre cada enemigo**: nada si está tranquilo, **`?`** amarillo si te escuchó
  y va hacia tu última posición, **`!`** rojo si te está viendo.

## El loop de la partida

El juego arrancó como un survival de mapa fijo y ahora se parece bastante a
**Mini DAYZ**: cada partida es una vida, y cuando morís se pierde todo menos lo
que aprendiste.

1. **Aparecés en un punto al azar del mapa.** No hay campamento inicial: te toca
   donde te toca, y lo primero es orientarte con **M**.
2. **Entrás a los edificios a saquear.** Cada casa, galpón o granja tiene
   contenedores (armario, cajón, botiquín, caja militar). Se revisan con **E**,
   tardan un par de segundos, **hacen ruido** y **solo se pueden revisar una vez**.
3. **No te entra todo.** La mochila tiene lugares contados: arrancás con 12 y las
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

- **Sigilo y ruido** (`player.gd`) — todo se mide contra **correr = 100%**, que es
  el tope de la escala:

  | Qué hacés | Ruido | Dónde se toca |
  |---|---|---|
  | Agachado | 25% | `player.gd` · `crouch_noise` |
  | Caminando | 50% | `player.gd` · `walk_noise` |
  | Talar / atacar | 75% | `interactor.gd` · `chop_noise`, `player.gd` · `attack_noise` |
  | Correr / picar roca | 100% | `player.gd` · `run_noise`, `interactor.gd` · `mine_noise` |

  Las **armas de fuego** tienen su propio ruido en `data/items.json` y se pasan de
  la escala a propósito. Es lo que usan zombies y animales para detectarte.
- **Zombies con IA** (`zombie.gd`) — deambulan, te detectan por **visión** (cono al frente, que se corta con paredes, árboles y barricadas) o por **oído**, te persiguen y te muerden (la mordida casi siempre te hace **sangrar**). Se los puede matar.
- **Las paredes tapan el ruido** (`zombie.gd`, `wolf.gd` · `muffle_through_walls`) — adentro de una casa te escuchan mucho menos (35%). Es lo que hace que meterse sirva de algo: antes te oían igual a través de la pared. *No* es un bloqueo total a propósito — si adentro fueras invisible y sordo para ellos, nadie golpearía nunca una puerta y las puertas rompibles no tendrían sentido. Quedate quieto y estás a salvo; peleá o corré adentro y te encuentran igual.
- **Entran por la puerta** (`zombie.gd`/`wolf.gd` · `_chase_waypoint()`) — si te metés en una casa, el que te persigue **rodea hasta la puerta** en vez de quedarse empujando la pared de afuera. Reusa lo que `roof_system.gd` ya sabe (qué celda es de qué habitación y dónde están sus puertas), sin necesidad de un pathfinding aparte.
- **Hordas por ruido** (`systems/horde_spawner.gd`) — cuanto más ruido hacés, más "calor" acumulás; al pasar el umbral aparece una horda desde fuera de pantalla. Hay 3 variantes: normal, corredor (rápido y débil) y resistente (lento y duro).
- **Paredes que frenan** (`world.gd`) — paredes de ladrillo, rocas y vetas colisionan de verdad y cortan la línea de vista de los zombies. Encerrarte en una casa con la puerta cerrada es una defensa real. El mapa además está cerrado por **cuatro paredes invisibles** en el borde, así que no te podés ir al vacío.
- **Árboles atravesables** (`world.gd`) — se pueden cruzar (a menos velocidad,
  igual que el agua) pero **siguen tapando la visión de los zombies**: usan una
  segunda capa de física que solo mira el `VisionRay`, no los cuerpos. Meterte
  detrás de uno sigue siendo un escondite real.
- **El terreno frena a todos por igual** (`world.gd` · `SPEED`) — el agua (0.45)
  y el monte (0.55) te frenan a vos, **y también a zombies, lobos y animales**.
  Es lo que hace que meterse entre los árboles o cruzar el lago escapando sirva
  de algo: si frenara solo al jugador, el bosque sería una trampa mortal en vez
  de un escondite. Cada script que se mueve multiplica su velocidad por
  `world.speed_at()`, y hay un verificador que lo controla (`check_project.py`).
- **Sigilo visible** (`player.gd`, `components/hunter_display.gd`) — la barra de ruido arriba de la cabeza, el `?`/`!` sobre cada enemigo y el chip del HUD. Antes el sistema de ruido existía pero era invisible y no se podía jugar con él.
- **Feedback de combate** (`systems/floating_text.gd`, `ui/game_camera.gd`) — números de daño, parpadeo y retroceso del enemigo al golpearlo, barra de vida sobre el que estás peleando, y sacudida de cámara cuando te pegan a vos.
- **Objetivos del arranque** (`systems/objectives.gd`) — cuatro cosas que te empujan a descubrir los sistemas (saquear, comer, prender fuego, sobrevivir la noche). Se tachan solas y después desaparecen.
- **Minimapa** (`ui/minimap.gd`) — comparte la niebla con el mapa grande.
- **Lobos** (`wolf.gd`) — más rápidos que vos corriendo, **cazan en manada** (el que te ve avisa a los que tenga cerca) y su mordida casi siempre te hace sangrar. Contra ellos correr no alcanza: o los ves venir de lejos, o te encerrás.
- **Contenedores de loot** (`container.gd` + `systems/loot_system.gd` + `data/loot_tables.json`) — se reparten solos al arrancar, pegados a las paredes de cada edificio y nunca tapando la puerta. Qué sale de cada tipo se edita en el JSON, sin tocar código.
- **Armas de fuego** — pistola, escopeta y rifle gastan **munición** y hacen muchísimo ruido: disparar te trae una horda casi seguro. El HUD te muestra cuántas balas te quedan.
- **Sangrado** — necesidad propia, con barra que parpadea en el HUD. No para solo (baja muy de a poco): hay que vendarse con **R**.
- **Botiquín** — cura 10 y es lo **único que cura sin estar sangrando**: el vendaje, que cura más, solo se puede usar con una hemorragia abierta. Sale poco frecuente de los botiquines del mapa y se craftea con 5 trapo + 1 vendaje + 2 metal. Se usa con **R** cuando no estás sangrando.
- **Cartel de sigilo** (`hud.gd`) — arriba y al centro, grande. Aparece solo cuando te escucharon o te vieron; si no hay cartel, estás oculto. Antes era una línea chica perdida en la esquina, que es donde menos se mira justo la información más urgente del juego.
- **Mochila con capacidad** (`components/inventory_component.gd`) — cada unidad ocupa un lugar, ahora **12** lugares en vez de 8. El HUD muestra `Mochila 6/12` y avisa cuando algo no entró. Desde **I** también se puede **tirar** cualquier objeto (aparece en el piso como un `Pickup`), incluso con la mochila llena.
- **Armas y munición aparte** (`components/arms_component.gd`) — 3 casilleros propios (cuerpo a cuerpo, arma de fuego, munición de esa arma) que **no gastan lugar de la mochila**. Lo que no está equipado sí ocupa mochila. **F** cambia cuál de las dos armas equipadas es la que "pega" (`arms.switch_hand()`); munición de un arma distinta a la equipada no entra en el casillero, va a la mochila común. Al **equipar** un arma de fuego se lleva al casillero la munición de esa arma que ya tuvieras suelta en la mochila (encontrar las balas antes que el arma es el caso normal), y al **guardarla** las devuelve.
- **Almacenamiento** (`container.gd`, `ui/StorageScreen.tscn`) — se puede construir un **cofre** (modo **B**) y, una vez que un **armario** ya fue saqueado, se puede reutilizar para guardar cosas: **E** abre una pantalla de poner/sacar en vez de perderlo para siempre.
- **Necesidades** (`components/needs_component.gd`) — salud, hambre, sed, energía, temperatura y **sangrado**, cada una con su efecto.
  - *Nota de diseño:* había también una barra de **infección** y se sacó. Hacía lo mismo que el sangrado (drenar salud despacio después de una mordida) pero más lento, y con las dos juntas eran 7 barras que nadie miraba. Lo que hacía quedó repartido: las mordidas sangran más (60% de probabilidad en vez de 45%), y la comida cruda y el agua sin hervir **pegan directo a la salud**.
- **Nada desaparece por tener la mochila llena** — es la queja más fuerte del
  testeo y hay dos respuestas distintas según el caso. Lo que **puede esperar**
  (un árbol, una roca, una veta, un pickup del suelo, el botín de un mueble) no
  se entrega y **se queda donde estaba**, así volvés cuando hagas lugar. Lo que
  **ya se cobró** y no puede devolver el vuelto (lo que crafteás, el refund de
  desarmar algo, lo que te regala un perk, un arma que guardás) cae **al piso a
  tus pies** vía `player.give_or_drop()`. Hay un verificador que salta si algún
  `inventory.add()` vuelve a tirar su resultado (`check_types.py`).
- **Recolección** — talar un árbol, picar una roca o picar una veta abren el
  **minijuego de 3 clicks** (`ui/click_minigame.gd`); acertar los 3 da madera,
  piedra o metal. Si no te entra en la mochila, **el árbol/roca/veta no se
  toca**: sigue ahí para cuando hagas lugar. **Tomar agua** (**T**) y **pescar** (**E** parado en el agua)
  son dos acciones separadas: tomar agua directo del lago te saca 6 de salud
  (es agua sucia) salvo que la lleves en un **recipiente** y la **hiervas** en
  la fogata (`agua_sucia` + madera → `agua`); pescar **no** sacia la sed, solo
  te da pescado, y usa el **minijuego de burbujas** con **caña** — no se puede
  pescar si hay un zombi que te vio o a menos de 15 celdas.
- **Caza** (`animal.gd`) — los animales huyen si te oyen; cazarlos deja carne en el piso.
- **Minería** — con un **pico** podés picar las rocas y las **vetas de mineral** (las manchas naranjas de la zona rocosa al este) para sacar piedra y metal. Sin pico no se puede. Picar hace **más ruido que talar**.
- **Crafteo** (`systems/crafting.gd` + `data/recipes.json`) — hace falta estar **al lado de una mesa de trabajo**; las recetas de cocina piden además una fogata prendida. Cada receta muestra cuánto tenés de cada material (`Madera 2/3`).
- **Armas** — se craftean (cuchillo, lanza, hacha, bate con clavos, pico) y se **equipan desde el inventario**. Cada una tiene su daño, alcance, ruido y velocidad: el bate mata de un golpe pero se escucha de lejos, el cuchillo es rápido y silencioso. El hacha tala más rápido y el pico habilita minar.
- **Construcción** (`systems/build_system.gd`) — muros de madera, piedra y metal, fogatas, mesas de trabajo y cofres. Cada cosa cuesta sus propios materiales (`{"metal": 2, "tabla": 1}`, mismo formato que las recetas). Los muros frenan zombies y les tapan la visión.
- **Todo lo construido se rompe** (`structure.gd`) — muros y puertas tienen vida, y **un zombi que te persigue le pega a lo que se interponga** en vez de quedarse empujando contra la pared. Un zombi que solo deambula no rompe nada: si no, el mapa se iría demoliendo solo.

  | Qué | Vida | Golpes (zombi normal) | Golpes (resistente) |
  |---|---|---|---|
  | Muro de madera | 120 | 15 | 8 |
  | Muro de piedra | 240 | 30 | 15 |
  | Muro de metal | 400 | 50 | 25 |
  | Puerta | 160 | 20 | 10 |

  Como los zombies pegan una vez por segundo, esa columna son **segundos**. Ojo:
  son contra **un** zombi — con tres encima de la misma puerta, es un tercio.
  Los **lobos no** rompen nada: son animales.
- **Reparar** — en modo construcción (**B**), clic izquierdo sobre algo dañado lo arregla gastando su material (una unidad por clic). Sirve también para las **puertas de las casas del mapa**, que es lo que te permite adoptar una casa como base.
- **En las casas del mapa no se puede construir** — ni muro, ni mesa, ni fogata, ni cofre. Es lo que hace que valga la pena armarse un refugio propio en vez de ocupar una casa y equiparla entera. Los armarios ya saqueados **sí** se siguen pudiendo usar como guardado.
- **Puertas** (`door.gd`) — los edificios tienen puerta. Con **E** la abrís y la cerrás, y **cerrada frena a los zombies y les corta la visión**. Pero **se rompen**: al quedarse sin vida quedan abiertas para siempre (el marco sigue ahí) y ya no se pueden cerrar. Encerrarse sigue siendo una defensa, pero ahora es una que hay que mantener.
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

El andamiaje de este minijuego (`is_open()`, `_set_player_blocked()`, cancelar
con Escape, no pausar el árbol) se sacó a una base común,
**`ui/minigame_base.gd`**, que también usan el **minijuego de 3 clicks** (talar
/ picar) y el **minijuego de pesca** (burbujas). Si hay que tocar ese
comportamiento compartido, se toca ahí una sola vez.

## Qué probar primero (checklist de playtest)

**Lo primero de todo, que es lo que estaba roto:**

- **Caminá contra una pared de ladrillo.** Tiene que frenarte. Lo mismo contra una
  **roca**. Si las atravesás, mirá el panel *Salida*: tendría que haber un error
  de `world.gd` diciendo qué tiles quedaron sin colisión.
- **Caminá contra un árbol.** Al revés que las paredes: **te tiene que dejar
  pasar**, pero mucho más lento. Metete detrás de uno con un zombi cerca que
  todavía no te vio: no te tiene que descubrir (el árbol le sigue tapando la
  visión aunque vos lo puedas cruzar).
- **Mirá una casa desde afuera.** Tenés que ver dónde está la puerta (es lo único
  del edificio que el techo no tapa) y si está abierta o cerrada. Abrila con **E**
  parado afuera.
- **Andá hasta el borde del mapa**, sobre todo nadando por la costa del oeste. No
  te tenés que poder ir.
- Arrancá el juego dos o tres veces seguidas y fijate que **aparecés en un lugar
  distinto cada vez**.

Después, lo de siempre:

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
6. Llenar la mochila hasta que el HUD diga `12/12` y probar levantar algo más:
   tiene que avisar que no entra. Abrir **I** y **tirar** un objeto: tiene que
   aparecer en el piso y liberar un lugar. Buscar una **mochila** en el loot y
   ver que sube la capacidad.
7. Dejar que un zombie te muerda unas cuantas veces hasta que arranque el
   **sangrado**: la barra roja tiene que aparecer y **parpadear**, y la salud
   bajar sostenido. Apretar **R** para vendarte.
8. Ir hasta un árbol y apretar **E**: se abre el **minijuego de 3 clicks** (aro
   que se achica, 3 vueltas); acertar las 3 da madera. Después pará en el borde
   del agua: **T** toma agua directo (te baja un poco la salud, es agua sucia)
   y **E** abre el **minijuego de pesca** (burbujas) — son dos acciones
   distintas, probá las dos por separado. Comer el pescado crudo desde **I**
   también tiene que sacarte salud; cocinarlo, no.
   - Con un **zombi que te vio, o a menos de 15 celdas**, probá **E** en el agua:
     tiene que **negarse a pescar**.
   - Craftear un **recipiente** y usar **T** con él: en vez de tomar agua sucia
     directo, la guarda como `agua_sucia`. Prender la fogata y craftear
     **"Hervir agua"** (gasta `agua_sucia` + madera) → da `agua` limpia, sin
     daño al tomarla.
9. **I** para abrir el inventario: el juego se tiene que **congelar**.
10. **B** → poner una **mesa de trabajo** (ahora **6 madera**, antes 8). **C** al lado → craftear un **pico**.
11. Picar una **roca** y una **veta naranja** con el minijuego de 3 clicks → piedra y metal.
12. Craftear un arma cuerpo a cuerpo **y** una de fuego, equipar las dos desde
    **I**: tienen que ocupar sus propios casilleros y **no gastar mochila**.
    Apretar **F** y ver que el HUD cambia cuál está "en mano". Craftear
    munición o encontrarla y comprobar que tampoco ocupa mochila mientras el
    arma esté equipada.
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

**De la interfaz y el feel:**

22. Mové el mouse en círculo: el jugador tiene que **mirar siempre al cursor**.
    Atacá con **clic izquierdo**. Ojo con esto: si el clic no ataca, es que algún
    `Control` del HUD se lo está comiendo (tiene que ir con `MOUSE_FILTER_IGNORE`,
    ver `hud.gd`).
23. Pegale a un zombi: tiene que salir el **número de daño** en amarillo,
    parpadear en blanco, **retroceder** y aparecerle la barra de vida arriba.
24. Dejá que te muerda: número **rojo**, parpadeo rojo tuyo y **sacudida de cámara**.
25. Corré y fijate cómo **se llena la barra de ruido** arriba de tu cabeza (correr
    la llena entera y la pone roja); caminando queda a la mitad y **agachado en un
    cuarto**. Acercate a un zombi caminando hasta que le salga el **`?`**, y
    después ponete en su campo de visión hasta que sea **`!`**. El chip del HUD
    tiene que ir cambiando junto con eso.
26. Apretá **H**: se abre la ayuda y el juego se pausa.
27. Mirá el **minimapa** de abajo a la derecha: se tiene que ir destapando igual
    que el mapa grande.
28. Encerrate en una casa con la puerta cerrada y un zombi afuera: **no te tiene
    que ver, y tampoco alcanzarte a través de la puerta**. Pero sí te la va a
    **romper** si te está persiguiendo (ver el ítem 48): esconderse ya no es
    gratis, hay que mantener la puerta. Si el zombi te muerde con la puerta
    cerrada y entera, eso sí es un bug.

**Del mapa (esto se rompió una vez y no se notó hasta jugar):**

29. Mirá el panel **Salida** apenas arranca: tiene que decir
    `world.gd: 9 de 9 tiles con atlas OK`. Si nombra alguno, ese tile quedó
    transparente y en pantalla no se va a ver.
30. Parado en el pasto, tenés que **distinguir** el pasto del camino de tierra, los
    árboles, el agua y las rocas. Si es todo un verde plano, el atlas quedó vacío.
31. Metete adentro de una casa: se tienen que ver las **paredes de ladrillo**
    (rojizas) y el **piso de madera**, distintos entre sí y distintos del pasto de
    afuera.

**De lo nuevo de este lote (lo que pidió el testeo externo):**

32. **Construí un cofre** (**B**) y guardale algo con **E**: tiene que abrir una
    pantalla de poner/sacar, no la de saqueo de un solo uso. Volvé más tarde y
    verificá que lo que guardaste sigue ahí (probar también con **F5/F9**).
33. Saqueá un **armario** hasta vaciarlo y volvé a apretar **E**: en vez de
    "Ya revisaste eso" tiene que abrir la misma pantalla de guardar/sacar.
34. Dejá que la **sed** baje sola y cronometrá más o menos: tendría que tardar
    del orden de **4 minutos** en vaciarse del todo (antes era bastante más
    rápido), y el daño por deshidratación se nota más suave que antes.
35. En el minijuego de **3 clicks** (talar/picar), fijate que el aro que hay que
    acertar **se va achicando** en cada una de las 3 vueltas (la primera es la
    más fácil, la última la más difícil).
36. En el minijuego de **pesca**, fijate que las zonas de burbuja aparecen y
    hay que clickearlas rápido; si te la tomás con calma, tienen que
    desaparecer y aparecer otra en otro lado.
37. **Andá por el mapa entero y fijate que ninguna casa se pisa con otra** (las
    paredes de dos edificios no se tienen que superponer en ningún lado).
38. Metete al agua y probá **T** (tomar) y **E** (pescar) por separado sin tener
    caña: pescar tiene que avisar que te falta la caña; tomar agua tiene que
    funcionar igual.

**Lo que se arregló después (repaso del lote — mirar esto con atención):**

39. **Llená la mochila hasta `12/12` y talá un árbol.** Tiene que decir *"No te
    entra madera: la mochila está llena"* y **el árbol tiene que seguir ahí**.
    Antes el árbol desaparecía del mapa para siempre, no recibías nada, y el
    cartel igual anunciaba "+3 madera". Repetir con una **roca**, una **veta**
    y **pescando**.
40. **Encontrá balas antes que el arma.** Guardá balas 9mm sin tener pistola
    (van a la mochila), después conseguí la **pistola** y equipala: las balas
    tienen que **pasar solas al casillero** y el HUD mostrarlas. Antes te decía
    "Sin balas 9mm" con las balas en la espalda. Guardá el arma y fijate que
    vuelven a la mochila.
41. **Corré al monte con un lobo atrás.** Ahora al lobo **también** lo frena el
    monte, así que meterse entre los árboles tiene que servir para algo. Lo
    mismo cruzando el **agua**. Si el lobo te alcanza igual de rápido adentro
    del monte que en el pasto, algo se rompió.
42. **Errale a propósito muchas veces seguidas** en el minijuego de 3 clicks: la
    aguja acelera, pero tiene **techo** — nunca puede volverse imposible.
43. Tomá agua del lago **con** y **sin** recipiente: sin recipiente tiene que
    saciarte lo mismo que tomarte un `agua_sucia` guardada (ni más ni menos),
    así craftear el recipiente nunca te deja peor.
44. Mirá un **armario ya saqueado**: no tiene que verse gris "muerto" como
    antes, porque ahora sirve de guardado. Si le guardaste algo adentro, se
    tiene que notar de afuera sin abrirlo.
45. **Desarmá una barricada con la mochila llena** (**B** → clic derecho): la
    madera del reembolso tiene que **caer al piso**, no evaporarse. Lo mismo al
    craftear algo sin lugar.
46. **Poné el cursor justo encima del panel de vida** (arriba a la izquierda) y
    apretá **clic izquierdo**: tiene que **atacar igual**. Es el ítem 22 otra
    vez, pero mirándolo a propósito: el HUD ya se comió el clic dos veces, y la
    segunda fue por ponerle tooltips a las barras. Si algún día no ataca, mirá
    los `mouse_filter` de `hud.gd` (hay un verificador que lo controla).
47. Buscá un **zombi resistente** (el lento, duro y que pega fuerte): tiene que
    verse con **su propio dibujo**, sin un tinte violeta encima. Si se ve
    violeta, el spawner no está reconociendo que la variante tiene arte propio.

**De la construcción rompible (Fase 1 del plan de fortalezas):**

48. **Encerrate en una casa con un zombi persiguiéndote.** Tiene que **pegarle a
    la puerta** —número de daño, barra de vida sobre ella— y tirarla en unos 20
    segundos. Al romperse queda abierta para siempre y ya no se puede cerrar.
49. **Un zombi que solo deambula NO tiene que romper nada.** Si ves paredes o
    puertas cayéndose solas sin que nadie te esté persiguiendo, está mal.
50. Contá los golpes: muro de piedra **30** de un zombi normal, puerta **20**.
    Con una horda de tres encima es un tercio de eso — ese es el número que de
    verdad importa medir.
51. **Reparar:** con la puerta dañada, apretá **B** y clic izquierdo sobre ella.
    Tiene que cobrarte madera y subirle la vida. Probá también sin material:
    tiene que avisar que te falta.
52. **Metete en una casa del mapa y probá construir adentro.** No te tiene que
    dejar. Afuera, en el pasto, sí. El armario saqueado de esa misma casa se
    tiene que seguir pudiendo abrir para guardar cosas.
53. **Pegá un mandoble adentro de tu propia base.** Tus muros **no** se tienen
    que dañar: el ataque del jugador no toca las estructuras a propósito.
54. Construí un **muro de piedra** y uno de **metal**: el panel de abajo tiene
    que mostrar el costo correcto de cada uno (3 piedra / 2 metal + 1 tabla) y
    ponerse en rojo si no te alcanza.
55. **F5 / F9 con muros a media vida.** Al cargar tienen que volver con la misma
    vida, no enteros ni rotos. Y una partida guardada **antes** de este cambio
    tiene que cargar con todo entero (no en cero).

**Del lote de interfaz, mapa e IA:**

56. Apretá **B**: el panel de construcción tiene que ser una **lista vertical
    scrolleable** a la izquierda, con **todas** las opciones visibles —
    incluido el cofre, que antes se salía de la pantalla.
57. Entrá a cualquier minijuego (talar, pescar, fogata): tiene que verse
    *"Escape — salir"* y un botón **Salir**. Probá los dos.
58. Craftear el **recipiente de madera**: tiene que costar **2 madera** (antes
    3 metal).
59. **Metete en una casa, cerrá la puerta y quedate quieto** con un zombi
    afuera: no te tiene que encontrar. Ahora **corré o pegá adentro**: el ruido
    atraviesa un poco y sí te va a venir a buscar. Las dos cosas tienen que
    pasar — si quieto igual te encuentra, o si haciendo ruido nunca aparece,
    está mal.
60. **Entrá a una casa mientras un zombi te persigue.** Tiene que **rodear
    hasta la puerta** y entrar, no quedarse empujando la pared de afuera.
61. **Ponete detrás de una pared con un lobo del otro lado.** No te tiene que
    ver. Era el único bicho que veía a través de las paredes.
62. Mirá el **zombi resistente** (el que tiene dibujo propio): el `?` y el `!`
    tienen que quedar **arriba de su cabeza**, sin taparle el dibujo.
63. El cartel de **sigilo** tiene que salir arriba y al centro cuando te
    detectan, y desaparecer del todo cuando estás oculto.
64. Recorré el mapa: **ninguna puerta** tiene que tener un árbol, una roca, una
    veta o agua pegados a la fachada (zona de 3 de ancho por 2 de fondo).
65. Conseguí un **botiquín** (loot de botiquín o crafteo) y apretá **R** con la
    vida baja **sin estar sangrando**: tiene que curarte 10. Con un vendaje y
    sin sangrado, **R** no te lo tiene que gastar.

**Del pixel art nuevo (el zombi chiquito ya es un dibujo, no un cuadrado):**

66. **Miralo caminar de frente.** No tiene que verse **flotando** sobre el piso
    ni hundido: los pies apoyan en la celda. (Los dibujos venían con la medida
    vieja y se bajaron 4 px al integrarlos; si flota, ese corrimiento falló.)
67. **Dale la vuelta completa**: de frente, de espaldas, a la derecha y a la
    izquierda. Las cuatro tienen que tener dibujo propio. Ojo con la
    **izquierda**: tiene su propio PNG, así que **no** es el espejo de la
    derecha — si se ve espejada, no está cargando el archivo.
68. La animación es de **12 cuadros**: tiene que verse fluida, no en cámara
    lenta ni acelerada. Se ajusta sin programar en `Zombie.tscn` → nodo
    `SpriteDirectional` → campo **Fps** (arranca en 24).
69. Mirá el **zombi pesado dándose vuelta**: puede que **cambie de color** entre
    el frente y la espalda (se dibujaron en sesiones distintas con paletas
    distintas). Está anotado en `ARTE_SPEC.md`; si molesta, se rehace.
70. Compará las tres variantes, que **comparten el dibujo nuevo**: el **normal**
    sale con los colores tal cual; el **corredor** (rápido y débil) sale con un
    tinte naranja por encima, que es a propósito para distinguirlo; y el
    **resistente** usa su propio dibujo, sin tinte.

## Cómo editar el mundo (el mapa de tiles)

El terreno se dibuja con un **TileMap** que se arma por código (`scripts/world.gd`) leyendo un mapa de texto: `data/level_prototype.txt`. Se edita con cualquier editor de texto, sin abrir el editor de tiles.

| Caracter | Tile | ¿Frena / tapa visión? |
|---|---|---|
| `.` | pasto | no |
| `=` | camino | no |
| `~` | agua | **no**: se camina, pero a menos de la mitad de velocidad (acá se pesca) |
| `T` | árbol | **NO frena** (se cruza, más lento) — **sí tapa la visión** de los zombies (segunda capa de física, ver "Sistemas que ya funcionan") |
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

## Meter pixel art

Todo lo que se ve hoy son **formas de colores** (placeholders). El arte real
entra sin tocar código: se deja caer el PNG en la carpeta y listo.

```
game/assets/
  tiles/     pasto.png  camino.png  agua.png  arbol.png  pared.png
             piso.png   roca.png    veta.png  puerta.png        (16×16)
  sprites/
    jugador/  abajo.png  arriba.png  lado.png                   (32×32)
    zombi/    lobo/      animal/     (igual)
```

- **Mientras el archivo no esté**, el juego sigue mostrando la forma de color y
  no se rompe nada. Se puede ir reemplazando de a uno.
- Los personajes se dibujan en **3 direcciones** (la izquierda es la derecha
  espejada, la hace el juego).
- Para **animar**: el mismo nombre con `_1`, `_2`, `_3`. Sin tocar nada más.
- **Siempre PNG con transparencia, nunca JPG.**

Todo el detalle —medidas, dónde apoyan los pies, la paleta y el checklist de los
21 archivos del primer lote— está en **`../docs/ARTE_SPEC.md`**.

Para ver que el sistema anda antes de tener arte propio:

```bash
python3 ../tools/gen_sprite_prueba.py   # el jugador pasa a ser un muñeco
rm -rf assets/sprites/jugador           # y vuelve a ser un cuadrado
```

## Antes de subir cambios

En la máquina de desarrollo hay verificadores estáticos que revisan lo que se
puede revisar **sin abrir Godot** (rutas rotas, tipos que GDScript rechaza al
compilar, mapas mal armados):

```bash
python3 tools/verificadores/run_all.py
```

No reemplazan probar el juego, pero evitan subir algo que ni siquiera abre.

Si tocaste algo del **atlas de tiles** (`_build_atlas()` en `world.gd`, o el
placeholder), hay además una prueba que arma el atlas en Python y lo dibuja:

```bash
python3 tools/prueba_atlas.py          # deja atlas_resultado.png para mirarlo
python3 tools/gen_tiles_placeholder.py # regenera el placeholder de los 9 tiles
```

Avisa si algún tile quedó transparente o si dos salieron del mismo color. El
fucsia en la imagen marca lo que quedaría transparente.
