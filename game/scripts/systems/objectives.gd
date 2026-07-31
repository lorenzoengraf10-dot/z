extends CanvasLayer
## Objetivos suaves del arranque de cada partida.
##
## Con spawn al azar, aparecés en el medio de la nada sin ninguna pista de qué
## se supone que hagas. Esto no es una campaña ni una lista de misiones: son
## cuatro cosas que te empujan a descubrir los sistemas del juego, se tachan
## solas y después desaparecen para no molestar.
##
## Cada objetivo se engancha a señales que ya existen, así que no hay lógica
## de juego duplicada acá: esto solo mira y tacha.

## Cuánto queda en pantalla el cartel de "listo" antes de borrarse.
@export var done_seconds := 4.0
## Se esconde entero cuando terminaste todos.
@export var fade_seconds := 3.0

const DONE := Color(0.55, 0.85, 0.55)
const PENDING := Color(0.92, 0.92, 0.88)

## id -> texto. El orden es el orden en que se muestran.
const GOALS: Array[Dictionary] = [
	{"id": "saquear", "texto": "Entrá a un edificio y revisalo"},
	{"id": "comida", "texto": "Conseguí algo para comer"},
	{"id": "fuego", "texto": "Prendé una fogata antes de que sea de noche"},
	{"id": "noche", "texto": "Sobreviví la primera noche"},
]

var _done: Dictionary = {}
var _rows: Dictionary = {}   ## id -> Label
var _panel: VBoxContainer
var _hide_timer := 0.0


func _ready() -> void:
	add_to_group("objectives")
	layer = 2
	_build_ui()
	await get_tree().process_frame
	_connect_signals()


func _build_ui() -> void:
	_panel = VBoxContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -320.0
	_panel.offset_right = -14.0
	_panel.offset_top = 74.0
	_panel.offset_bottom = 180.0
	_panel.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_panel)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "PARA ARRANCAR"
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.modulate = Color(0.75, 0.75, 0.7)
	_panel.add_child(title)

	for goal in GOALS:
		var id := str(goal["id"])
		var row := Label.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_font_size_override("font_size", 13)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.text = "○  %s" % str(goal["texto"])
		row.modulate = PENDING
		_panel.add_child(row)
		_rows[id] = row


func _connect_signals() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var inventory: InventoryComponent = player.get_node_or_null("InventoryComponent")
		if inventory != null:
			inventory.changed.connect(_on_inventory_changed)
			_on_inventory_changed(inventory.items)

	var day_night = get_tree().get_first_node_in_group("day_night")
	if day_night != null:
		day_night.phase_changed.connect(_on_phase_changed)

	# Los contenedores se crean después que nosotros, así que en vez de
	# conectarnos a cada uno miramos el contador de la partida.
	var run = get_tree().get_first_node_in_group("run_manager")
	if run != null:
		run.run_ended.connect(_on_run_ended)


func _process(delta: float) -> void:
	# Objetivo de saqueo: lo lleva run_manager, que ya cuenta los contenedores.
	if not _done.has("saquear"):
		var run = get_tree().get_first_node_in_group("run_manager")
		if run != null and int(run.stats.get("contenedores", 0)) > 0:
			complete("saquear")

	# Objetivo de la fogata: alcanza con que haya una prendida cerca tuyo.
	if not _done.has("fuego"):
		for node in get_tree().get_nodes_in_group("campfire"):
			var fire = node
			if fire.has_method("is_lit") and fire.is_lit():
				complete("fuego")
				break

	if _hide_timer > 0.0:
		_hide_timer -= delta
		_panel.modulate.a = clampf(_hide_timer / fade_seconds, 0.0, 1.0)
		if _hide_timer <= 0.0:
			_panel.visible = false


## Tacha un objetivo. Es idempotente: llamarla dos veces no hace nada.
func complete(id: String) -> void:
	if _done.has(id) or not _rows.has(id):
		return
	_done[id] = true

	var row: Label = _rows[id]
	row.text = row.text.replace("○", "✓")
	row.modulate = DONE

	if _done.size() >= GOALS.size():
		_hide_timer = fade_seconds


func _on_inventory_changed(items: Dictionary) -> void:
	if _done.has("comida"):
		return
	for id in items.keys():
		if ItemDB.is_edible(str(id)):
			complete("comida")
			return


func _on_phase_changed(phase: String) -> void:
	# Pasar de noche a amanecer es haber sobrevivido la noche.
	if phase == "Amanecer":
		complete("noche")


func _on_run_ended(_stats: Dictionary) -> void:
	# Partida nueva, objetivos nuevos: la escena se recarga entera, así que solo
	# hace falta no seguir tachando nada de la anterior.
	set_process(false)
