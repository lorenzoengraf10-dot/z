extends TileMap
## Construye el mundo con tiles reales. Para poder trabajar sin abrir el editor,
## el TileSet se arma por código (en vez de un recurso .tres) y el mapa se pinta
## leyendo un archivo de texto editable (data/level_prototype.txt).
##
## Tiles del atlas placeholder (una fila de 9, 16x16 c/u):
##   0 pasto | 1 camino | 2 agua | 3 arbol | 4 pared
##   5 piso  | 6 roca   | 7 veta | 8 puerta
##
## Pared, roca y veta son sólidas de verdad: colisionan en la capa de física 1
## → frenan a todos los cuerpos (jugador/zombie/lobo/animal) y de paso tapan
## la visión del zombie (su RayCast2D hace mask contra esa misma capa).
##
## El árbol es distinto **a propósito**: se puede atravesar (más lento, ver
## SPEED) pero sigue tapando la vista. Por eso tiene su PROPIA capa de física
## (la 2, bit 16) que ningún cuerpo choca — solo la mira el RayCast2D del
## zombie, que tiene las dos capas en su mask (1|16 = 17). Así el escondite
## sigue funcionando (no te ven) aunque ya no te frene caminar.
##
## El agua y la puerta no bloquean nada: al agua se entra (lento) y la puerta
## la bloquea el nodo Door cuando está cerrada.
##
## Nota: en Godot 4.3+ el nodo TileMap figura como deprecado (lo reemplaza
## TileMapLayer), pero sigue funcionando. Se usa TileMap a propósito para que el
## proyecto abra igual en 4.2 que en versiones más nuevas.

const TILE_SIZE := 16
const SOURCE_ID := 0
## El atlas de respaldo: los 9 tiles de placeholder en una fila.
const TILES_TEXTURE := "res://assets/tiles/placeholder_tiles.png"
## Los tiles de verdad, uno por archivo. Ver docs/ARTE_SPEC.md.
const TILE_ART := "res://assets/tiles/%s.png"
const LEVEL_PATH := "res://data/level_prototype.txt"

const GRASS := "."
const PATH := "="
const WATER := "~"
const TREE := "T"
const WALL := "#"
const FLOOR := ","
const ROCK := "R"
const ORE := "O"
const DOOR := "D"

## Carácter del mapa -> nombre del archivo en assets/tiles/. Es el contrato con
## quien dibuja: si el archivo se llama así, el juego lo usa solo.
const TILE_NAMES := {
	GRASS: "pasto",
	PATH: "camino",
	WATER: "agua",
	TREE: "arbol",
	WALL: "pared",
	FLOOR: "piso",
	ROCK: "roca",
	ORE: "veta",
	DOOR: "puerta",
}

# Caracter del mapa ASCII -> índice de tile en el atlas.
const CHAR_TO_TILE := {
	GRASS: 0,
	PATH: 1,
	WATER: 2,
	TREE: 3,
	WALL: 4,
	FLOOR: 5,
	ROCK: 6,
	ORE: 7,
	DOOR: 8,
}

## Índices de tiles "ocupados": ahí no se puede construir ni spawnear
## (build_system.gd y run_manager.gd/horde_spawner.gd lo consultan vía
## is_solid_cell()/is_solid()). El árbol sigue acá adentro a propósito, aunque
## ya no frene el paso — ver BLOCKS_BODIES más abajo para esa distinción.
## El agua NO está (se camina, solo que lento) y la puerta tampoco (la
## colisión la pone el nodo Door cuando está cerrada).
const SOLID := {3: true, 4: true, 6: true, 7: true}

## De los tiles de SOLID, cuáles chocan de VERDAD contra los cuerpos (capa de
## física 1: jugador, zombie, lobo, animal). El árbol no está: pasa a
## BLOCKS_SIGHT_ONLY, más abajo.
const BLOCKS_BODIES := {4: true, 6: true, 7: true}

## Tiles que tapan la visión del zombie pero NO frenan el paso — hoy solo el
## árbol. Van en una capa de física aparte (ver _build_tileset()).
const BLOCKS_SIGHT_ONLY := {3: true}

## Multiplicador de velocidad por tile (lo que no está acá va a 1.0).
## El árbol ralentiza igual que el agua, pero un poco menos (0.55 vs 0.45):
## cruzar el monte cuesta, pero no tanto como meterse al lago.
const SPEED := {2: 0.45, 3: 0.55}

## Tiles que se pueden picar con el pico, y qué dejan.
const MINEABLE := {ROCK: "piedra", ORE: "metal"}

var _tile_to_char: Dictionary = {}
## Tiles que el jugador modificó (ej. árboles talados). Se guardan en la partida.
var _modified: Dictionary = {}
## Celdas donde el mapa marcó una puerta. Las usa door_system.gd.
var _door_cells: Array[Vector2i] = []
## Rectángulo del mapa en celdas, para que el sistema de techos sepa dónde barrer.
var _bounds := Rect2i()


func _ready() -> void:
	add_to_group("world")
	for ch in CHAR_TO_TILE.keys():
		_tile_to_char[CHAR_TO_TILE[ch]] = ch
	tile_set = _build_tileset()
	_paint_level()
	_build_boundary()


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Capa de física 0: lo sólido de verdad choca en la capa de colisión 1 (el
	# "mundo") — pared, roca, veta. Frena a todos los cuerpos.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	# Capa de física 1: SOLO el árbol. Colisión en la capa 16, que ningún
	# cuerpo choca (jugador/zombie/lobo/animal tienen mask sin ese bit) — la
	# usa nada más el RayCast2D de visión del zombie, que sí la incluye en su
	# mask. Así el árbol tapa la vista pero no frena el paso.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 16)

	var src := TileSetAtlasSource.new()
	src.texture = _build_atlas()
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# ⚠ EL ORDEN DE ESTAS LÍNEAS IMPORTA Y NO SE ADIVINA LEYENDO EL CÓDIGO.
	#
	# El source va al TileSet ANTES de crear los tiles. Cada TileData copia las
	# capas de física del TileSet recién cuando se entera de a qué TileSet
	# pertenece, y eso pasa adentro de add_source(). Si creás la colisión antes,
	# el tile todavía tiene CERO capas de física y add_collision_polygon(0) se va
	# por un ERR_FAIL_INDEX: tira error al panel Salida y no crea nada.
	#
	# Con eso, NINGÚN tile del mapa colisiona: ni paredes, ni árboles, ni rocas.
	# Fue exactamente el bug de "las paredes no frenan a nadie". Si alguien
	# reordena esto, check_project.py lo caza.
	ts.add_source(src, SOURCE_ID)

	var half := TILE_SIZE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])

	for tile_index in range(CHAR_TO_TILE.size()):
		var coords := Vector2i(tile_index, 0)
		src.create_tile(coords)
		if BLOCKS_BODIES.has(tile_index):
			var data := src.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
		if BLOCKS_SIGHT_ONLY.has(tile_index):
			var data := src.get_tile_data(coords, 0)
			data.add_collision_polygon(1)
			data.set_collision_polygon_points(1, 0, square)

	_verify_collisions(src)
	return ts


## Arma el atlas pegando los PNG sueltos de assets/tiles/.
##
## Cada tile es su propio archivo (`pasto.png`, `arbol.png`...) para que los tres
## puedan dibujar a la vez sin pisarse en git. Acá se juntan en una sola textura
## porque es lo que necesita el TileSet.
##
## El que falte se rellena con el placeholder de siempre, así se puede ir
## reemplazando de a un tile y ver el resultado al toque, sin que el mapa quede
## con agujeros mientras tanto.
func _build_atlas() -> Texture2D:
	var fallback := load(TILES_TEXTURE) as Texture2D
	var base: Image = null
	if fallback != null:
		base = _listo_para_pegar(fallback.get_image())

	var total := CHAR_TO_TILE.size()
	var atlas := Image.create(TILE_SIZE * total, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var cuadro := Rect2i(0, 0, TILE_SIZE, TILE_SIZE)
	var propios := 0

	for ch in CHAR_TO_TILE.keys():
		var index: int = CHAR_TO_TILE[ch]
		var destino := Vector2i(index * TILE_SIZE, 0)
		var nombre: String = TILE_NAMES.get(ch, "")
		var path := TILE_ART % nombre

		if nombre != "" and ResourceLoader.exists(path):
			var art := load(path) as Texture2D
			if art != null:
				var image := _listo_para_pegar(art.get_image())
				if image.get_width() == TILE_SIZE and image.get_height() == TILE_SIZE:
					atlas.blit_rect(image, cuadro, destino)
					propios += 1
					continue
				push_warning("world.gd: %s mide %dx%d y tiene que ser %dx%d; se usa el placeholder"
						% [path, image.get_width(), image.get_height(), TILE_SIZE, TILE_SIZE])

		# Sin arte (o con el tamaño mal): va el placeholder.
		if base != null:
			atlas.blit_rect(base, Rect2i(destino.x, 0, TILE_SIZE, TILE_SIZE), destino)

	if propios > 0:
		print("world.gd: %d de %d tiles con arte propio" % [propios, total])
	_verify_atlas(atlas)
	return ImageTexture.create_from_image(atlas)


## Deja una imagen lista para blit_rect().
##
## ⚠ ACÁ ESTUVO EL BUG DE "NO SE VE NADA DEL MAPA", NO BORRAR LA CONVERSIÓN.
##
## blit_rect() exige que las dos imágenes tengan **el mismo formato**: si no
## coinciden, no copia nada y no tira excepción, solo un error en el panel
## Salida. El atlas se crea RGBA8 y el placeholder era RGB8 (sin alpha), así que
## no se pegaba ni un tile: el mapa entero quedaba transparente y se veía el
## fondo de Main.tscn. El juego abría igual, por eso no se notaba de entrada.
func _listo_para_pegar(image: Image) -> Image:
	if image == null:
		return null
	# Según cómo Godot importe el PNG, get_image() puede devolverlo comprimido,
	# y convert() no funciona sobre un formato comprimido.
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


## Comprueba que en el atlas haya quedado algo dibujado en cada tile.
##
## Existe por el mismo motivo que _verify_collisions(): el bug fallaba EN
## SILENCIO. El juego abría, no había excepción, y recién te dabas cuenta al ver
## que la pantalla era un color plano.
func _verify_atlas(atlas: Image) -> void:
	var vacios: Array[String] = []
	for ch in CHAR_TO_TILE.keys():
		var index: int = CHAR_TO_TILE[ch]
		var pintado := false
		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				if atlas.get_pixel(index * TILE_SIZE + x, y).a > 0.0:
					pintado = true
					break
			if pintado:
				break
		if not pintado:
			vacios.append("%s (%s)" % [str(ch), str(TILE_NAMES.get(ch, "?"))])

	if vacios.is_empty():
		print("world.gd: %d de %d tiles con atlas OK" % [CHAR_TO_TILE.size(), CHAR_TO_TILE.size()])
		return
	push_error("world.gd: estos tiles quedaron TRANSPARENTES y el mapa se va a ver " +
			"como un color plano: %s — revisá _listo_para_pegar() en _build_atlas()"
			% ", ".join(vacios))


## Comprueba que los tiles sólidos (y el árbol, que tapa la vista sin frenar
## el paso) hayan quedado realmente con colisión en la capa que corresponde.
##
## Existe porque el bug de arriba falla EN SILENCIO: el juego abre igual, se ve
## igual, y recién te das cuenta cuando cruzás una pared caminando (o cuando un
## zombie te ve a través de un árbol). Mejor que avise al arrancar.
func _verify_collisions(src: TileSetAtlasSource) -> void:
	var sin_colision: Array[String] = []
	for tile_index in BLOCKS_BODIES.keys():
		var data := src.get_tile_data(Vector2i(int(tile_index), 0), 0)
		if data == null or data.get_collision_polygons_count(0) == 0:
			sin_colision.append("%s (tile %d, capa 0)" % [_tile_to_char.get(tile_index, "?"), tile_index])
	for tile_index in BLOCKS_SIGHT_ONLY.keys():
		var data := src.get_tile_data(Vector2i(int(tile_index), 0), 0)
		if data == null or data.get_collision_polygons_count(1) == 0:
			sin_colision.append("%s (tile %d, capa 1 — tapar vista)" % [_tile_to_char.get(tile_index, "?"), tile_index])

	if sin_colision.is_empty():
		print("world.gd: %d tiles sólidos + %d que tapan vista, colisión OK"
				% [BLOCKS_BODIES.size(), BLOCKS_SIGHT_ONLY.size()])
		return
	# Un solo string literal, no dos con "+": el % de formato ata más fuerte
	# que el "+" y aplicarlo sobre dos strings pegados es justo el tipo de
	# trampa que este mismo archivo advierte en otros comentarios.
	push_error("world.gd: estos tiles quedaron SIN colisión: %s — revisá el orden de add_source() en _build_tileset()"
			% ", ".join(sin_colision))


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
	_bounds = Rect2i(Vector2i(-off_x, -off_y), Vector2i(w, h))
	_door_cells.clear()

	for row in range(h):
		var line: String = lines[row]
		for col in range(line.length()):
			var ch := line[col]
			var tile_index: int = CHAR_TO_TILE.get(ch, 0)
			var cell := Vector2i(col - off_x, row - off_y)
			set_cell(0, cell, SOURCE_ID, Vector2i(tile_index, 0))
			if ch == DOOR:
				_door_cells.append(cell)


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


## Paredes invisibles pegadas al borde del mapa.
##
## El mapa ya tiene un anillo de árboles, pero cualquier retoque puede abrirlo:
## le pasó a la costa oeste, que se dibujaba DESPUÉS del anillo y se lo comía
## entero, así que se podía salir nadando al vacío. Esto lo cierra por código,
## pase lo que pase con el dibujo.
##
## Frena a todo lo que enmascare la capa 1: jugador, zombies, lobos y animales.
func _build_boundary() -> void:
	if _bounds.size.x <= 0 or _bounds.size.y <= 0:
		return

	var body := StaticBody2D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var thick := float(TILE_SIZE) * 2.0
	var origin := Vector2(_bounds.position) * float(TILE_SIZE)
	var span := Vector2(_bounds.size) * float(TILE_SIZE)

	# Cada pared se pasa de largo en las esquinas, para no dejar rendijas.
	var walls := [
		{  # arriba
			"pos": Vector2(origin.x + span.x * 0.5, origin.y - thick * 0.5),
			"size": Vector2(span.x + thick * 2.0, thick),
		},
		{  # abajo
			"pos": Vector2(origin.x + span.x * 0.5, origin.y + span.y + thick * 0.5),
			"size": Vector2(span.x + thick * 2.0, thick),
		},
		{  # izquierda
			"pos": Vector2(origin.x - thick * 0.5, origin.y + span.y * 0.5),
			"size": Vector2(thick, span.y + thick * 2.0),
		},
		{  # derecha
			"pos": Vector2(origin.x + span.x + thick * 0.5, origin.y + span.y * 0.5),
			"size": Vector2(thick, span.y + thick * 2.0),
		},
	]

	for wall in walls:
		var wall_size: Vector2 = wall["size"]
		var wall_pos: Vector2 = wall["pos"]
		var shape := RectangleShape2D.new()
		shape.size = wall_size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = wall_pos
		body.add_child(collider)


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


## ¿Esta celda es el piso de una casa que ya venía dibujada en el mapa?
##
## Es lo que usa build_system.gd para no dejarte construir adentro de las casas
## prediseñadas: si se pudiera, ocupar una casa y equiparla entera (mesa, fogata,
## cofre) sería siempre mejor que armarse un refugio propio, y construir dejaría
## de tener sentido.
##
## Está acá y no suelto en build_system.gd para que el literal "," viva en un
## solo lugar, al lado del resto de los caracteres del mapa.
func is_map_floor(cell: Vector2i) -> bool:
	return char_at_cell(cell) == FLOOR


## Cuánto frena el terreno en esa posición (1.0 = normal, 0.45 = agua).
func speed_at(global_pos: Vector2) -> float:
	var atlas := get_cell_atlas_coords(0, cell_at(global_pos))
	if atlas.x < 0:
		return 1.0
	return float(SPEED.get(atlas.x, 1.0))


## Si el tile se puede minar, devuelve el ítem que da; si no, "".
func mineable_at(cell: Vector2i) -> String:
	return str(MINEABLE.get(char_at_cell(cell), ""))


## Celdas marcadas como puerta en el mapa. Las usa door_system.gd.
func door_cells() -> Array[Vector2i]:
	return _door_cells.duplicate()


## Rectángulo del mapa en celdas. Lo usa roof_system.gd para barrer el mapa.
func bounds() -> Rect2i:
	return _bounds


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
