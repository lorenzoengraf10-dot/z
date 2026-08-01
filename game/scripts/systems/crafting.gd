extends CanvasLayer
## Panel de crafteo (tecla C). Lee las recetas de data/recipes.json.
##
## Para craftear hay que estar **al lado de una mesa de trabajo**, y las recetas
## de cocina piden además una **fogata prendida**. Cada receta muestra su costo
## con los materiales que te faltan en rojo, así se ve de una qué te falta.
##
## La UI se arma por código a propósito: agregar recetas es solo editar el JSON.

signal craft_message(text: String)

const RECIPES_PATH := "res://data/recipes.json"

const OK_COLOR := Color(0.82, 0.86, 0.82)
const BAD_COLOR := Color(0.55, 0.52, 0.52)
const MISSING_COLOR := Color(0.92, 0.45, 0.42)

var recipes: Array = []

var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label
var _rows: Array[Button] = []


func _ready() -> void:
	add_to_group("crafting")
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -210
	_panel.offset_bottom = 210
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)

	var title := Label.new()
	title.text = "CRAFTEO"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	column.add_child(_status)

	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var hint := Label.new()
	hint.text = "Clic para fabricar  ·  C o Esc para cerrar"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.7, 0.7, 0.74)
	column.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _refresh() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()

	var player = _player()
	var near_bench := _has_workbench_nearby(player)
	var near_fire := _has_fire_nearby(player)

	if not near_bench:
		_status.text = "Necesitás una MESA DE TRABAJO cerca (construila con B)"
		_status.modulate = MISSING_COLOR
	elif near_fire:
		_status.text = "Mesa de trabajo ✓   ·   Fogata prendida ✓"
		_status.modulate = OK_COLOR
	else:
		_status.text = "Mesa de trabajo ✓   ·   sin fogata: no podés cocinar"
		_status.modulate = OK_COLOR

	var current_category := ""
	for i in range(recipes.size()):
		var recipe: Dictionary = recipes[i]
		var category := str(recipe.get("categoria", "Otros"))
		if category != current_category:
			current_category = category
			_rows.append(_add_header(category))
		_rows.append(_add_recipe_row(i, recipe, player, near_bench, near_fire))


func _add_header(text: String) -> Button:
	# Usamos un Button deshabilitado para que entre en el mismo array y se
	# limpie igual que las filas.
	var header := Button.new()
	header.text = "— " + text + " —"
	header.disabled = true
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list.add_child(header)
	return header


func _add_recipe_row(index: int, recipe: Dictionary, player, near_bench: bool, near_fire: bool) -> Button:
	var costs: Dictionary = recipe.get("cuesta", {})
	var needs_fire := bool(recipe.get("requiere_fuego", false))
	var needs_bench := bool(recipe.get("requiere_mesa", false))

	var affordable := player != null and _can_afford(player, costs)
	var station_ok := (not needs_bench or near_bench) and (not needs_fire or near_fire)

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 32)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.focus_mode = Control.FOCUS_NONE
	row.text = "%s   [%s]%s" % [
		str(recipe.get("nombre", "?")),
		_cost_text(player, costs),
		"   🔥 necesita fogata" if needs_fire and not near_fire else "",
	]
	row.tooltip_text = str(recipe.get("descripcion", ""))
	row.disabled = not (affordable and station_ok)
	row.modulate = OK_COLOR if not row.disabled else BAD_COLOR
	row.pressed.connect(_craft.bind(index))
	_list.add_child(row)
	return row


## Texto del costo, marcando lo que te falta.
func _cost_text(player, costs: Dictionary) -> String:
	var parts: Array[String] = []
	for id in costs.keys():
		var need := int(costs[id])
		var have := 0
		if player != null:
			have = player.inventory.count(str(id))
		parts.append("%s %d/%d" % [ItemDB.display_name(str(id)), have, need])
	return ", ".join(parts)


func _can_afford(player, costs: Dictionary) -> bool:
	for id in costs.keys():
		if not player.inventory.has(str(id), int(costs[id])):
			return false
	return true


## ¿Hay una fogata prendida lo bastante cerca como para cocinar?
func _has_fire_nearby(player) -> bool:
	if player == null:
		return false
	for node in get_tree().get_nodes_in_group("campfire"):
		var fire = node
		if fire.has_method("can_cook_from") and fire.can_cook_from(player.global_position):
			return true
	return false


## ¿Hay una mesa de trabajo cerca?
func _has_workbench_nearby(player) -> bool:
	if player == null:
		return false
	for node in get_tree().get_nodes_in_group("workbench"):
		var bench = node
		if bench.has_method("can_craft_from") and bench.can_craft_from(player.global_position):
			return true
	return false


func _craft(index: int) -> void:
	var player = _player()
	if player == null or index < 0 or index >= recipes.size():
		return
	var recipe: Dictionary = recipes[index]
	var costs: Dictionary = recipe.get("cuesta", {})
	var makes: Dictionary = recipe.get("produce", {})

	if bool(recipe.get("requiere_mesa", false)) and not _has_workbench_nearby(player):
		craft_message.emit("Necesitás estar al lado de una mesa de trabajo")
		return
	if bool(recipe.get("requiere_fuego", false)) and not _has_fire_nearby(player):
		craft_message.emit("Para eso necesitás una fogata prendida al lado")
		return
	if not _can_afford(player, costs):
		craft_message.emit("Te faltan materiales para %s" % str(recipe.get("nombre", "eso")))
		return

	for id in costs.keys():
		player.inventory.remove(str(id), int(costs[id]))
	var made: Array[String] = []
	for id in makes.keys():
		var amount := int(makes[id])
		# give_or_drop() y no inventory.add(): los materiales ya se cobraron
		# arriba, así que si lo fabricado no entra tiene que caer al piso, no
		# evaporarse. Hoy toda receta gasta más lugares de los que produce, pero
		# alcanza con una receta nueva que dé 2 de algo para que se pierda.
		player.give_or_drop(str(id), amount)
		made.append("%d %s" % [amount, ItemDB.display_name(str(id))])

	craft_message.emit("Fabricaste: " + ", ".join(made))
	AudioManager.play("craftear")
	_refresh()


# Sin tipar: usamos player.inventory, que no existe en Node/Node2D.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
