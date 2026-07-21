# Último Brote — Game Design Document (borrador v0.1)

## 1. Resumen

- **Título de trabajo:** Último Brote
- **Género:** Supervivencia + sim de reconstrucción / gestión, con toques cozy
- **Vista:** 2D top-down, pixel art
- **Plataforma objetivo:** PC (Steam) primero. Posible port a mobile más adelante si el juego valida bien.
- **Modo:** Un jugador en el MVP. Co-op (2-4 jugadores) como posible expansión futura, no en el alcance inicial.
- **Equipo:** 1 persona (diseño/programación) part-time + 1-2 amigos (arte, sonido/programación de apoyo), en tiempo libre.
- **Motor:** Godot 4.x
- **Referencias:** Core Keeper, Stardew Valley, Terraria, RimWorld (para el sistema de "curar" territorio).

## 2. Premisa

Un cataclismo llamado la **Marea Gris** corrompió la vegetación y fauna de una región entera. El/la jugador/a se instala en los restos de un pueblo o estación de investigación abandonada, con el objetivo de **sanar la tierra**.

Cada zona sanada se transforma visualmente: de paleta gris/muerta a paleta verde/viva. Sanar zonas desbloquea nuevos recursos, NPCs, misiones y biomas.

## 3. Loop de juego

### Ciclo de día
- Explorar el mapa (zonas corrompidas y zonas ya sanadas).
- Recolectar recursos (madera, minerales, restos de la corrupción, flora).
- Plantar y cuidar **semillas madre**: plantas especiales que limpian la corrupción de una zona a lo largo de varios días.
- Craftear herramientas, mejoras de base y objetos de defensa.
- Interactuar con NPCs: misiones, comercio, historia del cataclismo.
- Mejorar el refugio/base (almacenamiento, estaciones de crafteo, defensas).

### Ciclo de noche
- La corrupción "contraataca": aparecen criaturas corrompidas y tormentas tóxicas.
- El jugador defiende su base y las zonas ya sanadas (combate simple + defensas tipo tower-defense liviano).
- Perder una zona sanada ante un ataque nocturno es un riesgo real (tensión), pero recuperable.

### Progresión
- Árbol tecnológico de herramientas y mejoras.
- Mapa dividido en biomas que se van abriendo a medida que se sanan zonas (bosque → pantano → costa → montaña).
- Sistema de estaciones del año, que afecta recursos disponibles y dificultad nocturna.

## 4. Pilares de diseño

1. **La sanación es el reward loop principal** — el progreso se *ve* (transformación de arte/paleta), no solo se lee en un menú.
2. **Tensión día/noche sin ser agotador** — la defensa nocturna debe sentirse manejable en sesiones cortas (ideal para desarrollo part-time y para el jugador).
3. **Alcance controlado** — MVP con 1 bioma completo y loop cerrado, antes de prometer el mapa completo.

## 5. Arte y sonido

- Pixel art, resolución de referencia a definir (ej. 16x16 o 32x32 tiles).
- Paleta doble por zona: "corrompida" (grises/violetas apagados) vs "sanada" (verdes/colores vivos) — clave para el pipeline de arte.
- Música ambiental adaptativa (tema día calmo / tema noche tenso) — puede empezar con librerías royalty-free y evolucionar a original.

## 6. Fuera de alcance para el MVP

- Multijugador / co-op.
- Más de 1-2 biomas.
- Narrativa extensa con muchos NPCs.
- Port a mobile.

Estos ítems quedan como backlog para después de validar el prototipo (ver `ROADMAP.md`).
