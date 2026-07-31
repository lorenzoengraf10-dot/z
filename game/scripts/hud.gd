extends CanvasLayer
## HUD: barras de necesidades, inventario, barra de progreso de la acción en
## curso (talar/pescar) y una línea de mensajes.
##
## Toda la interfaz se arma por código: así agregar una necesidad nueva en
## NeedsComponent la hace aparecer sola acá, sin tocar ninguna escena.

const BAR_WIDTH := 190
const BAR_HEIGHT := 14
const MESSAGE_SECONDS := 3.0

const COLORS := {
	"salud": Color(0.83, 0.24, 0.24),
	"hambre": Color(0.88, 0.63, 0.14),
	"sed": Color(0.25, 0.60, 0.88),
	"energia": Color(0.35, 0.78, 0.36),
	"temperatura": Color(0.62, 0.82, 0.92),
	"sangrado": Color(0.90, 0.15, 0.18),
}
const PHASE_ICONS := {
	"Amanecer": "🌅",
	"Día": "☀",
	"Atardecer": "🌇",
	"Noche": "🌙",
}
const LABELS := {
	"salud": "Salud",
	"hambre": "Hambre",
	"sed": "Sed",
	"energia": "Energía",
	"temperatura": "Temp.",
	"sangrado": "SANGRADO",
}

var _bars: Dictionary = {}
var _inventory_label: Label
var _message_label: Label
var _action_box: VBoxContainer
var _action_label: Label
var _action_bar: ProgressBar
var _clock_label: Label
var _weapon_label: Label
var _message_timer := 0.0
var _blink := 0.0
var _day_night = null
var _player_ref = null
var _run = null


func _ready() -> void:
	layer = 2
	_build_ui()
	_build_toolbar()
	# Esperamos un frame para que el jugador y los sistemas ya estén en el árbol.
	await get_tree().process_frame
	_connect_signals()
	_day_night = get_tree().get_first_node_in_group("day_night")
	_run = get_tree().get_first_node_in_group("run_manager")


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.text = ""

	if _player_ref != null and is_instance_valid(_player_ref):
		var weapon: Dictionary = _player_ref.weapon_stats()
		var text := "En mano: %s  (daño %d · alcance %d)" % [
			str(weapon["nombre"]), int(weapon["dano"]), int(weapon["alcance"]),
		]
		# Las de fuego valen lo que la munición que te queda.
		if bool(weapon["fuego"]):
			var ammo := str(weapon["municion"])
			text += "  ·  %s: %d" % [ItemDB.display_name(ammo), _player_ref.inventory.count(ammo)]
		_weapon_label.text = text

	_blink_bleed_bar(delta)

	if _day_night != null and is_instance_valid(_day_night):
		var phase := str(_day_night.phase_name())
		_clock_label.text = "%s%s  %s %s" % [
			_day_prefix(), _day_night.time_string(), PHASE_ICONS.get(phase, ""), phase,
		]


## "Día 4 · " si hay run_manager; vacío si no (por si abrís la escena sola).
func _day_prefix() -> String:
	if _run == null or not is_instance_valid(_run):
		return ""
	return "Día %d · " % (int(_run.stats.get("dias", 0)) + 1)


## La barra de sangrado parpadea: es la que te mata si la ignorás.
func _blink_bleed_bar(delta: float) -> void:
	var bar: ProgressBar = _bars.get(NeedsComponent.SANGRADO)
	if bar == null:
		return
	if bar.value <= 0.0:
		bar.modulate = Color.WHITE
		return
	_blink = fmod(_blink + delta * 4.0, TAU)
	bar.modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(_blink)))


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_bottom", 10)
	add_child(root)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(column)

	# Barras de necesidades
	for id in NeedsComponent.ORDER:
		var row := HBoxContainer.new()
		column.add_child(row)

		var name_label := Label.new()
		name_label.text = str(LABELS.get(id, id))
		name_label.custom_minimum_size = Vector2(78, 0)
		row.add_child(name_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = COLORS.get(id, Color.WHITE)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		_bars[id] = bar

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer)

	_inventory_label = Label.new()
	_inventory_label.text = "Mochila: vacía"
	column.add_child(_inventory_label)

	_weapon_label = Label.new()
	_weapon_label.text = ""
	column.add_child(_weapon_label)

	# Barra de acción (talar / pescar)
	_action_box = VBoxContainer.new()
	_action_box.visible = false
	column.add_child(_action_box)

	_action_label = Label.new()
	_action_box.add_child(_action_label)

	_action_bar = ProgressBar.new()
	_action_bar.custom_minimum_size = Vector2(BAR_WIDTH, 10)
	_action_bar.max_value = 1.0
	_action_bar.show_percentage = false
	_action_box.add_child(_action_bar)

	# Línea de mensajes: centrada abajo, anclada para que siga a la ventana.
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 1.0
	_message_label.anchor_bottom = 1.0
	_message_label.offset_left = -350
	_message_label.offset_right = 350
	_message_label.offset_top = -64
	_message_label.offset_bottom = -40
	add_child(_message_label)


## Barra de arriba a la derecha: reloj + botones para abrir mapa, crafteo y
## construcción sin depender de acordarse de las teclas.
func _build_toolbar() -> void:
	var column := VBoxContainer.new()
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.offset_left = -350.0
	column.offset_right = -12.0
	column.offset_top = 10.0
	column.offset_bottom = 90.0
	column.alignment = BoxContainer.ALIGNMENT_END
	add_child(column)

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 17)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.text = ""
	column.add_child(_clock_label)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(bar)

	bar.add_child(_make_button("Mapa (M)", _toggle_map))
	bar.add_child(_make_button("Crafteo (C)", _toggle_crafting))
	bar.add_child(_make_button("Construir (B)", _toggle_build))


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# Sin foco: si no, después de hacer clic la barra espaciadora volvería a
	# apretar el botón en vez de atacar.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _toggle_map() -> void:
	var map = get_tree().get_first_node_in_group("map_screen")
	if map != null and map.has_method("toggle"):
		map.toggle()


func _toggle_crafting() -> void:
	var crafting = get_tree().get_first_node_in_group("crafting")
	if crafting != null and crafting.has_method("toggle"):
		crafting.toggle()


func _toggle_build() -> void:
	var build = get_tree().get_first_node_in_group("build_system")
	if build != null and build.has_method("toggle"):
		build.toggle()


func _connect_signals() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_player_ref = player
		_connect_if_possible(player, "message", _on_message)

		var needs: NeedsComponent = player.get_node_or_null("NeedsComponent")
		if needs != null:
			needs.need_changed.connect(_on_need_changed)
			for id in NeedsComponent.ORDER:
				_on_need_changed(id, needs.get_need(id), needs.max_of(id))

		var inventory: InventoryComponent = player.get_node_or_null("InventoryComponent")
		if inventory != null:
			inventory.changed.connect(_on_inventory_changed)
			inventory.full.connect(_on_inventory_full)
			_on_inventory_changed(inventory.items)

		var interactor: Interactor = player.get_node_or_null("Interactor")
		if interactor != null:
			interactor.action_started.connect(_on_action_started)
			interactor.action_progress.connect(_on_action_progress)
			interactor.action_ended.connect(_on_action_ended)

	_connect_if_possible(get_tree().get_first_node_in_group("build_system"), "build_message", _on_message)
	_connect_if_possible(get_tree().get_first_node_in_group("crafting"), "craft_message", _on_message)
	_connect_if_possible(get_tree().get_first_node_in_group("horde_spawner"), "horde_spawned", _on_horde)

	# Autoload de guardado.
	var save := get_node_or_null("/root/SaveSystem")
	_connect_if_possible(save, "save_message", _on_message)


func _connect_if_possible(node: Object, signal_name: String, target: Callable) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_signal(signal_name):
		return
	if not node.is_connected(signal_name, target):
		node.connect(signal_name, target)


func _on_need_changed(id: String, current: float, maximum: float) -> void:
	var bar: ProgressBar = _bars.get(id)
	if bar == null:
		return
	bar.max_value = maximum
	bar.value = current


func _on_inventory_changed(items: Dictionary) -> void:
	var header := "Mochila"
	if _player_ref != null and is_instance_valid(_player_ref):
		var inv = _player_ref.inventory
		header = "Mochila %d/%d" % [inv.used(), inv.capacity()]
	if items.is_empty():
		_inventory_label.text = header + ": vacía"
		return
	var parts: Array[String] = []
	for id in items.keys():
		parts.append("%s x%d" % [ItemDB.display_name(str(id)), int(items[id])])
	_inventory_label.text = header + ": " + " · ".join(parts)


func _on_action_started(label: String, _duration: float) -> void:
	_action_box.visible = true
	_action_label.text = label
	_action_bar.value = 0.0


func _on_action_progress(ratio: float) -> void:
	_action_bar.value = ratio


func _on_action_ended(message: String) -> void:
	_action_box.visible = false
	if message != "":
		_on_message(message)


func _on_inventory_full(item: String) -> void:
	_on_message("¡Mochila llena! Necesitás una mochila más grande (%s)" % ItemDB.display_name(item))


func _on_horde(count: int) -> void:
	_on_message("¡Escuchaste ruido... vienen %d zombies!" % count)


func _on_message(text: String) -> void:
	_message_label.text = text
	_message_timer = MESSAGE_SECONDS
