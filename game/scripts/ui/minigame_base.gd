class_name MinigameBase
extends CanvasLayer
## Base común para los minijuegos modales (prender fuego, talar/picar, pesca).
##
## Lo que comparten los tres, sacado de `fire_minigame.gd` (el original):
##   - Un Control de pantalla completa para dibujar encima del mundo, con un
##     fondo oscuro semitransparente.
##   - Título + pista, siempre en el mismo lugar.
##   - **NO pausan el árbol**: el mundo sigue corriendo (los zombies te siguen
##     buscando) — lo único que se frena es el jugador (`input_blocked`).
##   - Escape cancela siempre, y si te matan en pleno minijuego se cierra solo.
##
## Cada minijuego hereda de este archivo (`extends "res://scripts/ui/minigame_base.gd"`)
## y solo tiene que:
##   1. Implementar `_ready_extra()` — como mínimo, `add_to_group(...)`.
##   2. Desde su propio `start(...)`, dejar listo su estado y llamar a `_open()`.
##   3. Implementar `_tick(delta)` con su lógica — se llama una vez por frame
##      mientras está abierto, después de los chequeos comunes de arriba.
##   4. Implementar `_draw_game(canvas, center)` con su propio dibujo.
##   5. Llamar a `_finish(success)` cuando termine (bien o mal).
##
## Ver `ui/fire_minigame.gd`, `ui/click_minigame.gd` y `ui/fishing_minigame.gd`.

signal finished(success: bool)

var is_active := false

var canvas: Control
var title_label: Label
var hint_label: Label


func _ready() -> void:
	layer = 8
	_build_base_ui()
	visible = false
	_ready_extra()


## La implementa cada minijuego (como mínimo, add_to_group con su propio
## nombre de grupo).
func _ready_extra() -> void:
	pass


func _build_base_ui() -> void:
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_on_canvas_draw)
	add_child(canvas)

	title_label = _make_label(24, -170)
	hint_label = _make_label(16, 150)


func _make_label(font_size: int, y_offset: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -320
	label.offset_right = 320
	label.offset_top = y_offset
	label.offset_bottom = y_offset + 34
	add_child(label)
	return label


## La llama la subclase al final de su propio start(...), una vez que ya dejó
## listo todo su estado inicial.
func _open() -> void:
	is_active = true
	visible = true
	_set_player_blocked(true)


func _process(delta: float) -> void:
	if not is_active:
		return

	# Como el juego no se pausa, te pueden matar en pleno minijuego.
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.needs.is_dead():
		_finish(false)
		return

	# Escape cancela siempre, incluso con una tecla de acción recién apretada.
	if Input.is_action_just_pressed("ui_cancel"):
		_finish(false)
		return

	_tick(delta)
	canvas.queue_redraw()


## La implementa cada minijuego con su lógica de un frame.
func _tick(_delta: float) -> void:
	pass


func _finish(success: bool) -> void:
	is_active = false
	visible = false
	_set_player_blocked(false)
	_on_finish(success)
	finished.emit(success)


## Para que la subclase limpie su propio estado (soltar la referencia a la
## fogata, etc.) justo antes de avisar con la señal.
func _on_finish(_success: bool) -> void:
	pass


func is_open() -> bool:
	return is_active


func _set_player_blocked(blocked: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.input_blocked = blocked


func _on_canvas_draw() -> void:
	var center: Vector2 = canvas.size / 2.0
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0, 0, 0, 0.55))
	_draw_game(canvas, center)


## La implementa cada minijuego para dibujar lo suyo.
func _draw_game(_canvas: Control, _center: Vector2) -> void:
	pass
