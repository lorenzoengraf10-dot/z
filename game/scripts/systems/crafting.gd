extends CanvasLayer
## Panel de crafteo (tecla C). Lee las recetas de data/recipes.json y las muestra
## con su costo; las que podés hacer aparecen en blanco y las que no, en gris.
## Se craftea apretando el número de la receta.
##
## La UI se arma por código a propósito: así agregar recetas es solo editar el
## JSON, sin tocar ninguna escena.

signal craft_message(text: String)

const RECIPES_PATH := "res://data/recipes.json"

var recipes: Array = []

var _panel: PanelContainer
var _list: VBoxContainer
var _rows: Array[Label] = []


func _ready() -> void:
	add_to_group("crafting")
	layer = 5
	recipes = _load_recipes()
	_build_ui()
	visible = false


func _load_recipes() -> Array:
	if not FileAccess.file_exists(RECIPES_PATH):
		push_warning("crafting.gd: no se encontró " + RECIPES_PATH)
		return []
	var file := FileAccess.open(RECIPES_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("crafting.gd: recipes.json debe ser una lista de recetas.")
		return []
	return parsed


func _build_ui() -> void:
	# Panel centrado en pantalla (anclado, así queda bien en cualquier resolución).
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -230
	_panel.offset_right = 230
	_panel.offset_top = -110
	_panel.offset_bottom = 110
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	_list = VBoxContainer.new()
	margin.add_child(_list)

	var title := Label.new()
	title.text = "CRAFTEO   (número para fabricar · C para cerrar)"
	title.add_theme_font_size_override("font_size", 18)
	_list.add_child(title)

	var sep := HSeparator.new()
	_list.add_child(sep)

	for i in range(recipes.size()):
		var row := Label.new()
		_list.add_child(row)
		_rows.append(row)

	if recipes.is_empty():
		var empty := Label.new()
		empty.text = "(No hay recetas cargadas)"
		_list.add_child(empty)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var index := _digit_index(event.keycode)
		if index >= 0 and index < recipes.size():
			_craft(index)
			get_viewport().set_input_as_handled()


func _digit_index(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	return -1


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _refresh() -> void:
	var player = _player()
	var near_fire := _has_fire_nearby(player)
	for i in range(_rows.size()):
		var recipe: Dictionary = recipes[i]
		var costs: Dictionary = recipe.get("cuesta", {})
		var needs_fire := bool(recipe.get("requiere_fuego", false))
		var ok := player != null and _can_afford(player, costs) and (not needs_fire or near_fire)

		var suffix := ""
		if needs_fire:
			suffix = "  [fogata prendida]" if near_fire else "  [necesitás una fogata prendida]"

		var row := _rows[i]
		row.text = "%d) %s — %s%s" % [i + 1, str(recipe.get("nombre", "?")), _cost_text(costs), suffix]
		row.modulate = Color(1, 1, 1) if ok else Color(0.55, 0.55, 0.55)


## ¿Hay una fogata prendida lo bastante cerca como para cocinar?
func _has_fire_nearby(player) -> bool:
	if player == null:
		return false
	# El for sobre Array[Node] da elementos tipados como Node: los pasamos a una
	# variable sin tipo para poder llamarles can_cook_from().
	for node in get_tree().get_nodes_in_group("campfire"):
		var fire = node
		if fire.has_method("can_cook_from") and fire.can_cook_from(player.global_position):
			return true
	return false


func _cost_text(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for id in costs.keys():
		parts.append("%d %s" % [int(costs[id]), ItemDB.display_name(str(id))])
	return ", ".join(parts)


func _can_afford(player, costs: Dictionary) -> bool:
	for id in costs.keys():
		if not player.inventory.has(str(id), int(costs[id])):
			return false
	return true


func _craft(index: int) -> void:
	var player = _player()
	if player == null:
		return
	var recipe: Dictionary = recipes[index]
	var costs: Dictionary = recipe.get("cuesta", {})
	var makes: Dictionary = recipe.get("produce", {})

	if not _can_afford(player, costs):
		craft_message.emit("Te faltan materiales para %s" % str(recipe.get("nombre", "eso")))
		return

	if bool(recipe.get("requiere_fuego", false)) and not _has_fire_nearby(player):
		craft_message.emit("Para eso necesitás estar al lado de una fogata prendida")
		return

	for id in costs.keys():
		player.inventory.remove(str(id), int(costs[id]))
	var made: Array[String] = []
	for id in makes.keys():
		var amount := int(makes[id])
		player.inventory.add(str(id), amount)
		made.append("%d %s" % [amount, ItemDB.display_name(str(id))])

	craft_message.emit("Fabricaste: " + ", ".join(made))
	_refresh()


# Sin tipar: usamos player.inventory, que no existe en Node/Node2D.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
