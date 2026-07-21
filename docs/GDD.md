# Cuarentena — Game Design Document (borrador v0.2)

> v0.2: pivot de concepto. La v0.1 (sim de restauración ecológica "Último Brote") se reemplaza por un survival de zombies inspirado en Project Zomboid, DayZ y The Forest. Ver decisiones de alcance en la sección 7.

## 1. Resumen

- **Título de trabajo:** Cuarentena
- **Género:** Supervivencia de mundo abierto (zombies): exploración, caza, pesca, crafteo, construcción de base en cualquier lugar del mapa.
- **Vista:** 2D top-down/isométrico, pixel art (no 3D — ver sección 7).
- **Plataforma objetivo:** PC (Steam).
- **Modo:** Un jugador en el MVP, diseñado desde el inicio para soportar cooperativo (2-4 jugadores) en una fase posterior.
- **Equipo:** 1 persona (diseño/programación) part-time + 1-2 amigos (arte, sonido/programación de apoyo), en tiempo libre.
- **Motor:** Godot 4.x
- **Referencias:** Project Zomboid (loop y vista), DayZ (tensión, mundo abierto, permadeath), The Forest (supervivencia/caza/base building en un entorno hostil).

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
- Necesidades del personaje: hambre, sed, salud, cansancio, temperatura, infección/enfermedad.
- Zombies como amenaza constante: patrullan, reaccionan a ruido y visión; el sigilo es tan válido como el combate directo.
- Muerte permanente (permadeath) configurable como modo de dificultad (apela al público de DayZ).

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

- Pixel art top-down/isométrico (a definir resolución de tile, ej. 16x16 o 32x32).
- Paleta apagada/desaturada para reforzar el tono de colapso, con contraste claro para zombies y peligros.
- Sonido como mecánica: el ruido del jugador (correr, disparar, motor) debe tener representación audible y visual (radio de ruido) porque atrae zombies.

## 6. Fuera de alcance para el MVP

- Multijugador / netcode real (se diseña para soportarlo, no se implementa aún).
- Mundo grande / múltiples biomas — arrancar con un mapa chico y denso.
- Vehículos.
- Sistema de clima/estaciones complejo.
- Port a mobile.

## 7. Decisiones de alcance (por qué 2D y no 3D)

DayZ y The Forest son juegos 3D en primera/tercera persona con presupuestos y equipos mucho más grandes que el nuestro. Para un equipo de 1-3 personas part-time, replicar esa fidelidad visual no es realista como meta inicial.

Se optó por **2D top-down/isométrico**, tomando como referencia de viabilidad a **Project Zomboid** (mismo espíritu — zombies, caza, pesca, base en cualquier lugar, cooperativo — hecho originalmente por un equipo muy chico y con gran éxito en Steam). Esto reduce drásticamente el costo de arte (sin modelado 3D ni animación esquelética compleja) y de programación (sin cámara 3D, colisiones 3D, optimización de renderizado 3D).

Si el prototipo valida bien y el equipo crece, un salto a 3D low-poly queda como posibilidad a futuro, no como parte del plan inicial.
