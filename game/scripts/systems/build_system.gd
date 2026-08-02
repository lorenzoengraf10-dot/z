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
##
## "costo" es un **diccionario** {item: cantidad}, igual que el "cuesta" de
## data/recipes.json. Antes era un número suelto y todo costaba madera: con
## muros de piedra y de metal eso ya no alcanzaba, y unificar el formato con el
## de las recetas evita tener dos formas distintas de decir lo mismo.
const BUILDABLES := [
	{
		# El id sigue siendo "barricada" y NO se renombra aunque ahora se llame
		# "Muro de madera": load_cells() usa ese id como valor por defecto para
		# las partidas guardadas viejas, así que cambiarlo las rompería.
		"id": "barricada",
		"nombre": "Muro de madera",
		"escena": "res://scenes/Barricade.tscn",
		"costo": {"madera": 2},
		"color": Color(0.55, 0.38, 0.2, 0.5),
	},
	{
		"id": "muro_piedra",
		"nombre": "Muro de piedra",
		"escena": "res://scenes/WallStone.tscn",
		"costo": {"piedra": 3},
		"color": Color(0.45, 0.43, 0.4, 0.5),
	},
	{
		"id": "muro_metal",
		"nombre": "Muro de metal",
		"escena": "res://scenes/WallMetal.tscn",
		"costo": {"metal": 2, "tabla": 1},
		"color": Color(0.45, 0.47, 0.5, 0.5),
	},
	{
		"id": "fogata",
		"nombre": "Fogata",
		"escena": "res://scenes/Campfire.tscn",
		"costo": {"madera": 5},
		"color": Color(1.0, 0.6, 0.2, 0.5),
	},
	{
		"id": "mesa",
		"nombre": "Mesa de trabajo",
		"escena": "res://scenes/Workbench.tscn",
		# Era 8 (3 árboles enteros) y es la puerta de entrada a 8 de las 11
		# recetas: el testeo la marcó como el cuello de botella más caro del
		# arranque. -15% ~ 6.8, redondeado para abajo a 6.
		"costo": {"madera": 6},
		"color": Color(0.65, 0.5, 0.25, 0.5),
	},
	{
		"id": "cofre",
		"nombre": "Cofre",
		"escena": "res://scenes/Chest.tscn",
		"costo": {"madera": 5},
		"color": Color(0.5, 0.35, 0.15, 0.5),
	},
]

const REFUND_RATIO := 0.5
const MAX_RANGE := 96.0

var active := false
var selected := 0

var _scenes: Array[PackedScene] = []
var _ghost: Polygon2D
var _palette: CanvasLayer
var _palette_buttons: Array[Button] = []
## celda "x,y" -> { "nodo": Node, "tipo": String }
var _placed: Dictionary = {}


func _ready() -> void:
	add_to_group("build_system")
	for entry in BUILDABLES:
		# load() devuelve Resource: sin el cast no entra en un Array[PackedScene].
		_scenes.append(load(str(entry["escena"])) as PackedScene)
	_ghost = _make_ghost()
	add_child(_ghost)
	_ghost.visible = false
	_build_palette()
	# Las estructuras que ya vienen puestas en la escena (la fogata de prueba
	# cerca del spawn) se registran igual que las construidas: si no, no se
	# guardaban ni se podían desarmar.
	_register_preplaced.call_deferred()


## Panel de construcción: se muestra al entrar en modo construcción y deja
## elegir qué poner con el mouse (o con los números).
func _build_palette() -> void:
	_palette = CanvasLayer.new()
	_palette.layer = 4
	add_child(_palette)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -104
	panel.offset_bottom = -46
	_palette.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	for i in range(BUILDABLES.size()):
		var entry: Dictionary = BUILDABLES[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%d) %s\n%s" % [i + 1, str(entry["nombre"]), _cost_text(entry["costo"])]
		button.pressed.connect(select.bind(i))
		row.add_child(button)
		_palette_buttons.append(button)

	_palette.visible = false


## Marca cuál está elegido y si te alcanza la madera.
func _refresh_palette() -> void:
	var player = _player()
	for i in range(_palette_buttons.size()):
		var button := _palette_buttons[i]
		var affordable := _can_afford(player, BUILDABLES[i]["costo"])
		if i == selected:
			button.modulate = Color(1, 1, 1) if affordable else Color(1.0, 0.6, 0.6)
		else:
			button.modulate = Color(0.62, 0.62, 0.66)


## Adopta lo que ya estaba colgado del nodo Structures al arrancar.
func _register_preplaced() -> void:
	var world = _world()
	if world == null:
		return
	# get_children() devuelve Array[Node]: pasamos cada uno a una variable sin
	# tipo para poder pedirle global_position.
	for raw in _structures().get_children():
		if raw == _ghost or not (raw is Node2D):
			continue
		var child = raw
		var cell: Vector2i = world.cell_at(child.global_position)
		var key := _key(cell)
		if _placed.has(key):
			continue
		var type_id := "fogata" if child.is_in_group("campfire") else "barricada"
		_placed[key] = {"nodo": child, "tipo": type_id}


func _current() -> Dictionary:
	return BUILDABLES[clampi(selected, 0, BUILDABLES.size() - 1)]


func _cost() -> Dictionary:
	return _current()["costo"]


## ¿Tenés todo lo que pide este costo?
func _can_afford(player, costo: Dictionary) -> bool:
	if player == null:
		return false
	for item in costo:
		if not player.inventory.has(str(item), int(costo[item])):
			return false
	return true


## Cobra el costo entero, o no cobra nada. Nunca a medias: sin el chequeo previo
## te podría sacar la piedra y después fallar al sacar el metal.
func _pay(player, costo: Dictionary) -> bool:
	if not _can_afford(player, costo):
		return false
	for item in costo:
		player.inventory.remove(str(item), int(costo[item]))
	return true


## "2 madera" / "2 metal + 1 tabla", para los botones y los mensajes.
func _cost_text(costo: Dictionary) -> String:
	var partes: Array[String] = []
	for item in costo:
		partes.append("%d %s" % [int(costo[item]), ItemDB.display_name(str(item))])
	return " + ".join(partes)


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
	_refresh_palette()


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
	_refresh_palette()
	build_message.emit("Construir: %s (%d madera)" % [str(_current()["nombre"]), _cost()])


func set_active(value: bool) -> void:
	active = value
	_ghost.visible = value
	_palette.visible = value
	mode_changed.emit(active)
	if not active:
		build_message.emit("Modo construcción OFF")
		return

	# Que no queden dos paneles peleándose por las teclas de números.
	var crafting = get_tree().get_first_node_in_group("crafting")
	if crafting != null and crafting.visible:
		crafting.visible = false

	_refresh_palette()
	build_message.emit("Construcción ON — clic izq: poner · clic der: sacar")


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
	if world.is_map_floor(cell):
		return false
	if world.center_of(cell).distance_to(player.global_position) > MAX_RANGE:
		return false
	return _can_afford(player, _cost())


func _try_place(cell: Vector2i) -> void:
	var player = _player()
	var world = _world()
	if player == null or world == null:
		return

	# Clic sobre algo que ya está: si está dañado, esto es un arreglo, no un
	# intento fallido de construir encima.
	var existente = _structure_at(cell)
	if existente != null:
		_try_repair(existente)
		return
	if _placed.has(_key(cell)):
		build_message.emit("Ya hay algo construido ahí")
		return
	if world.is_solid_cell(cell):
		build_message.emit("No se puede construir sobre agua, árboles o paredes")
		return
	# Adentro de las casas del mapa no se construye: es lo que hace que valga la
	# pena armarse un refugio propio en vez de ocupar una casa y equiparla entera.
	if world.is_map_floor(cell):
		build_message.emit("Acá no: armate tu propio refugio afuera")
		return
	if world.center_of(cell).distance_to(player.global_position) > MAX_RANGE:
		build_message.emit("Demasiado lejos")
		return
	if not _pay(player, _cost()):
		build_message.emit("Te falta material (necesitás %s)" % _cost_text(_cost()))
		return

	var entry := _current()
	_spawn_at(cell, str(entry["id"]))
	AudioManager.play("construir")
	match str(entry["id"]):
		"fogata":
			build_message.emit("Fogata armada — apretá E para prenderla")
		"mesa":
			build_message.emit("Mesa lista — ahora podés craftear parado al lado (C)")
		_:
			build_message.emit("%s construida" % str(entry["nombre"]))


## Arreglar una estructura dañada: **modo construcción (B) + clic izquierdo**
## sobre ella.
##
## Va acá y no en la tecla E a propósito: una puerta ya usa E para abrirse y
## cerrarse, así que meter el arreglo ahí obligaría a que E haga dos cosas
## distintas según cuánta vida le quede. El modo construcción, en cambio, ya es
## el contexto de "estoy trabajando en la base" y ya sabe de materiales y costos.
## Estructura reparable que ocupa esa celda, o null.
##
## Busca en el grupo "structure" y no solo en `_placed` **a propósito**:
## `_placed` únicamente tiene lo que construyó el jugador, así que mirando ahí
## nomás no se podrían arreglar las **puertas de las casas del mapa** — que es
## justo el caso principal, porque son las que te van a romper primero.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _structure_at(cell: Vector2i):
	var world = _world()
	if world == null:
		return null
	for node in get_tree().get_nodes_in_group("structure"):
		if not (node is Node2D):
			continue
		var candidate = node
		if world.cell_at(candidate.global_position) == cell:
			return candidate
	return null


func _try_repair(node) -> void:
	if not is_instance_valid(node) or not node.has_method("repair"):
		build_message.emit("Ya hay algo construido ahí")
		return
	if not node.is_damaged():
		build_message.emit("Eso está entero")
		return

	var player = _player()
	if player == null:
		return
	var item := str(node.repair_item)
	if not player.inventory.has(item, 1):
		build_message.emit("Necesitás %s para arreglar esto" % ItemDB.display_name(item))
		return

	# Se cobra de a una unidad por clic: así no se te va media mochila de un
	# golpe en algo que estaba raspado nada más.
	player.inventory.remove(item, 1)
	var curado: float = node.repair(float(node.repair_per_item))
	AudioManager.play("construir")
	build_message.emit("Reparaste (+%d) — %d%%" % [
		int(curado), int(round(node.health_ratio() * 100.0)),
	])


func _try_remove(cell: Vector2i) -> void:
	var key := _key(cell)
	if not _placed.has(key):
		return

	var record: Dictionary = _placed[key]
	var node = record.get("nodo")
	var type_id := str(record.get("tipo", "barricada"))
	var player = _player()

	# Un cofre con cosas adentro no se desarma así nomás: se perdería todo lo
	# guardado junto con el mueble. Hay que vaciarlo primero (E lo abre).
	if type_id == "cofre" and is_instance_valid(node):
		var stored: Dictionary = node.get("stored")
		if not stored.is_empty():
			build_message.emit("Vaciá el cofre antes de desarmarlo (E para abrirlo)")
			return

	_placed.erase(key)
	if is_instance_valid(node):
		node.queue_free()

	# Devolvemos la mitad de cada material (redondeando para abajo, mínimo 1).
	var devuelto := {}
	for item in _cost_of(type_id):
		var refund := maxi(1, int(floor(int(_cost_of(type_id)[item]) * REFUND_RATIO)))
		devuelto[item] = refund
		if player != null:
			# Al piso si no entra: la construcción ya se desarmó, no hay forma de
			# devolver el vuelto de otra manera.
			player.give_or_drop(str(item), refund)
	build_message.emit("Desarmaste %s (+%s)" % [_name_of(type_id), _cost_text(devuelto)])


func _entry_of(type_id: String) -> Dictionary:
	for entry in BUILDABLES:
		if str(entry["id"]) == type_id:
			return entry
	return BUILDABLES[0]


func _cost_of(type_id: String) -> Dictionary:
	return _entry_of(type_id)["costo"]


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
