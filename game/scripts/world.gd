extends TileMap
## Construye el mundo con tiles reales. Para poder trabajar sin abrir el editor,
## el TileSet se arma por código (en vez de un recurso .tres) y el mapa se pinta
## leyendo un archivo de texto editable (data/level_prototype.txt).
##
## Tiles del atlas placeholder (una fila de 5, 16x16 c/u):
##   0 pasto | 1 camino | 2 agua | 3 arbol | 4 pared
## Las tiles sólidas (agua, arbol, pared) colisionan en la capa 1 → frenan al
## jugador/zombie y tapan la visión del zombie (que hace raycast contra esa capa).
##
## Nota: en Godot 4.3+ el nodo TileMap figura como deprecado (lo reemplaza
## TileMapLayer), pero sigue funcionando. Se usa TileMap a propósito para que el
## proyecto abra igual en 4.2 que en versiones más nuevas.

const TILE_SIZE := 16
const SOURCE_ID := 0
const TILES_TEXTURE := "res://assets/tiles/placeholder_tiles.png"
const LEVEL_PATH := "res://data/level_prototype.txt"

const GRASS := "."
const PATH := "="
const WATER := "~"
const TREE := "T"
const WALL := "#"

# Caracter del mapa ASCII -> índice de tile en el atlas.
const CHAR_TO_TILE := {
	GRASS: 0,
	PATH: 1,
	WATER: 2,
	TREE: 3,
	WALL: 4,
}
# Índices de tiles que colisionan (y tapan la visión).
const SOLID := {2: true, 3: true, 4: true}

var _tile_to_char: Dictionary = {}
## Tiles que el jugador modificó (ej. árboles talados). Se guardan en la partida.
var _modified: Dictionary = {}


func _ready() -> void:
	add_to_group("world")
	for ch in CHAR_TO_TILE.keys():
		_tile_to_char[CHAR_TO_TILE[ch]] = ch
	tile_set = _build_tileset()
	_paint_level()


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Capa de física: lo sólido choca en la capa de colisión 1 (el "mundo").
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	var src := TileSetAtlasSource.new()
	src.texture = load(TILES_TEXTURE) as Texture2D
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var half := TILE_SIZE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])

	for tile_index in range(CHAR_TO_TILE.size()):
		var coords := Vector2i(tile_index, 0)
		src.create_tile(coords)
		if SOLID.has(tile_index):
			var data := src.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)

	ts.add_source(src, SOURCE_ID)
	return ts


func _paint_level() -> void:
	var lines := _load_level_lines()
	if lines.is_empty():
		push_warning("world.gd: no se pudo cargar el nivel; pinto un claro de pasto.")
		for y in range(-6, 7):
			for x in range(-10, 11):
				set_cell(0, Vector2i(x, y), SOURCE_ID, Vector2i(0, 0))
		return

	# Centramos el mapa en el origen (0,0), donde spawnea el jugador.
	var h := lines.size()
	var w := 0
	for ln in lines:
		w = maxi(w, ln.length())
	var off_x := int(w / 2.0)
	var off_y := int(h / 2.0)

	for row in range(h):
		var line: String = lines[row]
		for col in range(line.length()):
			var ch := line[col]
			var tile_index: int = CHAR_TO_TILE.get(ch, 0)
			set_cell(0, Vector2i(col - off_x, row - off_y), SOURCE_ID, Vector2i(tile_index, 0))


func _load_level_lines() -> PackedStringArray:
	if not FileAccess.file_exists(LEVEL_PATH):
		return PackedStringArray()
	var f := FileAccess.open(LEVEL_PATH, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var text := f.get_as_text()
	var result := PackedStringArray()
	for raw in text.split("\n"):
		var ln := raw.rstrip("\r")
		if ln.length() > 0:
			result.append(ln)
	return result


# --- Consulta y modificación de tiles ---

func cell_at(global_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(global_pos))


## Centro (en coordenadas globales) de una celda.
func center_of(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))


func char_at_cell(cell: Vector2i) -> String:
	var atlas := get_cell_atlas_coords(0, cell)
	if atlas.x < 0:
		return ""
	return str(_tile_to_char.get(atlas.x, ""))


func char_at(global_pos: Vector2) -> String:
	return char_at_cell(cell_at(global_pos))


func is_solid_cell(cell: Vector2i) -> bool:
	var atlas := get_cell_atlas_coords(0, cell)
	if atlas.x < 0:
		return true  # fuera del mapa cuenta como sólido
	return SOLID.has(atlas.x)


func is_solid(global_pos: Vector2) -> bool:
	return is_solid_cell(cell_at(global_pos))


func set_char_at_cell(cell: Vector2i, ch: String) -> void:
	if not CHAR_TO_TILE.has(ch):
		return
	set_cell(0, cell, SOURCE_ID, Vector2i(int(CHAR_TO_TILE[ch]), 0))
	_modified[_key(cell)] = ch


# --- Guardado ---

func modified_to_dict() -> Dictionary:
	return _modified.duplicate()


func apply_modified(data: Dictionary) -> void:
	for key in data.keys():
		var cell := _cell_from_key(str(key))
		var ch := str(data[key])
		if CHAR_TO_TILE.has(ch):
			set_cell(0, cell, SOURCE_ID, Vector2i(int(CHAR_TO_TILE[ch]), 0))
			_modified[str(key)] = ch


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
