# Cuarentena — proyecto Godot

Este es el proyecto del juego (motor Godot 4). El diseño y el roadmap completos están en `../docs/GDD.md` y `../docs/ROADMAP.md`.

## Cómo abrirlo (cuando tengas la compu)

1. Instalar [Godot 4.x](https://godotengine.org/download) (versión 4.2 o más nueva — es gratis y no requiere instalación, se ejecuta directo).
2. Abrir Godot, click en **Import**, seleccionar el archivo `game/project.godot` de este repo.
3. Una vez abierto el proyecto, apretar **F5** (o el botón de play) para correr el prototipo.

## Controles

| Tecla | Acción |
|---|---|
| WASD / Flechas | Mover |
| Shift | Correr (más rápido, **más ruido**) |
| C | Agacharse (más lento, **casi sin ruido**) |
| E | Comer (consume 1 comida, restaura hambre) |
| M | Abrir/cerrar el mapa |

## Qué hay armado hasta ahora

- **Movimiento con sigilo** (`Player.tscn` + `player.gd`): caminar / correr / agacharse, cada modo con distinta velocidad y **radio de ruido**. Correr te delata; agacharte te esconde.
- **Zombie con IA** (`Zombie.tscn` + `zombie.gd`): deambula al azar y te detecta de dos formas — te **ve** (cono de visión al frente, con línea de vista bloqueable por paredes) o te **oye** (si entrás en tu radio de ruido, aunque no te vea). Cuando te detecta, persigue tu última posición conocida; si te alcanza, ataca. Si te pierde por unos segundos, vuelve a deambular.
- **Necesidades del personaje** (`components/needs_component.gd`): salud y hambre. El hambre baja sola con el tiempo; si llega a 0 empezás a perder salud. Si la salud llega a 0, la escena se reinicia (la permadeath/dificultad serán configurables más adelante).
- **Recolección y consumo** (`Pickup.tscn` + `pickup.gd`): hay comida (rombos) tirada en el mapa; la juntás al pasarle por encima y la comés con **E**.
- **HUD** (`scenes/ui/HUD.tscn` + `hud.gd`): barras de salud y hambre + contador de comida, que se actualizan solas.
- **Pantalla de mapa** (`scenes/ui/MapScreen.tscn` + `map_screen.gd`): se abre/cierra con **M**. Lee las ubicaciones desde `data/world_map.json` y las dibuja como etiquetas (base funcional para cuando haya una ilustración de mapa real, estilo la referencia en `docs/WORLD_MAP.md`).
- **Input por código** (`autoload/input_setup.gd`): las teclas se registran al arrancar, así no hay que configurar el mapa de input a mano.

Todo el arte es placeholder a propósito (cuadrados y rombos de colores): la prioridad de la Fase 1 (ver roadmap) es validar que el loop de juego es divertido, no el arte.

### Cómo probar el loop
Junta algo de comida evitando al zombie, mantené el hambre arriba comiendo con **E**, y usá **C** (agacharse) para pasar cerca del zombie sin que te oiga. Si corrés (Shift) cerca del zombie, te va a escuchar y perseguir.

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
