extends Node2D
## Modo construcción (tecla B). Muestra un fantasma en la celda que apuntás con
## el mouse: verde si podés construir ahí, rojo si no. Clic izquierdo coloca una
## barricada gastando madera; clic derecho la saca y te devuelve una madera.
##
## Las barricadas son StaticBody2D en la capa de colisión 1, o sea que frenan a
## los zombies y además les tapan la visión (su raycast apunta a esa capa).

signal mode_changed(active: bool)
signal build_message(text: String)

const BARRICADE_SCENE := "res://scenes/Barricade.tscn"
const COST_ITEM := "madera"
const COST_AMOUNT := 2
const REFUND_AMOUNT := 1
const MAX_RANGE := 96.0

var active := false

var _barricade: PackedScene
var _ghost: Polygon2D
## celda "x,y" -> nodo de la estructura
var _placed: Dictionary = {}


func _ready() -> void:
	add_to_group("build_system")
	_barricade = load(BARRICADE_SCENE)
	_ghost = _make_ghost()
	add_child(_ghost)
	_ghost.visible = false


func _make_ghost() -> Polygon2D:
	var g := Polygon2D.new()
	g.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	g.color = Color(1, 1, 1, 0.45)
	g.z_index = 10
	return g


func _process(_delta: float) -> void:
	if not active:
		return
	var cell := _hovered_cell()
	var world := _world()
	if world == null:
		return
	_ghost.global_position = world.center_of(cell)
	_ghost.color = Color(0.3, 1.0, 0.4, 0.45) if _can_build(cell) else Color(1.0, 0.3, 0.3, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if not active:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place(_hovered_cell())
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_remove(_hovered_cell())
			get_viewport().set_input_as_handled()


func toggle() -> void:
	set_active(not active)


func set_active(value: bool) -> void:
	active = value
	_ghost.visible = value
	mode_changed.emit(active)
	if active:
		build_message.emit("Modo construcción ON — clic izq: barricada (%d madera) · clic der: sacar" % COST_AMOUNT)
	else:
		build_message.emit("Modo construcción OFF")


func _hovered_cell() -> Vector2i:
	var world := _world()
	if world == null:
		return Vector2i.ZERO
	return world.cell_at(get_global_mouse_position())


func _can_build(cell: Vector2i) -> bool:
	var world := _world()
	var player := _player()
	if world == null or player == null:
		return false
	if _placed.has(_key(cell)):
		return false
	if world.is_solid_cell(cell):
		return false
	if world.center_of(cell).distance_to(player.global_position) > MAX_RANGE:
		return false
	return player.inventory.has(COST_ITEM, COST_AMOUNT)


func _try_place(cell: Vector2i) -> void:
	var player := _player()
	var world := _world()
	if player == null or world == null:
		return

	if _placed.has(_key(cell)):
		build_message.emit("Ya hay algo construido ahí")
		return
	if world.is_solid_cell(cell):
		build_message.emit("No se puede construir sobre agua, árboles o paredes")
		return
	if world.center_of(cell).distance_to(player.global_position) > MAX_RANGE:
		build_message.emit("Demasiado lejos")
		return
	if not player.inventory.remove(COST_ITEM, COST_AMOUNT):
		build_message.emit("Te falta madera (necesitás %d)" % COST_AMOUNT)
		return

	_spawn_at(cell)
	build_message.emit("Barricada construida")


func _try_remove(cell: Vector2i) -> void:
	var key := _key(cell)
	if not _placed.has(key):
		return
	var node: Node = _placed[key]
	_placed.erase(key)
	if is_instance_valid(node):
		node.queue_free()
	var player := _player()
	if player != null:
		player.inventory.add(COST_ITEM, REFUND_AMOUNT)
	build_message.emit("Barricada desarmada (+%d madera)" % REFUND_AMOUNT)


func _spawn_at(cell: Vector2i) -> void:
	var world := _world()
	if world == null or _barricade == null:
		return
	var node := _barricade.instantiate()
	node.global_position = world.center_of(cell)
	_structures().add_child(node)
	_placed[_key(cell)] = node


# --- Guardado ---

func placed_cells() -> Array:
	return _placed.keys()


func load_cells(keys: Array) -> void:
	for key in keys:
		var cell := _cell_from_key(str(key))
		if not _placed.has(_key(cell)):
			_spawn_at(cell)


func clear_all() -> void:
	for key in _placed.keys():
		var node: Node = _placed[key]
		if is_instance_valid(node):
			node.queue_free()
	_placed.clear()


# --- Helpers ---

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


# Sin tipar: usamos cell_at/center_of/is_solid_cell, propios de world.gd.
func _world():
	return get_tree().get_first_node_in_group("world")


# Sin tipo de retorno a propósito: le pedimos al jugador propiedades (inventory)
# que no existen en Node2D y GDScript valida los tipos estáticos al compilar.
func _player():
	return get_tree().get_first_node_in_group("player")


func _structures() -> Node:
	var s := get_tree().get_first_node_in_group("structures")
	return s if s != null else self
