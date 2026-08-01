extends CanvasLayer
## Pantalla de almacenamiento: se abre con **E** sobre un cofre o un armario ya
## revisado. **Pausa el juego**, igual que la mochila.
##
## Dos columnas: lo que está guardado en el mueble (container.stored) y tu
## mochila. Un clic mueve 1 de un lado al otro; Ctrl+clic mueve la pila entera.
## Es el mismo patrón de fila+botón que ya usa inventory_screen.gd.

const ROW_HEIGHT := 28

var _container = null   ## Sin tipar: es container.gd, que no existe en Node.

var _panel: PanelContainer
var _title: Label
var _stored_list: VBoxContainer
var _bag_list: VBoxContainer
var _stored_rows: Array[Control] = []
var _bag_rows: Array[Control] = []


func _ready() -> void:
	add_to_group("storage_screen")
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -320
	_panel.offset_right = 320
	_panel.offset_top = -210
	_panel.offset_bottom = 210
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)

	_title = Label.new()
	_title.text = "ALMACENAMIENTO"
	_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_title)

	var hint := Label.new()
	hint.text = "Clic mueve 1  ·  Ctrl+clic mueve todo  ·  E o Esc para cerrar  ·  el juego está en pausa"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.75, 0.75, 0.78)
	column.add_child(hint)

	column.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	column.add_child(columns)

	_stored_list = _build_side(columns, "GUARDADO ACÁ  →  clic para sacarlo")
	_bag_list = _build_side(columns, "TU MOCHILA  →  clic para guardarlo")


func _build_side(parent: HBoxContainer, header: String) -> VBoxContainer:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(side)

	var label := Label.new()
	label.text = header
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.75, 0.75, 0.78)
	side.add_child(label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## La llama interactor.gd al apretar E sobre un mueble ya revisado (armario
## vacío o cofre construido).
func open_for(container) -> void:
	if container == null or not is_instance_valid(container):
		return
	# No se abre encima de otra pantalla modal: se pisarían la pausa al cerrar.
	for group in ["fire_minigame", "click_minigame", "fishing_minigame"]:
		var minigame = get_tree().get_first_node_in_group(group)
		if minigame != null and minigame.is_open():
			return
	var summary = get_tree().get_first_node_in_group("run_summary")
	if summary != null and summary.visible:
		return
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.help_open():
		return
	var inventory = get_tree().get_first_node_in_group("inventory_screen")
	if inventory != null and inventory.visible:
		return
	var map = get_tree().get_first_node_in_group("map_screen")
	if map != null and map.visible:
		return

	_container = container
	_title.text = "ALMACENAMIENTO — %s" % str(container.display_name())
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	_container = null


func _refresh() -> void:
	for row in _stored_rows:
		row.queue_free()
	_stored_rows.clear()
	for row in _bag_rows:
		row.queue_free()
	_bag_rows.clear()

	var player = _player()
	if player == null or _container == null or not is_instance_valid(_container):
		return

	_fill_side(_stored_list, _stored_rows, _container.stored, _on_take_pressed)
	_fill_side(_bag_list, _bag_rows, player.inventory.items, _on_store_pressed)


func _fill_side(list: VBoxContainer, rows: Array[Control], items: Dictionary, action: Callable) -> void:
	if items.is_empty():
		var empty := Label.new()
		empty.add_theme_font_size_override("font_size", 13)
		empty.modulate = Color(0.6, 0.6, 0.62)
		empty.text = "(vacío)"
		list.add_child(empty)
		rows.append(empty)
		return

	for key in items.keys():
		var id := str(key)
		var amount := int(items[key])

		var row := Button.new()
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.text = "%s  x%d" % [ItemDB.display_name(id), amount]
		row.tooltip_text = "Clic: 1  ·  Ctrl+clic: los %d" % amount
		row.pressed.connect(action.bind(id))
		list.add_child(row)
		rows.append(row)


## Saca `id` del mueble y lo mete en la mochila. Lo que no entre se queda
## adentro del mueble (nunca se pierde, mismo criterio que el resto del loot).
func _on_take_pressed(id: String) -> void:
	var player = _player()
	if player == null or _container == null:
		return
	var stored: Dictionary = _container.stored
	var have := int(stored.get(id, 0))
	if have <= 0:
		return
	var amount := have if Input.is_key_pressed(KEY_CTRL) else 1

	var taken: int = player.receive(id, amount)
	if taken <= 0:
		return
	var left := have - taken
	if left > 0:
		stored[id] = left
	else:
		stored.erase(id)
	_refresh()


## Mete `id` de la mochila al mueble.
func _on_store_pressed(id: String) -> void:
	var player = _player()
	if player == null or _container == null:
		return
	var have := player.inventory.count(id)
	if have <= 0:
		return
	var amount := have if Input.is_key_pressed(KEY_CTRL) else 1

	if not player.inventory.remove(id, amount):
		return
	_container.add_leftover(id, amount)
	_refresh()


# Sin tipar: usamos player.inventory/receive(), que no existen en Node.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
