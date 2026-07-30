extends Node2D
## Modo construcción (tecla B). Muestra un fantasma en la celda que apuntás con
## el mouse: verde si podés construir ahí, rojo si no. Clic izquierdo coloca una
## barricada gastando madera; clic derecho la saca y te devuelve una madera.
##
## Las barricadas son StaticBody2D en la capa de colisión 1, o sea que frenan a
## los zombies y además les tapan la visión (su raycast apunta a esa capa).

signal mode_changed(active: bool)
signal build_message(text: String)

## Lo que se puede construir. Agregar uno nuevo es solo sumar una entrada acá.
const BUILDABLES := [
	{
		"id": "barricada",
		"nombre": "Barricada",
		"escena": "res://scenes/Barricade.tscn",
		"costo": 2,
		"color": Color(0.55, 0.38, 0.2, 0.5),
	},
	{
		"id": "fogata",
		"nombre": "Fogata",
		"escena": "res://scenes/Campfire.tscn",
		"costo": 5,
		"color": Color(1.0, 0.6, 0.2, 0.5),
	},
]

const COST_ITEM := "madera"
const REFUND_RATIO := 0.5
const MAX_RANGE := 96.0

var active := false
var selected := 0

var _scenes: Array[PackedScene] = []
var _ghost: Polygon2D
## celda "x,y" -> { "nodo": Node, "tipo": String }
var _placed: Dictionary = {}


func _ready() -> void:
	add_to_group("build_system")
	for entry in BUILDABLES:
		_scenes.append(load(str(entry["escena"])))
	_ghost = _make_ghost()
	add_child(_ghost)
	_ghost.visible = false


func _current() -> Dictionary:
	return BUILDABLES[clampi(selected, 0, BUILDABLES.size() - 1)]


func _cost() -> int:
	return int(_current()["costo"])


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
	var world = _world()
	if world == null:
		return
	_ghost.global_position = world.center_of(cell)
	if _can_build(cell):
		_ghost.color = _current()["color"]
	else:
		_ghost.color = Color(1.0, 0.3, 0.3, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if not active:
		return

	# Números para elegir qué construir.
	if event is InputEventKey and event.pressed and not event.echo:
		var index := event.keycode - KEY_1
		if index >= 0 and index < BUILDABLES.size():
			select(index)
			get_viewport().set_input_as_handled()
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


func select(index: int) -> void:
	selected = clampi(index, 0, BUILDABLES.size() - 1)
	build_message.emit("Construir: %s (%d madera)" % [str(_current()["nombre"]), _cost()])


func set_active(value: bool) -> void:
	active = value
	_ghost.visible = value
	mode_changed.emit(active)
	if not active:
		build_message.emit("Modo construcción OFF")
		return

	# Que no queden dos paneles peleándose por las teclas de números.
	var crafting = get_tree().get_first_node_in_group("crafting")
	if crafting != null and crafting.visible:
		crafting.visible = false

	var options: Array[String] = []
	for i in range(BUILDABLES.size()):
		options.append("%d) %s (%d)" % [i + 1, str(BUILDABLES[i]["nombre"]), int(BUILDABLES[i]["costo"])])
	build_message.emit("Construcción ON — " + " · ".join(options) + " · clic izq: poner, der: sacar")


func _hovered_cell() -> Vector2i:
	var world = _world()
	if world == null:
		return Vector2i.ZERO
	return world.cell_at(get_global_mouse_position())


func _can_build(cell: Vector2i) -> bool:
	var world = _world()
	var player = _player()
	if world == null or player == null:
		return false
	if _placed.has(_key(cell)):
		return false
	if world.is_solid_cell(cell):
		return false
	if world.center_of(cell).distance_to(player.global_position) > MAX_RANGE:
		return false
	return player.inventory.has(COST_ITEM, _cost())


func _try_place(cell: Vector2i) -> void:
	var player = _player()
	var world = _world()
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
	if not player.inventory.remove(COST_ITEM, _cost()):
		build_message.emit("Te falta madera (necesitás %d)" % _cost())
		return

	var entry := _current()
	_spawn_at(cell, str(entry["id"]))
	if str(entry["id"]) == "fogata":
		build_message.emit("Fogata armada — apretá E para prenderla")
	else:
		build_message.emit("%s construida" % str(entry["nombre"]))


func _try_remove(cell: Vector2i) -> void:
	var key := _key(cell)
	if not _placed.has(key):
		return

	var record: Dictionary = _placed[key]
	var node = record.get("nodo")
	var type_id := str(record.get("tipo", "barricada"))
	_placed.erase(key)
	if is_instance_valid(node):
		node.queue_free()

	# Devolvemos la mitad de lo que costó (redondeando para abajo, mínimo 1).
	var refund := maxi(1, int(floor(_cost_of(type_id) * REFUND_RATIO)))
	var player = _player()
	if player != null:
		player.inventory.add(COST_ITEM, refund)
	build_message.emit("Desarmaste %s (+%d madera)" % [_name_of(type_id), refund])


func _entry_of(type_id: String) -> Dictionary:
	for entry in BUILDABLES:
		if str(entry["id"]) == type_id:
			return entry
	return BUILDABLES[0]


func _cost_of(type_id: String) -> int:
	return int(_entry_of(type_id)["costo"])


func _name_of(type_id: String) -> String:
	return str(_entry_of(type_id)["nombre"])


## Devuelve el nodo creado (o null) para que quien lo llame pueda restaurarle
## el estado al cargar una partida.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _spawn_at(cell: Vector2i, type_id: String):
	var world = _world()
	if world == null:
		return null

	var index := 0
	for i in range(BUILDABLES.size()):
		if str(BUILDABLES[i]["id"]) == type_id:
			index = i
			break
	if index >= _scenes.size() or _scenes[index] == null:
		return null

	# Sin ":=" : instantiate() devuelve Node y le seteamos global_position.
	var node = _scenes[index].instantiate()
	node.global_position = world.center_of(cell)
	_structures().add_child(node)
	_placed[_key(cell)] = {"nodo": node, "tipo": type_id}
	return node


# --- Guardado ---

## Devuelve [{ "celda": "x,y", "tipo": "fogata", "estado": {...} }, ...].
## El "estado" solo aparece en las estructuras que tienen algo que recordar
## (por ahora las fogatas: si están prendidas y cuánto combustible les queda).
func placed_cells() -> Array:
	var out: Array = []
	for key in _placed.keys():
		var record: Dictionary = _placed[key]
		var entry := {"celda": str(key), "tipo": str(record.get("tipo", "barricada"))}
		var node = record.get("nodo")
		if is_instance_valid(node) and node.has_method("to_dict"):
			entry["estado"] = node.to_dict()
		out.append(entry)
	return out


## Acepta el formato nuevo [{celda, tipo}] y también el viejo ["x,y", ...] de
## partidas guardadas antes de que existieran las fogatas.
func load_cells(entries: Array) -> void:
	for raw in entries:
		var cell_key := ""
		var type_id := "barricada"
		var state := {}
		if typeof(raw) == TYPE_DICTIONARY:
			cell_key = str(raw.get("celda", ""))
			type_id = str(raw.get("tipo", "barricada"))
			var saved: Variant = raw.get("estado", {})
			if typeof(saved) == TYPE_DICTIONARY:
				state = saved
		else:
			cell_key = str(raw)
		if cell_key == "":
			continue

		var cell := _cell_from_key(cell_key)
		if _placed.has(_key(cell)):
			continue
		var node = _spawn_at(cell, type_id)
		if node != null and not state.is_empty() and node.has_method("from_dict"):
			node.from_dict(state)


func clear_all() -> void:
	for key in _placed.keys():
		var record: Dictionary = _placed[key]
		var node = record.get("nodo")
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
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")


# Sin tipo de retorno a propósito: le pedimos al jugador propiedades (inventory)
# que no existen en Node2D y GDScript valida los tipos estáticos al compilar.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")


func _structures() -> Node:
	var s := get_tree().get_first_node_in_group("structures")
	return s if s != null else self
