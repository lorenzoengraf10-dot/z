extends CanvasLayer
## Inventario (tecla I). **Pausa el juego** mientras está abierto — al revés que
## el minijuego de fuego, donde el mundo sigue corriendo.
##
## Muestra lo que llevás encima, qué hace cada cosa, y deja equipar armas o
## consumir comida sin salir de la pantalla.

const ROW_HEIGHT := 30
## Cuánto se tira por click en "Tirar". Ctrl+click tira la pila entera.
const DROP_AMOUNT := 1

var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _detail: Label
var _rows: Array[Control] = []
var _ids: Array[String] = []
var _selected := 0

## Fila de "lo que tenés en la mano" (arms.melee / arms.firearm / munición).
## Estos 3 NO aparecen en la lista de la mochila de abajo: ArmsComponent los
## saca del inventario apenas se equipan, que es justo lo que hace que no
## gasten lugar. Por eso necesitan su propio lugar para desequiparlos.
var _melee_label: Label
var _melee_btn: Button
var _firearm_label: Label
var _firearm_btn: Button


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
	_panel.offset_top = -220
	_panel.offset_bottom = 220
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)

	_title = Label.new()
	_title.text = "MOCHILA"
	_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_title)

	var hint := Label.new()
	hint.text = "Clic para usar, equipar o cargar munición  ·  \"Tirar\" para soltarlo  ·  F cambia de mano  ·  I o Esc para cerrar  ·  el juego está en pausa"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.75, 0.75, 0.78)
	column.add_child(hint)

	column.add_child(HSeparator.new())

	var equip_title := Label.new()
	equip_title.text = "EN LA MANO  (no ocupa mochila)"
	equip_title.add_theme_font_size_override("font_size", 12)
	equip_title.modulate = Color(0.75, 0.75, 0.78)
	column.add_child(equip_title)

	var melee_row := HBoxContainer.new()
	column.add_child(melee_row)
	_melee_label = Label.new()
	_melee_label.add_theme_font_size_override("font_size", 13)
	_melee_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	melee_row.add_child(_melee_label)
	_melee_btn = Button.new()
	_melee_btn.text = "Guardar"
	_melee_btn.custom_minimum_size = Vector2(70, 24)
	_melee_btn.focus_mode = Control.FOCUS_NONE
	_melee_btn.pressed.connect(_on_unequip_melee)
	melee_row.add_child(_melee_btn)

	var firearm_row := HBoxContainer.new()
	column.add_child(firearm_row)
	_firearm_label = Label.new()
	_firearm_label.add_theme_font_size_override("font_size", 13)
	_firearm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	firearm_row.add_child(_firearm_label)
	_firearm_btn = Button.new()
	_firearm_btn.text = "Guardar"
	_firearm_btn.custom_minimum_size = Vector2(70, 24)
	_firearm_btn.focus_mode = Control.FOCUS_NONE
	_firearm_btn.pressed.connect(_on_unequip_firearm)
	firearm_row.add_child(_firearm_btn)

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
	# No abrimos encima de ningún minijuego, que necesitan el teclado/mouse.
	for group in ["fire_minigame", "click_minigame", "fishing_minigame"]:
		var minigame = get_tree().get_first_node_in_group(group)
		if minigame != null and minigame.is_open():
			return
	# Ni encima del resumen de la partida: ahí ya estás muerto.
	var summary = get_tree().get_first_node_in_group("run_summary")
	if summary != null and summary.visible:
		return
	# Ni encima de la ayuda: las dos pausan y se pisarían al cerrarse.
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.help_open():
		return
	# Ni encima del almacenamiento: mismo motivo.
	var storage = get_tree().get_first_node_in_group("storage_screen")
	if storage != null and storage.visible:
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

	var inv: InventoryComponent = player.inventory
	_title.text = "MOCHILA  (%d/%d)" % [inv.used(), inv.capacity()]
	_refresh_equipped(player)

	var items: Dictionary = inv.items
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

		var wrapper := HBoxContainer.new()

		var row := Button.new()
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.text = _row_text(player, id, amount)
		row.pressed.connect(_on_row_pressed.bind(id))
		row.mouse_entered.connect(_on_row_hovered.bind(id))
		wrapper.add_child(row)

		# Nunca se tira lo que tenés equipado directo: hay que desequiparlo
		# primero (clic en la fila), así no te quedás sin arma sin querer.
		if not (ItemDB.is_weapon(id) and (player.arms.melee == id or player.arms.firearm == id)):
			var drop_btn := Button.new()
			drop_btn.text = "Tirar"
			drop_btn.custom_minimum_size = Vector2(52, ROW_HEIGHT)
			drop_btn.focus_mode = Control.FOCUS_NONE
			drop_btn.tooltip_text = "Tirar 1  ·  Ctrl+clic tira todo (%d)" % amount
			drop_btn.pressed.connect(_on_drop_pressed.bind(id))
			wrapper.add_child(drop_btn)

		_list.add_child(wrapper)
		_rows.append(wrapper)
		_ids.append(id)

	_show_detail(_ids[0])


## Actualiza las dos filas de "en la mano". Las armas equipadas ya no
## aparecen en la lista de abajo (ArmsComponent las sacó de la mochila), así
## que este es el único lugar donde se ven y se pueden guardar.
func _refresh_equipped(player) -> void:
	var arms: ArmsComponent = player.arms

	if arms.melee == "":
		_melee_label.text = "Cuerpo a cuerpo: (nada)"
		_melee_btn.visible = false
	else:
		var marca := "  · EN MANO" if arms.active == ArmsComponent.MELEE else ""
		_melee_label.text = "Cuerpo a cuerpo: %s%s" % [ItemDB.display_name(arms.melee), marca]
		_melee_btn.visible = true

	if arms.firearm == "":
		_firearm_label.text = "Arma de fuego: (nada)"
		_firearm_btn.visible = false
	else:
		var marca := "  · EN MANO" if arms.active == ArmsComponent.FIREARM else ""
		_firearm_label.text = "Arma de fuego: %s  ·  Balas: %d%s" % [
			ItemDB.display_name(arms.firearm), arms.ammo, marca,
		]
		_firearm_btn.visible = true


func _on_unequip_melee() -> void:
	var player = _player()
	if player == null:
		return
	player.arms.unequip_melee()
	_refresh()


func _on_unequip_firearm() -> void:
	var player = _player()
	if player == null:
		return
	player.arms.unequip_firearm()
	_refresh()


func _row_text(player, id: String, amount: int) -> String:
	var label := "%s  x%d" % [ItemDB.display_name(id), amount]
	if ItemDB.is_weapon(id):
		label += "   (arma, clic para equipar)"
	elif ItemDB.is_edible(id):
		label += "   (consumible)"
	elif player.arms.firearm != "" and ItemDB.ammo_of(player.arms.firearm) == id:
		label += "   (clic para cargarla, no ocupa mochila)"
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
		if ItemDB.value_of(id, "cura") > 0.0:
			parts.append("+%d salud" % int(ItemDB.value_of(id, "cura")))
		if ItemDB.value_of(id, "dano_salud") > 0.0:
			parts.append("-%d salud (crudo)" % int(ItemDB.value_of(id, "dano_salud")))
		if not parts.is_empty():
			text += "\n" + " · ".join(parts)
	_detail.text = text


func _on_row_pressed(id: String) -> void:
	var player = _player()
	if player == null or id == "":
		return

	if ItemDB.is_weapon(id):
		# Si aparece acá es porque no está equipada (las equipadas se sacan de
		# la mochila): un clic siempre la manda al casillero que corresponda.
		player.arms.toggle(id)
	elif ItemDB.is_edible(id):
		if player.inventory.remove(id, 1):
			player.needs.consume_item(id)
	elif player.arms.firearm != "" and ItemDB.ammo_of(player.arms.firearm) == id:
		# Munición suelta que coincide con el arma equipada: clic la carga
		# entera al casillero, que no gasta mochila.
		var amount := player.inventory.count(id)
		if player.inventory.remove(id, amount):
			player.arms.add_ammo(id, amount)
	else:
		_show_detail(id)
		return

	_refresh()


## Tira 1, o la pila entera si mantenés Ctrl apretado al clickear.
func _on_drop_pressed(id: String) -> void:
	var player = _player()
	if player == null or id == "":
		return
	var amount := player.inventory.count(id) if Input.is_key_pressed(KEY_CTRL) else DROP_AMOUNT
	player.drop(id, amount)
	_refresh()


# Sin tipar: usamos player.inventory / equip(), que no existen en Node.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
