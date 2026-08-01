extends CanvasLayer
## HUD del juego.
##
## Arriba a la izquierda van las necesidades, en una fila: **ícono + barra +
## porcentaje**. La que está en rojo se resalta y el resto queda apagada, así de
## un vistazo ves qué te está matando sin tener que leer seis barras iguales.
##
## Debajo: mochila, arma en mano y el estado de **sigilo** (si te escuchan o te
## ven). El reloj y los botones van arriba a la derecha, y los controles enteros
## viven en el panel de ayuda (tecla H).
##
## Toda la interfaz se arma por código: agregar una necesidad nueva en
## NeedsComponent la hace aparecer sola acá, sin tocar ninguna escena.
##
## ⚠ Todo Control que no sea un botón va con MOUSE_FILTER_IGNORE. Se apunta con
## el mouse, y un contenedor con el filtro por defecto (STOP) se come el clic y
## te deja sin poder atacar.

const BAR_WIDTH := 62
const BAR_HEIGHT := 5
const ICON_SIZE := 15
## La vida va aparte y bastante más grande que el resto: el testeo externo la
## marcó como invisible (un chip más entre seis, apagada al 62% mientras
## estás sano). Es lo único de la pantalla que de verdad importa siempre.
const HEALTH_BAR_WIDTH := 150
const HEALTH_BAR_HEIGHT := 10
const HEALTH_ICON_SIZE := 22
const MESSAGE_SECONDS := 3.0
## Por debajo de esto (en porcentaje) la necesidad se considera crítica.
const CRITICAL := 25.0

const COLORS := {
	"salud": Color(0.86, 0.28, 0.28),
	"hambre": Color(0.90, 0.66, 0.20),
	"sed": Color(0.30, 0.64, 0.90),
	"energia": Color(0.40, 0.80, 0.40),
	"temperatura": Color(0.66, 0.84, 0.94),
	"sangrado": Color(0.92, 0.16, 0.20),
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
	"temperatura": "Temperatura",
	"sangrado": "Sangrado",
}

var _bars: Dictionary = {}      ## id -> ProgressBar
var _icons: Dictionary = {}     ## id -> NeedIcon
var _percents: Dictionary = {}  ## id -> Label
var _chips: Dictionary = {}     ## id -> Control (la columna entera)

## Todo lo de arriba a la izquierda (vida, necesidades, mochila, arma, sigilo)
## cuelga de acá en fila vertical. Antes cada bloque se posicionaba a mano con
## coordenadas fijas y quedaban pegoteados; un solo VBoxContainer los apila
## solo, con aire entre cada uno.
var _hud_left: VBoxContainer

var _inventory_label: Label
var _weapon_label: Label
var _stealth_label: Label
var _message_label: Label
var _action_box: VBoxContainer
var _action_label: Label
var _action_bar: ProgressBar
var _clock_label: Label
var _help_panel: PanelContainer

var _message_timer := 0.0
var _blink := 0.0
var _health_blink := 0.0
var _health_critical := false
var _day_night = null
var _player_ref = null
var _run = null


func _ready() -> void:
	add_to_group("hud")
	layer = 2
	# Tiene que responder con el juego pausado: la ayuda se abre y se cierra ahí.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_hud_left = VBoxContainer.new()
	_passthrough(_hud_left)
	_hud_left.add_theme_constant_override("separation", 8)
	_hud_left.position = Vector2(14, 10)
	add_child(_hud_left)

	_build_needs()
	_build_status()
	_build_toolbar()
	_build_help()
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
		_update_weapon()
		_update_stealth()

	_blink_bleed(delta)
	_blink_health(delta)

	if _day_night != null and is_instance_valid(_day_night):
		var phase := str(_day_night.phase_name())
		_clock_label.text = "%s%s  %s %s" % [
			_day_prefix(), _day_night.time_string(), PHASE_ICONS.get(phase, ""), phase,
		]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		_toggle_help()
		get_viewport().set_input_as_handled()
	elif _help_panel.visible and event.is_action_pressed("ui_cancel"):
		_toggle_help()
		get_viewport().set_input_as_handled()


# --- Construcción de la interfaz ---

## Un Control que no molesta al mouse. Todo lo que no sea botón pasa por acá.
func _passthrough(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


## La vida, aparte y grande, arriba de todo; abajo el resto de las
## necesidades en la fila chica de siempre. Las dos adentro de un panel con
## fondo, para que no floten sueltas sobre el pasto.
func _build_needs() -> void:
	var panel := PanelContainer.new()
	_passthrough(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.4)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	_hud_left.add_child(panel)

	var column := VBoxContainer.new()
	_passthrough(column)
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	_build_health_row(column)
	column.add_child(HSeparator.new())
	_build_small_needs_row(column)


## La vida sola: ícono e info más grandes, y **siempre a máxima opacidad** —
## antes se apagaba al 62% mientras estabas sano, que es al revés de lo que
## hace falta (lo crítico tiene que resaltar, no lo normal apagarse).
func _build_health_row(column: VBoxContainer) -> void:
	var id := NeedsComponent.SALUD
	var tint: Color = COLORS.get(id, Color.WHITE)

	var row := HBoxContainer.new()
	# PASS (no IGNORE): deja que el tooltip aparezca al pasar el mouse, pero
	# sigue sin comerse el clic — un STOP acá rompería el ataque.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = str(LABELS.get(id, id))
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_chips[id] = row

	var icon := NeedIcon.new().setup(id, tint)
	icon.custom_minimum_size = Vector2(HEALTH_ICON_SIZE, HEALTH_ICON_SIZE)
	_passthrough(icon)
	row.add_child(icon)
	_icons[id] = icon

	var info := VBoxContainer.new()
	_passthrough(info)
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var label := Label.new()
	_passthrough(label)
	label.add_theme_font_size_override("font_size", 15)
	label.text = "100 / 100"
	info.add_child(label)
	_percents[id] = label

	var bar := ProgressBar.new()
	_passthrough(bar)
	bar.custom_minimum_size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	bar.add_theme_stylebox_override("background", back)
	info.add_child(bar)
	_bars[id] = bar


## El resto de las necesidades (todo menos salud), chicas y en fila.
func _build_small_needs_row(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	_passthrough(row)
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)

	for id in NeedsComponent.ORDER:
		if id == NeedsComponent.SALUD:
			continue
		var tint: Color = COLORS.get(id, Color.WHITE)

		var chip := VBoxContainer.new()
		_passthrough(chip)
		chip.add_theme_constant_override("separation", 2)
		row.add_child(chip)

		var head := HBoxContainer.new()
		# PASS (no IGNORE): habilita el tooltip con el nombre de la necesidad
		# sin comerse el clic del ataque (eso rompería con STOP).
		head.mouse_filter = Control.MOUSE_FILTER_PASS
		head.tooltip_text = str(LABELS.get(id, id))
		head.add_theme_constant_override("separation", 5)
		chip.add_child(head)

		var icon := NeedIcon.new().setup(str(id), tint)
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		_passthrough(icon)
		head.add_child(icon)
		_icons[id] = icon

		var percent := Label.new()
		_passthrough(percent)
		percent.add_theme_font_size_override("font_size", 13)
		percent.text = "100%"
		head.add_child(percent)
		_percents[id] = percent

		var bar := ProgressBar.new()
		_passthrough(bar)
		bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = tint
		bar.add_theme_stylebox_override("fill", fill)
		var bar_back := StyleBoxFlat.new()
		bar_back.bg_color = Color(0, 0, 0, 0.45)
		bar.add_theme_stylebox_override("background", bar_back)
		chip.add_child(bar)
		_bars[id] = bar

		_chips[id] = chip


## Debajo de las necesidades: mochila, arma y sigilo.
func _build_status() -> void:
	var column := VBoxContainer.new()
	_passthrough(column)
	column.add_theme_constant_override("separation", 1)
	_hud_left.add_child(column)

	_stealth_label = Label.new()
	_passthrough(_stealth_label)
	_stealth_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_stealth_label)

	_inventory_label = Label.new()
	_passthrough(_inventory_label)
	_inventory_label.add_theme_font_size_override("font_size", 13)
	_inventory_label.text = "Mochila: vacía"
	column.add_child(_inventory_label)

	_weapon_label = Label.new()
	_passthrough(_weapon_label)
	_weapon_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_weapon_label)

	# Barra de acción (talar / pescar / revisar)
	_action_box = VBoxContainer.new()
	_passthrough(_action_box)
	_action_box.visible = false
	column.add_child(_action_box)

	_action_label = Label.new()
	_passthrough(_action_label)
	_action_label.add_theme_font_size_override("font_size", 13)
	_action_box.add_child(_action_label)

	_action_bar = ProgressBar.new()
	_passthrough(_action_bar)
	_action_bar.custom_minimum_size = Vector2(150, 8)
	_action_bar.max_value = 1.0
	_action_bar.show_percentage = false
	_action_box.add_child(_action_bar)

	# Línea de mensajes: centrada abajo, anclada para que siga a la ventana.
	_message_label = Label.new()
	_passthrough(_message_label)
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 1.0
	_message_label.anchor_bottom = 1.0
	_message_label.offset_left = -350
	_message_label.offset_right = 350
	_message_label.offset_top = -70
	_message_label.offset_bottom = -46
	add_child(_message_label)

	# Recordatorio de la ayuda, chiquito abajo a la izquierda.
	var hint := Label.new()
	_passthrough(hint)
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.7, 0.72, 0.68)
	hint.text = "H — controles"
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 14.0
	hint.offset_top = -26.0
	hint.offset_right = 200.0
	hint.offset_bottom = -6.0
	add_child(hint)


## Barra de arriba a la derecha: reloj + botones para abrir mapa, crafteo y
## construcción sin depender de acordarse de las teclas.
func _build_toolbar() -> void:
	var column := VBoxContainer.new()
	# Este SÍ deja pasar el mouse a los botones hijos, pero no se come el clic.
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.offset_left = -350.0
	column.offset_right = -12.0
	column.offset_top = 10.0
	column.offset_bottom = 90.0
	column.alignment = BoxContainer.ALIGNMENT_END
	add_child(column)

	_clock_label = Label.new()
	_passthrough(_clock_label)
	_clock_label.add_theme_font_size_override("font_size", 17)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.text = ""
	column.add_child(_clock_label)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(bar)

	bar.add_child(_make_button("Mapa (M)", _toggle_map))
	bar.add_child(_make_button("Crafteo (C)", _toggle_crafting))
	bar.add_child(_make_button("Construir (B)", _toggle_build))
	bar.add_child(_make_button("?", _toggle_help))


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# Sin foco: si no, después de hacer clic la barra espaciadora volvería a
	# apretar el botón en vez de atacar.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


# --- Panel de ayuda (tecla H) ---

const HELP := [
	["Moverte", [
		["WASD / flechas", "caminar"],
		["Shift", "correr (gasta energía y hacés mucho ruido)"],
		["Ctrl", "agacharte (lento, pero casi no te escuchan)"],
	]],
	["Pelear", [
		["Mouse", "apuntás siempre hacia donde está el cursor"],
		["Clic izquierdo / Espacio", "atacar o disparar"],
		["F", "cambiar de mano (cuerpo a cuerpo <-> arma de fuego)"],
		["R", "vendarte (corta el sangrado)"],
	]],
	["Usar el mundo", [
		["E", "puerta · contenedor · fogata · talar · pescar · picar"],
		["T", "tomar agua del lago (o llenarla en el recipiente, si tenés)"],
		["Q", "comer o beber lo primero que tengas"],
		["B", "construir · C craftear (hace falta mesa de trabajo)"],
	]],
	["Pantallas", [
		["I o Tab", "mochila"],
		["M", "mapa (se destapa caminando)"],
		["H o F1", "esta ayuda"],
		["F5 / F9", "guardar / cargar"],
	]],
]


func _build_help() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.anchor_left = 0.5
	_help_panel.anchor_right = 0.5
	_help_panel.anchor_top = 0.5
	_help_panel.anchor_bottom = 0.5
	_help_panel.offset_left = -300
	_help_panel.offset_right = 300
	_help_panel.offset_top = -230
	_help_panel.offset_bottom = 230
	_help_panel.visible = false
	add_child(_help_panel)

	var margin := MarginContainer.new()
	_passthrough(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_help_panel.add_child(margin)

	var column := VBoxContainer.new()
	_passthrough(column)
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title := Label.new()
	_passthrough(title)
	title.text = "CONTROLES"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	for section in HELP:
		column.add_child(HSeparator.new())

		var header := Label.new()
		_passthrough(header)
		header.text = str(section[0])
		header.add_theme_font_size_override("font_size", 14)
		header.modulate = Color(1.0, 0.85, 0.45)
		column.add_child(header)

		for entry in section[1]:
			var line := Label.new()
			_passthrough(line)
			line.add_theme_font_size_override("font_size", 13)
			line.text = "   %s  —  %s" % [str(entry[0]), str(entry[1])]
			column.add_child(line)

	column.add_child(HSeparator.new())
	var close := Label.new()
	_passthrough(close)
	close.add_theme_font_size_override("font_size", 12)
	close.modulate = Color(0.7, 0.72, 0.68)
	close.text = "H o Esc para cerrar  ·  el juego está en pausa"
	column.add_child(close)


func _toggle_help() -> void:
	# No abrimos encima de otra pantalla modal: se pisarían la pausa.
	if not _help_panel.visible and _other_screen_open():
		return
	_help_panel.visible = not _help_panel.visible
	get_tree().paused = _help_panel.visible


## La consultan el mapa y el inventario para no abrirse encima de la ayuda: si
## se pisan, el que cierre primero despausa el juego con el otro todavía arriba.
func help_open() -> bool:
	return _help_panel != null and _help_panel.visible


func _other_screen_open() -> bool:
	for group in ["inventory_screen", "map_screen", "run_summary", "storage_screen"]:
		var screen = get_tree().get_first_node_in_group(group)
		if screen != null and screen.visible:
			return true
	for group in ["fire_minigame", "click_minigame", "fishing_minigame"]:
		var minigame = get_tree().get_first_node_in_group(group)
		if minigame != null and minigame.is_open():
			return true
	return false


# --- Actualización ---

## "Día 4 · " si hay run_manager; vacío si no (por si abrís la escena sola).
func _day_prefix() -> String:
	if _run == null or not is_instance_valid(_run):
		return ""
	return "Día %d · " % (int(_run.stats.get("dias", 0)) + 1)


func _update_weapon() -> void:
	var arms: ArmsComponent = _player_ref.arms
	var weapon: Dictionary = _player_ref.weapon_stats()
	var text := "En mano: %s  (daño %d · alcance %d)" % [
		str(weapon["nombre"]), int(weapon["dano"]), int(weapon["alcance"]),
	]
	# La munición vive en el casillero de ArmsComponent, no en la mochila.
	if bool(weapon["fuego"]):
		text += "  ·  %s: %d" % [ItemDB.display_name(str(weapon["municion"])), arms.ammo]

	# La otra mano, guardada: recordatorio de que F cambia sin abrir nada.
	var other := arms.melee if arms.active == ArmsComponent.FIREARM else arms.firearm
	if other != "":
		text += "   ·   Guardada: %s (F cambia)" % ItemDB.display_name(other)

	_weapon_label.text = text


## Chip de sigilo: lo más importante para entender por qué te encuentran.
func _update_stealth() -> void:
	var seeing := 0
	var hearing := 0
	for node in get_tree().get_nodes_in_group("hunter"):
		var hunter = node
		if not hunter.has_method("alert_level"):
			continue
		match int(hunter.alert_level()):
			2: seeing += 1
			1: hearing += 1

	if seeing > 0:
		_stealth_label.text = "◉ TE VEN (%d)" % seeing
		_stealth_label.modulate = Color(1.0, 0.35, 0.30)
	elif hearing > 0:
		_stealth_label.text = "◒ te escucharon (%d)" % hearing
		_stealth_label.modulate = Color(1.0, 0.82, 0.35)
	else:
		_stealth_label.text = "○ oculto"
		_stealth_label.modulate = Color(0.55, 0.75, 0.55)


## La barra de sangrado parpadea: es la que te mata si la ignorás.
func _blink_bleed(delta: float) -> void:
	var chip: Control = _chips.get(NeedsComponent.SANGRADO)
	var bar: ProgressBar = _bars.get(NeedsComponent.SANGRADO)
	if chip == null or bar == null:
		return
	if bar.value <= 0.0:
		return
	_blink = fmod(_blink + delta * 4.0, TAU)
	chip.modulate = Color(1, 1, 1, 0.6 + 0.4 * absf(sin(_blink)))


## La vida parpadea cuando está crítica. Nunca se apaga (ver _on_need_changed):
## esto es lo único que la distingue de "normal", además del número.
func _blink_health(delta: float) -> void:
	var chip: Control = _chips.get(NeedsComponent.SALUD)
	if chip == null:
		return
	if not _health_critical:
		chip.modulate = Color.WHITE
		return
	_health_blink = fmod(_health_blink + delta * 5.0, TAU)
	chip.modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(_health_blink)))


# --- Señales ---

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

	var ratio := 0.0 if maximum <= 0.0 else current / maximum
	var label: Label = _percents.get(id)
	if label != null:
		if id == NeedsComponent.SALUD:
			# "80/100" y no "80%": con el máximo siempre en 100 daba lo mismo,
			# pero así se lee como vida y no como un porcentaje cualquiera.
			label.text = "%d / %d" % [int(round(current)), int(round(maximum))]
		else:
			label.text = "%d%%" % int(round(ratio * 100.0))

	# El sangrado es al revés: 0 es lo bueno. Las demás, mientras más alto mejor.
	var inverted := id == NeedsComponent.SANGRADO
	var critical := ratio * 100.0 > 0.0 if inverted else ratio * 100.0 <= CRITICAL

	if id == NeedsComponent.SALUD:
		# La vida NUNCA se apaga: antes se dibujaba al 62% de opacidad mientras
		# estabas sano, que es exactamente al revés de lo que hace falta. Lo
		# único que cambia con lo crítico es que empieza a parpadear
		# (ver _blink_health).
		_health_critical = critical
		return

	var chip: Control = _chips.get(id)
	if chip != null:
		chip.modulate = Color.WHITE if critical else Color(1, 1, 1, 0.62)
	var icon: NeedIcon = _icons.get(id)
	if icon != null:
		var tint: Color = COLORS.get(id, Color.WHITE)
		icon.set_tint(tint if critical else tint.darkened(0.15))


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


func _on_message(text: String) -> void:
	_message_label.text = text
	_message_timer = MESSAGE_SECONDS


func _on_inventory_full(item: String) -> void:
	_on_message("¡Mochila llena! Necesitás una mochila más grande (%s)" % ItemDB.display_name(item))


func _on_horde(count: int) -> void:
	_on_message("¡Escuchaste ruido... vienen %d zombies!" % count)


# --- Botones de la barra ---

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
