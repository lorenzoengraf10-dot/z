# Especificación de arte — Cuarentena

Estándar del proyecto para que todo el arte encaje entre sí. Si algo se dibuja con otra medida, después no calza en el mundo — respetar estos tamaños.

## Tamaños base (en píxeles)

| Elemento | Tamaño | Notas |
|---|---|---|
| **Tile del mundo** | **16 × 16** | Unidad base del mapa (pasto, camino, agua, árboles, paredes). |
| **Personajes** (jugador, zombies) | **32 × 32** | Ocupan ~2×2 tiles. Deja lugar para detalle y animación legible en top-down. |
| **Objetos sueltos** (comida, ítems) | 16 × 16 | Un tile. Pueden ser un poco más chicos dentro del cuadro. |
| **Props grandes** (opcional) | múltiplos de 16 (32×32, 32×48…) | Ej. un árbol grande, un auto. Siempre múltiplo del tile. |

## Reglas generales

- **Todo en múltiplos de 16.** Mantiene la grilla consistente.
- **Un solo "pixel size".** No mezclar arte de 16px con arte de 48px sin querer: el detalle del pixel tiene que verse del mismo "tamaño" en todos lados. Al dibujar un personaje de 32×32, cada "pixel" es igual de grande que en un tile de 16×16.
- **Paleta compartida.** Conviene definir una paleta común (tono apagado/de colapso, como dice el GDD) y que todos usen esa misma paleta.
- **Fondo transparente** en personajes y objetos (PNG con alpha), para que se vean sobre cualquier tile.
- **Sin anti-aliasing / sin filtrado.** En Godot los sprites van con filtro "Nearest" (pixel nítido), no "Linear". Es la config por defecto para pixel art.

## Animación

- Los personajes se animan por **frames** (cuadros) de 32×32, uno al lado del otro en una tira (spritesheet).
- Mínimo para el prototipo: **idle** (quieto) y **walk** (caminar) en 4 direcciones, o al menos 2 (frente/espalda) + espejar los costados.

## Estado actual (placeholder)

Hoy el juego usa formas de colores como placeholder (cuadrados para personajes, tiles de colores planos en `game/assets/tiles/placeholder_tiles.png`). El arte real reemplaza esos placeholders respetando estas medidas, sin tocar el código.
