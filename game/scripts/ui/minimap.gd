extends CanvasLayer
## Minimapa fijo en una esquina.
##
## Con el mapa de 160×100 y el spawn al azar, abrir la M cada treinta segundos
## para saber dónde estás parado es un bajón. Esto muestra el pedacito de
## alrededor sin cortar la partida.
##
## Respeta la **niebla**: solo se ve lo que ya caminaste. La niebla es la misma
## que la del mapa grande (se la pregunta a `map_screen.gd`), así no hay dos
## verdades sobre qué destapaste.
##
## Los enemigos aparecen **solo cuando ya te detectaron**. Marcar todos sería
## regalarte el sigilo; marcar los que ya te vienen a buscar solo te dice de qué
## lado, que es lo que necesitás para decidir para dónde correr.

## Cuántas celdas se ven a cada lado tuyo.
@export var radius := 20
## Cuántos píxeles de pantalla ocupa cada celda.
@export var cell_pixels := 4
## Cada cuánto se redibuja el terreno (los puntos van cada frame).
@export var refresh_seconds := 0.35

const MARGIN := 12

var _terrain: TextureRect
var _dots: Control
var _frame: Panel
var _timer := 0.0
var _center := Vector2i.ZERO
var _map_screen = null


func _ready() -> void:
	add_to_group("minimap")
	layer = 3
	_build_ui()


func _build_ui() -> void:
	var side := (radius * 2 + 1) * cell_pixels

	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.anchor_left = 1.0
	_frame.anchor_right = 1.0
	_frame.anchor_top = 1.0
	_frame.anchor_bottom = 1.0
	_frame.offset_left = -side - MARGIN - 4
	_frame.offset_right = -MARGIN + 4
	_frame.offset_top = -side - MARGIN - 4
	_frame.offset_bottom = -MARGIN + 4
	add_child(_frame)

	_terrain = TextureRect.new()
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_terrain.stretch_mode = TextureRect.STRETCH_SCALE
	_terrain.position = Vector2(4, 4)
	_terrain.size = Vector2(side, side)
	_frame.add_child(_terrain)

	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.position = Vector2(4, 4)
	_dots.size = Vector2(side, side)
	_dots.draw.connect(_draw_dots)
	_frame.add_child(_dots)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = refresh_seconds
		_redraw_terrain()
	_dots.queue_redraw()


func _redraw_terrain() -> void:
	var world = _world()
	var player = _player()
	if world == null or player == null:
		return
	if _map_screen == null or not is_instance_valid(_map_screen):
		_map_screen = get_tree().get_first_node_in_group("map_screen")

	_center = world.cell_at(player.global_position)
	var side := radius * 2 + 1
	var image := Image.create(side, side, false, Image.FORMAT_RGB8)

	for y in range(side):
		for x in range(side):
			var cell := Vector2i(_center.x - radius + x, _center.y - radius + y)
			var seen := true
			if _map_screen != null:
				seen = _map_screen.is_seen(cell)
			var ch: String = world.char_at_cell(cell)
			var tint := Color(0.06, 0.07, 0.06)
			if _map_screen != null:
				tint = _map_screen.color_for(ch, seen)
			elif ch != "":
				tint = Color(0.25, 0.35, 0.20)
			image.set_pixel(x, y, tint)

	_terrain.texture = ImageTexture.create_from_image(image)


## Vos en el medio, y los enemigos que ya te tienen fichado.
func _draw_dots() -> void:
	var world = _world()
	if world == null:
		return

	var half := float(cell_pixels) * 0.5
	var middle := Vector2(radius, radius) * float(cell_pixels) + Vector2(half, half)

	for node in get_tree().get_nodes_in_group("hunter"):
		var hunter = node
		if not hunter.has_method("alert_level") or int(hunter.alert_level()) < 2:
			continue
		var cell: Vector2i = world.cell_at(hunter.global_position)
		var delta := cell - _center
		if absi(delta.x) > radius or absi(delta.y) > radius:
			continue
		var point := Vector2(delta + Vector2i(radius, radius)) * float(cell_pixels)
		_dots.draw_circle(point + Vector2(half, half), 2.5, Color(0.95, 0.25, 0.25))

	_dots.draw_circle(middle, 3.5, Color(1, 1, 1))
	_dots.draw_circle(middle, 2.0, Color(0.25, 0.92, 0.40))


# Sin tipar: usamos cell_at()/char_at_cell(), propios de world.gd.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")


# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
