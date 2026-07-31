# Plan maestro — Cuarentena (título de trabajo)

Este documento junta todo el proyecto en una sola lectura: qué es el juego, qué falta construir, con qué equipo/herramientas/plata, y qué decisiones siguen abiertas. Los documentos detallados (`GDD.md`, `ROADMAP.md`, `WORLD_MAP.md`) siguen siendo la fuente de verdad de cada tema — este archivo es el resumen ejecutivo y el punto de entrada.

## 1. Resumen ejecutivo

- **Título de trabajo:** Cuarentena (todavía sin cerrar — ver sección 9).
- **Género:** Supervivencia de mundo abierto con zombies: exploración, caza, pesca, crafteo, construcción de base en cualquier lugar del mapa.
- **Vista/arte:** 2D top-down/isométrico, pixel art.
- **Plataforma:** PC. Publicación **sin fines de lucro** — gratis en itch.io; Steam queda como opción a futuro (ver sección 7).
- **Modo:** un jugador desde el MVP, con arquitectura pensada desde el inicio para sumar cooperativo (2-4 jugadores) más adelante.
- **Referencias:** Project Zomboid (viabilidad de alcance/vista), DayZ (tensión, permadeath), The Forest (supervivencia y base building en entorno hostil).
- **Equipo:** el usuario como lead diseño/programación part-time, más amigos por confirmar en arte y sonido/programación de apoyo.
- **Estado actual:** concepto y alcance cerrados (`GDD.md` v0.2), roadmap por fases definido (`ROADMAP.md`), diseño del mapa mundial definido (`WORLD_MAP.md`), y ya existe un proyecto Godot jugable (`game/`) con un primer corte del loop de supervivencia: movimiento con sigilo (caminar/correr/agacharse con ruido), un zombie con IA (deambula, te detecta por visión o por ruido, persigue y ataca), necesidades de salud y hambre, recolección y consumo de comida, un HUD, y la pantalla de mapa — todo con arte placeholder a propósito.

Ver el detalle completo de diseño en [`GDD.md`](GDD.md).

## 2. Checklist de sistemas de gameplay

Vista plana de todo lo que el juego necesita, más allá del orden por fases (eso vive en `ROADMAP.md`).

| Sistema | Estado | Fase donde se completa |
|---|---|---|
| Movimiento y cámara | ✅ hecho (placeholder) | Fase 1 |
| Pantalla de mapa mundial | ✅ base hecha (placeholder) | Fase 1 (arte final en Fase 4) |
| Mapa jugable (TileMap con costa, lago, bosques y pueblo) | ✅ hecho (tiles placeholder) | Fase 1-2 |
| IA de zombies (deambular, visión/ruido, persecución, ataque) | ✅ hecho | Fase 1 |
| Variedad de zombies + hordas por ruido | ✅ hecho | Fase 2 |
| Sigilo / ruido (caminar/correr/agacharse) | ✅ hecho | Fase 1 |
| Combate del jugador | ✅ hecho | Fase 1 |
| Recolección + consumo de comida | ✅ hecho | Fase 1 |
| Tala de árboles (madera) | ✅ hecho | Fase 1 |
| Pesca | ✅ hecho | Fase 1 |
| Caza | ✅ hecho | Fase 2 |
| Crafteo | ✅ hecho | Fase 2 |
| Construcción de base en cualquier lugar | ✅ hecho (barricadas) | Fase 2 |
| Necesidades (salud, hambre, sed, energía, temperatura, sangrado) | ✅ hecho | Fase 2 |
| Ciclo día/noche + iluminación | ✅ hecho | Fase 2 |
| Fogatas (luz, calor, cocinar) + minijuego de fricción | ✅ hecho | Fase 2 |
| Guardado/carga | ✅ hecho | Fase 1-2 |
| HUD (necesidades, inventario, progreso, mensajes, reloj, botones) | ✅ hecho | Fase 3 (pulido) |
| Looteo de estructuras | ⏳ pendiente | Fase 3 |
| Progresión por uso de habilidades | ⏳ pendiente | Fase 3 |
| Permadeath configurable | ⏳ pendiente | Fase 3 |
| **Arte final** (personaje, tiles, zombies, UI) | ⏳ pendiente → **rol de arte** | Fase 2 |
| **Audio** (música y efectos) | 🟡 enganche listo, faltan los archivos → **rol de audio** | Fase 2 |
| Arquitectura preparada para multijugador | 🟡 en camino (lógica separada en componentes) | Fase 0-3 |
| Netcode cooperativo real | ⏳ pendiente | Fase 3-4 |

> ⚠️ Todo lo marcado ✅ está **programado pero todavía no probado en Godot** (se escribió sin poder ejecutar el motor). El primer playtest puede pedir ajustes.

## 3. Mundo y contenido

Resumen de [`WORLD_MAP.md`](WORLD_MAP.md): un hub central fortificado ("Refugio Central", nombre de ejemplo) rodeado de puntos de interés conectados por caminos (puesto militar, campamento maderero, zona de cultivo, asentamiento de chatarreros, ruinas de alto riesgo, campamento ferroviario), sobre terreno de bosque, montaña, río y costa.

**Decisión ya tomada:** el mapa es **fijo** (no procedural ni infinito), con la posibilidad de sumar zonas nuevas en updates después del lanzamiento.

## 4. Equipo y roles

- **Vos:** diseño y programación, lead del proyecto, en tiempo libre.
- **Amigos:** posible incorporación en arte y sonido/programación de apoyo. **Pendiente de confirmar** — se define en las próximas semanas, sin bloquear el trabajo de la Fase 0-1 en curso.

## 5. Stack técnico y herramientas

- **Motor:** Godot 4.x (ya en uso en `game/`).
- **Arte (pixel art in-game):** Aseprite para tiles, personajes y zombies (a confirmar si se suma alguien de arte con otra herramienta).
- **Diseño / mockups:** Figma, para maquetar UI/HUD, menús y pantallas antes de programarlas, y como pizarra visual del mapa. No reemplaza a Aseprite (que es para el pixel art final) — Figma es para diseñar cómo se ve y se ordena la interfaz. Tiene plan gratis, así que no rompe el presupuesto.
- **Control de versiones:** este repo de GitHub.
- **Gestión de tareas:** Notion — herramienta principal para marcar y seguir el estado de las tareas (está conectado a Claude, lo que facilita mantenerlo actualizado).
- **Sonido:** librerías royalty-free para arrancar; se evalúa audio original si se suma alguien al equipo.
- **Gestión de tareas (alternativas):** Notion es la opción principal, pero cualquier herramienta similar (Trello, GitHub Projects) sirve — lo importante es tener un solo lugar donde el equipo marque y siga las tareas.
- **Presupuesto:** proyecto **sin fines de lucro** — se hace por gusto/portfolio, no para ganar plata. Todo con herramientas gratuitas (Godot, Aseprite tiene alternativa gratis, Figma free, Notion free). El tema plata se ve más adelante y no bloquea nada ahora (ver secciones 7 y 9).

## 6. Roadmap resumido

Detalle completo con checklist en [`ROADMAP.md`](ROADMAP.md).

| Fase | Objetivo | Duración estimada | Estado |
|---|---|---|---|
| 0 — Preproducción | GDD, moodboard, setup técnico | 2-4 semanas | 🔵 en curso |
| 1 — Prototipo / vertical slice | Validar que el loop central es divertido | 6-8 semanas | 🔵 en curso (2 ítems adelantados) |
| 2 — Producción core | Sistemas completos + arte/sonido base | 2-3 meses | ⏳ |
| 3 — Contenido, pulido y arquitectura multijugador | Progresión, balance, prep. para netcode | 2-3 meses | ⏳ |
| 4 — Cooperativo online y pre-lanzamiento | Netcode, página de Steam, wishlists, demo | 2-3 meses | ⏳ |
| 5 — Lanzamiento y soporte | Early Access / 1.0, updates | — | ⏳ |

## 7. Publicación (sin fines de lucro)

El objetivo del proyecto es **hacerlo y compartirlo**, no venderlo. La plata se ve más adelante y no condiciona las decisiones de ahora.

- **Dónde publicarlo:** [itch.io](https://itch.io) es la opción natural — es **gratis** de publicar y permite subir el juego (gratis o "pagá lo que quieras"). Encaja perfecto con el enfoque sin fines de lucro.
- **Steam (opcional, a futuro):** solo si en algún momento el equipo quiere. Tiene un fee único de USD 100 por juego, así que queda como decisión para más adelante, no como meta obligatoria. Las tareas de Steam que aparecen en el `ROADMAP.md` (Fases 4-5) quedan como **opcionales**.
- **Difusión:** devlogs/capturas de los avances (en redes o donde el equipo prefiera) para mostrar el progreso y, si se quiere, juntar gente que lo pruebe. De bajo costo y buenos para mantener la motivación.
- **Localización:** al menos español; inglés si se quiere llegar a más gente.

## 8. Riesgos y mitigaciones

- **Netcode de multijugador** es la parte más difícil del proyecto → se deja para la Fase 3-4, después de validar que el juego en solitario ya es divertido.
- **Scope creep** → MVP estricto en la Fase 1 (mapa chico, pocas mecánicas) antes de sumar features nuevas.
- **Dependencia de un solo artista** → tener un plan B con asset packs de placeholder si el ritmo baja.
- **Motivación en proyecto part-time** → hitos cortos, jugables y visibles en cada fase.

## 9. Decisiones — resueltas y pendientes

- **Título:** sin cerrar todavía. Ideas para elegir/discutir con los amigos: **Cuarentena** (actual), **Zona Cero**, **Foco Cero**, **Últimos Días**, **Refugio** / *The Last Shelter* (si se prioriza un título en inglés para Steam internacional), **Tierra Muerta**. Ninguna es definitiva.
- **Mapa:** fijo por ahora, con updates de contenido más adelante — resuelto.
- **Equipo/amigos:** pendiente, se define en unas semanas.
- **Gestión de tareas:** Notion (o alguna similar) — resuelto.
- **Fines de lucro:** **no** — proyecto por gusto/portfolio. Se publica gratis (itch.io); vender queda descartado como meta por ahora — resuelto.
- **Presupuesto / plata:** se ve más adelante y no bloquea nada ahora — todo con herramientas gratuitas. Al ser sin fines de lucro y publicar en itch.io (gratis), no hay ningún gasto obligatorio en el camino — resuelto.
- **Permadeath y dificultad:** totalmente configurable por el jugador, sin modo fijo separado — resuelto.

## 10. Próximos pasos inmediatos

1. Instalar Godot 4 y abrir el proyecto en `game/` (ver `game/README.md`) cuando tengas la compu.
2. Prototipo de movimiento + 1 zombie con IA básica (1-2 semanas).
3. Cerrar con tus amigos quién se suma y en qué rol.
4. Elegir título definitivo de la lista de la sección 9 (o proponer otro).
