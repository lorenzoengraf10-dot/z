extends CanvasLayer
## Pantalla que aparece al morir: cuánto duraste, qué hiciste y qué perks
## desbloqueaste. Desde acá se arranca la partida siguiente.
##
## Los perks son lo único que sobrevive a la muerte, así que la pantalla les da
## protagonismo: es la recompensa por haber aguantado.

var _panel: PanelContainer
var _title: Label
var _stats: Label
var _perks: Label
var _button: Button


func _ready() -> void:
	add_to_group("run_summary")
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

	# Esperamos un frame para que run_manager ya esté en el árbol.
	await get_tree().process_frame
	var run = get_tree().get_first_node_in_group("run_manager")
	if run != null:
		run.run_ended.connect(_on_run_ended)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -240
	_panel.offset_right = 240
	_panel.offset_top = -180
	_panel.offset_bottom = 180
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title = Label.new()
	_title.text = "MORISTE"
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate = Color(0.9, 0.25, 0.25)
	column.add_child(_title)

	column.add_child(HSeparator.new())

	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 15)
	column.add_child(_stats)

	_perks = Label.new()
	_perks.add_theme_font_size_override("font_size", 14)
	_perks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_perks.custom_minimum_size = Vector2(0, 70)
	column.add_child(_perks)

	_button = Button.new()
	_button.text = "Empezar de nuevo"
	_button.custom_minimum_size = Vector2(0, 40)
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_restart)
	column.add_child(_button)


func _on_run_ended(summary: Dictionary) -> void:
	var rows: Array[String] = [
		"Días sobrevividos:   %d" % int(summary.get("dias", 0)),
		"Zombies eliminados:  %d" % int(summary.get("zombies", 0)),
		"Lobos eliminados:    %d" % int(summary.get("lobos", 0)),
		"Lugares saqueados:   %d" % int(summary.get("contenedores", 0)),
		"",
		"Tu récord: %d días   ·   partida n° %d" % [
			int(summary.get("mejor_dias", 0)), int(summary.get("partidas", 0)),
		],
	]
	_stats.text = "\n".join(rows)

	var unlocked: Array = summary.get("nuevos_perks", [])
	if unlocked.is_empty():
		_perks.text = "No desbloqueaste perks esta vez. Aguantá más días para conseguirlos."
		_perks.modulate = Color(0.7, 0.7, 0.72)
	else:
		var names: Array[String] = []
		for perk in unlocked:
			names.append("%s — %s" % [str(perk.get("nombre", "?")), str(perk.get("descripcion", ""))])
		_perks.text = "¡PERK NUEVO!\n" + "\n".join(names)
		_perks.modulate = Color(1.0, 0.85, 0.35)

	visible = true
	get_tree().paused = true


func _on_restart() -> void:
	visible = false
	var run = get_tree().get_first_node_in_group("run_manager")
	if run != null:
		run.restart()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()
