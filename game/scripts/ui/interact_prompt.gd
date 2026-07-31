extends Node2D
## Cartelito flotante que te dice qué va a hacer la **E** ahora mismo.
##
## Es lo que más se nota al jugar: antes te acercabas a un armario, apretabas E
## y a ver qué pasaba. Ahora ves "E — Revisar armario" y un recuadro sobre lo
## que vas a usar.
##
## No decide nada por su cuenta: le pregunta a `interactor.peek()`, el mismo
## código que ejecuta la acción, así el cartel nunca miente.

## Color del recuadro y del texto.
@export var tint := Color(1.0, 0.90, 0.45)
@export var blocked_tint := Color(0.62, 0.62, 0.60)
## Cada cuánto se vuelve a preguntar (no hace falta cada frame).
@export var refresh_seconds := 0.12

var _label: Label
var _target_position := Vector2.ZERO
var _has_target := false
var _blocked := false
var _timer := 0.0
var _interactor = null


func _ready() -> void:
	add_to_group("interact_prompt")
	z_index = 30   # por encima del techo de los edificios

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El Label vive en coordenadas de mundo: lo centramos a mano sobre el objeto.
	_label.custom_minimum_size = Vector2(160, 0)
	_label.size = Vector2(160, 16)
	add_child(_label)
	_label.visible = false


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = refresh_seconds
	_refresh()


func _refresh() -> void:
	if _interactor == null or not is_instance_valid(_interactor):
		_interactor = _find_interactor()
		if _interactor == null:
			return

	# Mientras estás talando/pescando el HUD ya muestra la barra de progreso.
	if _interactor.is_busy():
		_hide()
		return

	var found: Dictionary = _interactor.peek()
	if found.is_empty():
		_hide()
		return

	_target_position = found["posicion"]
	_has_target = true
	# "Ya lo revisaste" y "Necesitás un pico" son avisos, no acciones.
	var text := str(found["texto"])
	_blocked = text.begins_with("Ya ") or text.begins_with("Necesitás")

	_label.text = text if _blocked else "E — %s" % text
	_label.modulate = blocked_tint if _blocked else tint
	_label.position = _target_position + Vector2(-80, -30)
	_label.visible = true
	queue_redraw()


func _hide() -> void:
	if not _has_target:
		return
	_has_target = false
	_label.visible = false
	queue_redraw()


func _draw() -> void:
	if not _has_target:
		return
	# Recuadro sobre la celda/objeto que vas a usar.
	var rect := Rect2(_target_position - Vector2(9, 9), Vector2(18, 18))
	draw_rect(rect, blocked_tint if _blocked else tint, false, 1.5)


# Sin tipar: le pedimos peek()/is_busy(), que no existen en Node.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _find_interactor():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Interactor")
