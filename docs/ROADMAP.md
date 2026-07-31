# Roadmap — Cuarentena

Contexto: equipo part-time (1 persona + amigos en tiempo libre), objetivo final: publicar en Steam.
Los tiempos son estimaciones para ritmo part-time, no full-time.

> Nota: roadmap actualizado tras el pivot de concepto a survival de zombies 2D (ver `GDD.md` v0.2). El eje "solo primero, coop después" reemplaza al plan anterior.

## Fase 0 — Preproducción (2-4 semanas)
- [ ] Cerrar GDD corto (ver `GDD.md`) y validarlo con el equipo.
- [ ] Moodboard de arte (paleta de colapso/desaturada, referencias de tiles, personaje y zombies) — armarlo en Figma.
- [ ] Primeros mockups de UI/HUD (inventario, barra de necesidades, menú principal) en Figma antes de programarlos.
- [x] Estructura inicial del proyecto Godot lista para abrir (ver `/game`, `game/README.md`).
- [x] Sistema de mapa mundial (datos + pantalla básica) armado — ver `WORLD_MAP.md` y `game/data/world_map.json`.
- [ ] Instalar Godot 4 y abrir el proyecto por primera vez (pendiente hasta tener la compu).
- [ ] Confirmar quién de tus amigos se suma y en qué rol (arte / sonido / programación de apoyo).
- [ ] Armar el espacio de Notion para marcar y seguir las tareas.
- [ ] Diseñar los datos base (inventario, entidades, guardado) pensando en que en el futuro haya multijugador, aunque todavía no se implemente.

## Fase 1 — Prototipo jugable / vertical slice (6-8 semanas)
Objetivo: validar que el loop central es divertido antes de invertir en contenido.
- [x] Movimiento del personaje + cámara top-down (placeholder, sin arte).
- [x] Pantalla de mapa mundial básica (tecla M), leyendo ubicaciones desde `world_map.json`.
- [x] 1-2 zombies con IA básica: deambular, detección por visión/ruido, persecución y ataque (`zombie.gd`).
- [x] Sistema de sigilo/ruido básico (agacharse, correr = más ruido = atrae zombies) (`player.gd`).
- [x] Necesidades básicas del personaje: hambre y salud (`needs_component.gd` + HUD).
- [x] Recolección de recursos: comida del piso, **tala de árboles** (madera) y **pesca** (`interactor.gd`, tecla E).
- [x] Mapa jugable con TileMap real, con colisiones y editable desde `data/level_prototype.txt` (`world.gd`). Arte de tiles todavía placeholder.
- [x] Pesca básica (tecla E frente al agua; también sacia la sed, pero el agua sin hervir te saca salud).
- [x] Construcción de barricadas en cualquier punto del mapa (`build_system.gd`, tecla B).
- [x] Guardado/carga simple (`save_system.gd`, F5/F9).
- [ ] **Playtesting interno (vos + amigos) y ajuste de sensación de juego.** ← lo único que falta de la Fase 1

**Criterio de éxito de esta fase:** si después de jugarlo un rato el prototipo no engancha ni a ustedes mismos, hay que iterar el diseño antes de seguir.

## Fase 2 — Producción core (2-3 meses)
- [x] Sistemas completos de crafteo (`crafting.gd` + `data/recipes.json`) y construcción de base (en cualquier ubicación).
- [x] Caza (`animal.gd`: los animales huyen del ruido) y pesca como fuentes de comida.
- [x] Necesidades completas: sed, cansancio (energía), temperatura, sangrado.
- [x] IA de zombies con variedad (normal / corredor / resistente) y **hordas que reaccionan al ruido acumulado** (`horde_spawner.gd`).
- [x] Mapa más grande (costa al oeste, lago, bosques y pueblo con edificios).
- [x] **Ciclo día/noche** con oscurecimiento e iluminación 2D (`day_night.gd`), que además baja la temperatura de noche.
- [x] **Fogatas**: se construyen, se prenden con un **minijuego de fricción** (aguja girando + zona verde del 15% + mantener 3 s), iluminan, abrigan y habilitan las recetas de cocina.
- [x] Botones en pantalla para mapa / crafteo / construcción, más reloj del juego.
- [ ] **Arte final** (o casi final) de personaje, tiles, zombies y UI. → rol de arte
- [ ] **Música y sonido base**. El enganche ya está listo (`audio_manager.gd`): solo hay que copiar los archivos a `assets/audio/`. → rol de audio

> Nota: los sistemas de la Fase 2 están programados, pero el **balance** (velocidades, ritmo del hambre, dificultad de las hordas) se ajusta recién después del playtest de la Fase 1.

## Fase 3 — Contenido, pulido y arquitectura multijugador (2-3 meses)
- [ ] Progresión por uso de habilidades (caza, combate, pesca, crafteo).
- [ ] Permadeath configurable como modo de dificultad.
- [ ] Balance de dificultad y economía de recursos.
- [ ] Pulido de UI/UX, menús, opciones.
- [ ] Refactor de arquitectura para separar lógica de juego de la capa de input/render, preparando el terreno para el netcode.
- [ ] Prototipo técnico de multijugador (2 jugadores, LAN) — recién acá se empieza el netcode real.

## Fase 4 — Cooperativo online y preparación de lanzamiento (2-3 meses)
- [ ] Netcode cliente-servidor funcional para 2-4 jugadores.
- [ ] Testing de coop (sincronización, latencia, desconexiones).
- [ ] Arte final de la pantalla de mapa mundial (ilustración estilo la referencia en `WORLD_MAP.md`) — sirve también como key art / capsule de Steam.
- [ ] Crear página de Steam (Steamworks, fee de USD 100 por juego) con **meses de anticipación** para acumular wishlists — idealmente 3-6 meses antes del lanzamiento.
- [ ] Trailer y capturas mostrando exploración, caza/pesca y construcción de base.
- [ ] Demo pública / participación en Steam Next Fest.
- [ ] Testing externo (amigos, comunidad, foros de indie devs).
- [ ] Localización mínima: inglés + español.
- [ ] Definir precio (referencia: juegos de survival 2D exitosos suelen ubicarse en USD 15-20).

## Fase 5 — Lanzamiento y soporte
- [ ] Early Access (recomendado para este género: permite lanzar con el mapa/contenido de la Fase 2-3 y crecer con la comunidad) o lanzamiento 1.0.
- [ ] Plan de updates post-lanzamiento.
- [ ] Devlogs periódicos desde la Fase 1 en adelante (ayuda a mantener motivación del equipo y a construir audiencia antes del lanzamiento).

## Riesgos y cómo mitigarlos
- **Netcode de multijugador:** es la parte más difícil del proyecto. Por eso se deja para la Fase 3-4, después de validar que el juego solo ya es divertido — evita que trabe el proyecto entero desde el principio.
- **Scope creep:** mantenerse estrictos con el MVP de la Fase 1 (mapa chico, pocas mecánicas) antes de sumar features nuevas.
- **Dependencia de arte de un solo amigo:** tener un plan B con asset packs de placeholder si el ritmo baja.
- **Motivación en proyecto part-time:** hitos cortos, jugables y visibles (cada fase debe terminar en algo que se pueda mostrar/jugar).

## Próximos pasos inmediatos
1. Instalar Godot 4 y armar la estructura base del repo.
2. Definir con tus amigos quién entra y en qué rol.
3. Prototipo de movimiento + 1 zombie con IA básica en 1-2 semanas.
