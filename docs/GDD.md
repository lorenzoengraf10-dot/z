# Cuarentena — Game Design Document (borrador v0.3)

> v0.2: pivot de concepto. La v0.1 (sim de restauración ecológica "Último Brote") se reemplaza por un survival de zombies inspirado en Project Zomboid, DayZ y The Forest. Ver decisiones de alcance en la sección 7.
>
> **v0.3:** el loop se cierra al estilo **Mini DAYZ**. La muerte permanente deja de ser "un modo de dificultad" y pasa a ser **el** modo: cada partida es una vida, el spawn es al azar y lo único que sobrevive a la muerte son los **perks**. Ver la sección 3.1.

## 1. Resumen

- **Título de trabajo:** Cuarentena
- **Género:** Supervivencia de mundo abierto (zombies): exploración, caza, pesca, crafteo, construcción de base en cualquier lugar del mapa.
- **Vista:** 2D top-down/isométrico, pixel art (no 3D — ver sección 7).
- **Plataforma objetivo:** PC (Steam).
- **Modo:** Un jugador en el MVP, diseñado desde el inicio para soportar cooperativo (2-4 jugadores) en una fase posterior.
- **Equipo:** 1 persona (diseño/programación) part-time + 1-2 amigos (arte, sonido/programación de apoyo), en tiempo libre.
- **Motor:** Godot 4.x
- **Referencias:** Project Zomboid (loop y vista), DayZ (tensión, mundo abierto, permadeath), The Forest (supervivencia/caza/base building), **Mini DAYZ** (estructura de partidas cortas con perks entre corridas).
- **Nota de propiedad intelectual:** tomamos **mecánicas**, no identidad. Nombre, arte, textos, música e interfaz son propios. El detalle está en `LEGAL_Y_PRIVACIDAD.md`, sección 5.3.

## 2. Premisa

Un brote zombie colapsó la sociedad. No hay una historia lineal con misión principal: el jugador es un/a superviviente en un mapa abierto (pueblos, bosques, costa, campos) y decide **dónde asentarse y cómo sobrevivir**. No hay ubicación de base fija ni obligatoria — se puede fortificar una casa, levantar un campamento en el bosque, o algo en la costa para pescar.

## 3. Loop de juego

### Exploración y recolección
- Recorrer el mapa: pueblos, casas, bosques, costa, campos.
- Looteo de estructuras (comida, herramientas, medicinas, armas improvisadas).
- Caza de fauna salvaje (carne, pieles, huesos).
- Pesca en ríos, lagos y costa (comida confiable sin depender de looteo).
- Tala, minería/recolección de materiales de crafteo.

### Supervivencia
- Necesidades del personaje: hambre, sed, salud, cansancio, temperatura, infección y **sangrado**.
- El **sangrado** es la amenaza más aguda: no se frena solo y drena salud sostenido. Obliga a llevar vendajes encima, que ocupan lugar en una mochila chica.
- Zombies como amenaza constante: patrullan, reaccionan a ruido y visión; el sigilo es tan válido como el combate directo.
- **Lobos**: rápidos y en manada. Son la amenaza del campo abierto, así como los zombies lo son de los pueblos.
- **Mochila con espacio limitado**: la decisión constante no es "qué junto" sino "qué dejo".

## 3.1. La partida (run)

Cada partida es una vida:

1. **Spawn al azar** en una celda caminable al aire libre, distinta cada vez. No hay campamento inicial: la primera decisión es orientarse.
2. **Saqueo de edificios.** Cada construcción tiene contenedores que se revisan una sola vez, tardan unos segundos y hacen ruido. Es el motor de la exploración: los edificios dejan de ser decorado.
3. **Muerte.** Se pierde todo: inventario, posición, construcciones.
4. **Resumen**: días sobrevividos, zombies y lobos eliminados, lugares saqueados, récord personal.
5. **Perks.** Los hitos acumulados entre todas las partidas desbloquean mejoras permanentes (sangrar menos, más capacidad, menos ruido, empezar con equipo). Es la única progresión que atraviesa la muerte.

Por qué así: con muerte permanente y sin progresión ninguna, morir a los 20 minutos se siente gratis y el juego se abandona. Con perks, cada partida deja algo, y la siguiente arranca un escalón más arriba sin que el juego deje de ser difícil.

**Mapa hecho a mano, no procedural.** La rejugabilidad la da el spawn aleatorio y el loot, no la generación de terreno: un mapa dibujado a mano tiene pueblos con forma, rutas que llevan a algún lado y rincones que se aprenden — cosas que un generador no da gratis y que un equipo de tres puede mantener.

### Base y crafteo
- Construcción de base **en cualquier punto del mapa**: fortificación, almacenamiento, trampas, defensas contra hordas u oleadas nocturnas.
- Árbol de crafteo: herramientas, armas improvisadas/de fuego, curativos, mejoras de base.
- Progresión por uso de habilidades (mejorás cazando/pescando/combatiendo, no por XP de nivel — estilo Zomboid), no por historia.

### Multijugador (fase posterior, no en el MVP)
- El mismo mundo debe poder jugarse solo o en cooperativo.
- Se diseñan los sistemas (inventario, guardado, IA) pensando en que más adelante haya un servidor con varios jugadores, pero el netcode real se implementa recién cuando el loop en solitario ya sea divertido (ver `ROADMAP.md`).

## 4. Pilares de diseño

1. **Libertad de asentamiento** — nada de ubicación de base obligatoria; el mapa abierto es el punto de partida, no una serie de niveles.
2. **Tensión sostenida, no jump-scares** — el peligro viene de gestionar recursos + ruido/visibilidad de los zombies, no de sustos scriptados.
3. **Alcance controlado** — MVP en 2D top-down con un mapa chico, antes de prometer un mundo grande o multijugador.

## 5. Arte y sonido

- Pixel art top-down. **Tiles 16×16, personajes 32×32** (definido; ver `ARTE_SPEC.md`).
- Paleta apagada/desaturada para reforzar el tono de colapso, con contraste claro para zombies y peligros.
- Sonido como mecánica: el ruido del jugador (correr, disparar, motor) debe tener representación audible y visual (radio de ruido) porque atrae zombies.

## 6. Fuera de alcance para el MVP

- Multijugador / netcode real (se diseña para soportarlo, no se implementa aún).
- Generación procedural de mapa (decidido: el mapa es a mano, ver 3.1).
- Múltiples biomas separados — el mapa actual (160×100 tiles) mezcla costa, bosque, pueblos, zona industrial y cantera en una sola región.
- Vehículos.
- Sistema de clima/estaciones complejo.
- Port a mobile.

## 7. Decisiones de alcance (por qué 2D y no 3D)

DayZ y The Forest son juegos 3D en primera/tercera persona con presupuestos y equipos mucho más grandes que el nuestro. Para un equipo de 1-3 personas part-time, replicar esa fidelidad visual no es realista como meta inicial.

Se optó por **2D top-down/isométrico**, tomando como referencia de viabilidad a **Project Zomboid** (mismo espíritu — zombies, caza, pesca, base en cualquier lugar, cooperativo — hecho originalmente por un equipo muy chico y con gran éxito en Steam). Esto reduce drásticamente el costo de arte (sin modelado 3D ni animación esquelética compleja) y de programación (sin cámara 3D, colisiones 3D, optimización de renderizado 3D).

Si el prototipo valida bien y el equipo crece, un salto a 3D low-poly queda como posibilidad a futuro, no como parte del plan inicial.
