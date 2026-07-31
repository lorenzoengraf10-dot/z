extends CanvasLayer
## Mapa del mundo (tecla M). Dibuja el terreno real, celda por celda, leyendo el
## TileMap: si talaste un árbol o picaste una roca, el mapa lo refleja.
##
## Arranca **tapado**. Se va destapando solo con lo que caminaste, así que con el
## spawn al azar de cada partida el mapa es lo que te dice dónde estás parado y
## qué exploraste. El perk "Explorador" destapa los edificios desde el arranque
## (no el terreno: solo dónde hay algo que saquear).
##
## Se dibuja en dos capas: una imagen del terreno (un píxel por celda, escalada
## con filtro nearest para que se vea pixelada) y encima un Control que pinta los
## marcadores, que se mueven todo el tiempo.

## Color de cada carácter del mapa ASCII.
const COLORS := {
	".": Color(0.22, 0.35, 0.18),   # pasto
	"=": Color(0.45, 0.41, 0.32),   # camino
	"~": Color(0.16, 0.30, 0.48),   # agua
	"T": Color(0.13, 0.26, 0.14),   # árbol
	"#": Color(0.55, 0.34, 0.28),   # pared
	",": Color(0.42, 0.32, 0.20),   # piso
	"R": Color(0.42, 0.42, 0.44),   # roca
	"O": Color(0.62, 0.55, 0.30),   # veta de metal
	"D": Color(0.85, 0.72, 0.32),   # puerta
}
## Lo que cuenta como edificio para el perk "Explorador".
const BUILDING := {"#": true, ",": true, "D": true}

const UNKNOWN := Color(0.07, 0.08, 0.07)
## Los edificios que te destapa el perk se ven apagados: sabés que están, pero
## no qué hay alrededor.
const HINT := Color(0.30, 0.24, 0.20)

## Hasta dónde destapás mapa caminando, en celdas.
@export var reveal_radius := 9
## Cada cuánto se marca lo explorado (no hace falta cada frame).
@export var reveal_seconds := 0.35
## Cuánto ocupa cada celda en pantalla, en píxeles. Se recorta si no entra.
@export var max_cell_pixels := 8

var _seen: Dictionary = {}          ## "x,y" -> true
var _reveal_timer := 0.0
var _bounds := Rect2i()
var _cell_pixels := 4.0

@onready var _title: Label = $Title
@onready var _terrain: TextureRect = $Terrain
@onready var _markers: Control = $Markers


func _ready() -> void:
	add_to_group("map_screen")
	layer = 7
	# Tiene que seguir andando con el juego pausado, si no no redibuja nada.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sin esto el TextureRect no deja achicar/agrandar la imagen a mano.
	_terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_terrain.stretch_mode = TextureRect.STRETCH_SCALE
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	visible = false


func _process(delta: float) -> void:
	# Con el mapa abierto el juego está en pausa: ahí no se destapa nada nuevo.
	if not visible:
		_reveal_timer -= delta
		if _reveal_timer <= 0.0:
			_reveal_timer = reveal_seconds
			_reveal_around_player()
	else:
		_markers.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	# No abrimos encima de otra pantalla modal: se pisarían la pausa.
	if _other_screen_open():
		return
	visible = true
	get_tree().paused = true
	refresh()


func close() -> void:
	visible = false
	get_tree().paused = false


func _other_screen_open() -> bool:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.help_open():
		return true
	for group in ["fire_minigame", "inventory_screen", "run_summary"]:
		var screen = get_tree().get_first_node_in_group(group)
		if screen == null:
			continue
		if group == "fire_minigame":
			if screen.is_open():
				return true
		elif screen.visible:
			return true
	return false


## Redibuja terreno y marcadores. Se llama al abrir la pantalla.
func refresh() -> void:
	_redraw_terrain()
	_markers.queue_redraw()


# --- Niebla ---

func _reveal_around_player() -> void:
	var world = _world()
	var player = _player()
	if world == null or player == null:
		return
	var center: Vector2i = world.cell_at(player.global_position)
	for dy in range(-reveal_radius, reveal_radius + 1):
		for dx in range(-reveal_radius, reveal_radius + 1):
			if dx * dx + dy * dy > reveal_radius * reveal_radius:
				continue
			_seen["%d,%d" % [center.x + dx, center.y + dy]] = true


## Las usa el minimapa del HUD: así lo explorado y los colores son los mismos en
## las dos pantallas, y no hay dos verdades sobre qué destapaste.
func is_seen(cell: Vector2i) -> bool:
	return _seen.has("%d,%d" % [cell.x, cell.y])


func color_for(ch: String, seen: bool = true) -> Color:
	if not seen:
		return UNKNOWN
	var tint: Color = COLORS.get(ch, UNKNOWN)
	return tint


func explored_ratio() -> float:
	if _bounds.size.x <= 0 or _bounds.size.y <= 0:
		return 0.0
	# Caminando por el borde se marcan celdas de afuera del mapa, así que
	# recortamos: si no, el porcentaje podría pasar de 100.
	return minf(1.0, float(_seen.size()) / float(_bounds.size.x * _bounds.size.y))


# --- Dibujo ---

func _redraw_terrain() -> void:
	var world = _world()
	if world == null:
		_title.text = "Mapa — todavía no hay mundo"
		return

	_bounds = world.bounds()
	if _bounds.size.x <= 0 or _bounds.size.y <= 0:
		_title.text = "Mapa — el mundo está vacío"
		return

	var reveal_buildings := _has_explorer_perk()

	var image := Image.create(_bounds.size.x, _bounds.size.y, false, Image.FORMAT_RGB8)
	for y in range(_bounds.size.y):
		for x in range(_bounds.size.x):
			var cell := Vector2i(_bounds.position.x + x, _bounds.position.y + y)
			var ch: String = world.char_at_cell(cell)
			if _seen.has("%d,%d" % [cell.x, cell.y]):
				# Por una variable tipada: COLORS.get() devuelve Variant.
				var tint: Color = COLORS.get(ch, UNKNOWN)
				image.set_pixel(x, y, tint)
			elif reveal_buildings and BUILDING.has(ch):
				image.set_pixel(x, y, HINT)
			else:
				image.set_pixel(x, y, UNKNOWN)

	_terrain.texture = ImageTexture.create_from_image(image)

	# Escala entera: el mapa se ve pixelado prolijo y nunca se sale de la pantalla.
	var screen := get_viewport().get_visible_rect().size
	var usable := screen - Vector2(60, 110)
	_cell_pixels = maxf(1.0, floorf(minf(
		usable.x / float(_bounds.size.x),
		usable.y / float(_bounds.size.y)
	)))
	_cell_pixels = minf(_cell_pixels, float(max_cell_pixels))

	var map_size := Vector2(_bounds.size) * _cell_pixels
	var origin := ((screen - map_size) * 0.5).floor()
	origin.y = maxf(origin.y, 70.0)
	_terrain.position = origin
	_terrain.size = map_size
	_markers.position = origin

	_title.text = "Mapa — %s · explorado %d%%" % [
		_region_name(), int(round(explored_ratio() * 100.0)),
	]


## Marcadores encima del terreno: vos, y las fogatas prendidas que hayas visto.
func _draw_markers() -> void:
	var world = _world()
	if world == null or _bounds.size.x <= 0:
		return

	for node in get_tree().get_nodes_in_group("campfire"):
		if not (node is Node2D):
			continue
		var fire = node
		if not fire.has_method("is_lit") or not fire.is_lit():
			continue
		_dot(world.cell_at(fire.global_position), Color(1.0, 0.62, 0.20), 2.0)

	var player = _player()
	if player != null:
		var cell: Vector2i = world.cell_at(player.global_position)
		_dot(cell, Color(1.0, 1.0, 1.0), 3.5)
		_dot(cell, Color(0.2, 0.9, 0.3), 2.0)


func _dot(cell: Vector2i, color: Color, radius: float) -> void:
	var local := Vector2(cell - _bounds.position) * _cell_pixels + Vector2.ONE * (_cell_pixels * 0.5)
	_markers.draw_circle(local, radius, color)


func _has_explorer_perk() -> bool:
	var run = get_tree().get_first_node_in_group("run_manager")
	return run != null and run.has_perk("explorador")


## Nombre de la región, solo para el título. Si falta el archivo no pasa nada.
func _region_name() -> String:
	const PATH := "res://data/world_map.json"
	if not FileAccess.file_exists(PATH):
		return "Región sin nombre"
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return "Región sin nombre"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Región sin nombre"
	var data: Dictionary = parsed
	return str(data.get("region_name", "Región sin nombre"))


# --- Guardado de la niebla ---

func to_dict() -> Dictionary:
	return {"visto": _seen.keys()}


func from_dict(data: Dictionary) -> void:
	_seen.clear()
	var seen: Variant = data.get("visto", [])
	if typeof(seen) != TYPE_ARRAY:
		return
	for key in seen:
		_seen[str(key)] = true


# Sin tipar: usamos bounds()/cell_at()/char_at_cell(), propios de world.gd.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")


# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
