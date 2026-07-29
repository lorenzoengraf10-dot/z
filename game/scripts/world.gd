extends TileMap
## Construye el mundo con tiles reales. Para poder trabajar sin abrir el editor,
## el TileSet se arma por código (en vez de un recurso .tres) y el mapa se pinta
## leyendo un archivo de texto editable (data/level_prototype.txt).
##
## Tiles del atlas placeholder (una fila de 5, 16x16 c/u):
##   0 pasto | 1 camino | 2 agua | 3 arbol | 4 pared
## Las tiles sólidas (agua, arbol, pared) colisionan en la capa 1 → frenan al
## jugador/zombie y tapan la visión del zombie (que hace raycast contra esa capa).

const TILE_SIZE := 16
const SOURCE_ID := 0
const TILES_TEXTURE := "res://assets/tiles/placeholder_tiles.png"
const LEVEL_PATH := "res://data/level_prototype.txt"

# Caracter del mapa ASCII -> índice de tile en el atlas.
const CHAR_TO_TILE := {
	".": 0,  # pasto
	"=": 1,  # camino
	"~": 2,  # agua
	"T": 3,  # arbol
	"#": 4,  # pared
}
# Índices de tiles que colisionan (y tapan la visión).
const SOLID := {2: true, 3: true, 4: true}


func _ready() -> void:
	tile_set = _build_tileset()
	_paint_level()


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Capa de física: lo sólido choca en la capa de colisión 1 (el "mundo").
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	var src := TileSetAtlasSource.new()
	src.texture = load(TILES_TEXTURE)
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
	var text := f.get_as_text()
	var result := PackedStringArray()
	for raw in text.split("\n"):
		var ln := raw.rstrip("\r")
		if ln.length() > 0:
			result.append(ln)
	return result
