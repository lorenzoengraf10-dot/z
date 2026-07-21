# Cuarentena — proyecto Godot

Este es el proyecto del juego (motor Godot 4). El diseño y el roadmap completos están en `../docs/GDD.md` y `../docs/ROADMAP.md`.

## Cómo abrirlo (cuando tengas la compu)

1. Instalar [Godot 4.x](https://godotengine.org/download) (versión 4.2 o más nueva — es gratis y no requiere instalación, se ejecuta directo).
2. Abrir Godot, click en **Import**, seleccionar el archivo `game/project.godot` de este repo.
3. Una vez abierto el proyecto, apretar **F5** (o el botón de play) para correr el prototipo.

## Qué hay armado hasta ahora

- Movimiento básico del personaje (`Player.tscn` + `player.gd`) con flechas del teclado.
- Escena principal (`Main.tscn`) con una cámara que sigue al jugador y un piso de placeholder (sin arte todavía).
- **Pantalla de mapa** (`scenes/ui/MapScreen.tscn` + `map_screen.gd`): se abre/cierra con la tecla **M**. Lee las ubicaciones desde `data/world_map.json` y las dibuja como etiquetas sobre el mapa (sin arte todavía — es la base funcional para cuando haya una ilustración de mapa real, estilo la referencia que se usó en `docs/WORLD_MAP.md`).

Todo esto es placeholder a propósito: la prioridad de la Fase 1 (ver roadmap) es validar el loop de juego, no el arte.

## Cómo agregar/editar ubicaciones del mapa

Editar `data/world_map.json`. Cada punto de interés tiene:

```json
{
  "name": "Nombre del lugar",
  "type": "camp | outpost | resource | danger | hub",
  "position": [0.0, 0.0],
  "description": "Texto corto"
}
```

`position` son coordenadas normalizadas (0.0 a 1.0, no píxeles), para que el mapa escale a cualquier resolución de pantalla. `[0.5, 0.5]` es el centro.

## Estructura de carpetas

```
game/
  project.godot
  scenes/          escenas jugables (Main, Player, UI)
  scripts/         código GDScript
  data/            datos del juego (world_map.json, etc.)
  assets/
    sprites/       arte de personajes/objetos (vacío por ahora)
    tiles/         tilesets del mundo (vacío por ahora)
    audio/         música y sonido (vacío por ahora)
    map/           arte de la pantalla de mapa mundial (vacío por ahora)
```
