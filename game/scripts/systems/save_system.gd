extends Node
## Autoload. Guarda y carga la partida en JSON (user://savegame.json).
## F5 guarda, F9 carga.
##
## Guarda: posición y necesidades del jugador, inventario, barricadas
## construidas y tiles que cambiaron (árboles talados).
##
## Está escrito para no romper nunca: si el archivo no existe, está corrupto o
## viene de una versión vieja, avisa y sigue de largo en vez de crashear.

signal saved()
signal loaded()
signal save_message(text: String)

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_game()
		get_viewport().set_input_as_handled()


func save_game() -> bool:
	var player = _player()
	if player == null:
		save_message.emit("No se pudo guardar (no hay jugador)")
		return false

	var data := {
		"version": SAVE_VERSION,
		"jugador": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"necesidades": player.needs.to_dict(),
			"inventario": player.inventory.to_dict(),
		},
	}

	var world = _world()
	if world != null:
		data["tiles"] = world.modified_to_dict()

	var build = _build_system()
	if build != null:
		data["construcciones"] = build.placed_cells()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		save_message.emit("No se pudo escribir el guardado")
		push_warning("save_system: no se pudo abrir %s para escribir" % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_message.emit("Partida guardada")
	saved.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	var data := _read_save()
	if data.is_empty():
		save_message.emit("No hay partida guardada")
		return false

	var player = _player()
	if player == null:
		save_message.emit("No se pudo cargar (no hay jugador)")
		return false

	var pdata: Dictionary = data.get("jugador", {})
	if typeof(pdata) == TYPE_DICTIONARY and not pdata.is_empty():
		player.global_position = Vector2(float(pdata.get("x", 0.0)), float(pdata.get("y", 0.0)))
		var needs_data: Variant = pdata.get("necesidades", {})
		if typeof(needs_data) == TYPE_DICTIONARY:
			player.needs.from_dict(needs_data)
		var inv_data: Variant = pdata.get("inventario", {})
		if typeof(inv_data) == TYPE_DICTIONARY:
			player.inventory.from_dict(inv_data)

	var world = _world()
	var tiles: Variant = data.get("tiles", {})
	if world != null and typeof(tiles) == TYPE_DICTIONARY:
		world.apply_modified(tiles)

	var build = _build_system()
	var built: Variant = data.get("construcciones", [])
	if build != null and typeof(built) == TYPE_ARRAY:
		build.clear_all()
		build.load_cells(built)

	save_message.emit("Partida cargada")
	loaded.emit()
	return true


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("save_system: no se pudo abrir el guardado")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save_system: el guardado está corrupto, se ignora")
		return {}
	return parsed


# Sin tipar: usamos player.needs / player.inventory, que no existen en Node2D.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")


# Sin tipar: usamos métodos propios de world.gd y build_system.gd.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")


# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _build_system():
	return get_tree().get_first_node_in_group("build_system")
