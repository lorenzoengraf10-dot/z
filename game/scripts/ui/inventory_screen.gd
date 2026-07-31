extends CanvasLayer
## Inventario (tecla I). **Pausa el juego** mientras está abierto — al revés que
## el minijuego de fuego, donde el mundo sigue corriendo.
##
## Muestra lo que llevás encima, qué hace cada cosa, y deja equipar armas o
## consumir comida sin salir de la pantalla.

const ROW_HEIGHT := 30

var _panel: PanelContainer
var _list: VBoxContainer
var _detail: Label
var _rows: Array[Button] = []
var _ids: Array[String] = []
var _selected := 0


func _ready() -> void:
	add_to_group("inventory_screen")
	layer = 6
	# Tiene que seguir andando con el juego pausado, si no no responde nada.
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
	_panel.offset_left = -280
	_panel.offset_right = 280
	_panel.offset_top = -200
	_panel.offset_bottom = 200
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)

	var title := Label.new()
	title.text = "MOCHILA"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	var hint := Label.new()
	hint.text = "Clic para usar o equipar  ·  I o Esc para cerrar  ·  el juego está en pausa"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.75, 0.75, 0.78)
	column.add_child(hint)

	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	column.add_child(HSeparator.new())

	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 46)
	column.add_child(_detail)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
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
	# No abrimos encima del minijuego de fuego, que necesita el teclado.
	var fire = get_tree().get_first_node_in_group("fire_minigame")
	if fire != null and fire.is_open():
		return
	# Ni encima del resumen de la partida: ahí ya estás muerto.
	var summary = get_tree().get_first_node_in_group("run_summary")
	if summary != null and summary.visible:
		return
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false


func _refresh() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	_ids.clear()

	var player = _player()
	if player == null:
		return

	var items: Dictionary = player.inventory.items
	if items.is_empty():
		_detail.text = "No llevás nada encima."
		var empty := Button.new()
		empty.text = "(vacío)"
		empty.disabled = true
		empty.focus_mode = Control.FOCUS_NONE
		_list.add_child(empty)
		_rows.append(empty)
		_ids.append("")
		return

	for key in items.keys():
		var id := str(key)
		var amount := int(items[key])
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.text = _row_text(player, id, amount)
		row.pressed.connect(_on_row_pressed.bind(id))
		row.mouse_entered.connect(_on_row_hovered.bind(id))
		_list.add_child(row)
		_rows.append(row)
		_ids.append(id)

	_show_detail(_ids[0])


func _row_text(player, id: String, amount: int) -> String:
	var label := "%s  x%d" % [ItemDB.display_name(id), amount]
	if ItemDB.is_weapon(id):
		if player.equipped_weapon == id:
			label += "   [EQUIPADA]"
		else:
			label += "   (arma)"
	elif ItemDB.is_edible(id):
		label += "   (consumible)"
	return label


func _on_row_hovered(id: String) -> void:
	_show_detail(id)


func _show_detail(id: String) -> void:
	if id == "":
		return
	var text := ItemDB.describe(id)
	if ItemDB.is_weapon(id):
		text += "\nDaño %d · alcance %d · ruido %d" % [
			int(ItemDB.value_of(id, "dano")),
			int(ItemDB.value_of(id, "alcance")),
			int(ItemDB.value_of(id, "ruido")),
		]
	elif ItemDB.is_edible(id):
		var parts: Array[String] = []
		if ItemDB.value_of(id, "hambre") > 0.0:
			parts.append("+%d hambre" % int(ItemDB.value_of(id, "hambre")))
		if ItemDB.value_of(id, "sed") > 0.0:
			parts.append("+%d sed" % int(ItemDB.value_of(id, "sed")))
		if ItemDB.value_of(id, "infeccion") > 0.0:
			parts.append("+%d infección" % int(ItemDB.value_of(id, "infeccion")))
		if not parts.is_empty():
			text += "\n" + " · ".join(parts)
	_detail.text = text


func _on_row_pressed(id: String) -> void:
	var player = _player()
	if player == null or id == "":
		return

	if ItemDB.is_weapon(id):
		# Volver a apretar el arma equipada la guarda.
		player.equip("" if player.equipped_weapon == id else id)
	elif ItemDB.is_edible(id):
		if player.inventory.remove(id, 1):
			player.needs.consume_item(id)
	else:
		_show_detail(id)
		return

	_refresh()


# Sin tipar: usamos player.inventory / equip(), que no existen en Node.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
