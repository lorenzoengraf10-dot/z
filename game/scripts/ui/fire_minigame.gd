extends CanvasLayer
## Minijuego para prender fuego por fricción.
##
## Cómo funciona:
##   1. Una aguja gira en sentido horario alrededor de un círculo.
##   2. Una porción del círculo (15%) está pintada de verde.
##   3. Tenés que apretar E justo cuando la aguja pasa por el verde.
##   4. Si acertás, empezás a hacer fricción: mantené E apretado 3 segundos.
##      Mientras hacés fricción la aguja se frena (estás con los palos, no
##      buscando el momento). Si soltás antes, el progreso se cae solo.
##   5. Cada intento fallado acelera un poco la aguja: apurarse cuesta caro.
##
## Con un mechero salteás la puntería y solo tenés que mantener 1 segundo.
##
## **El juego NO se pausa**: mientras hacés fricción el mundo sigue corriendo y
## los zombies te pueden llegar encima. Lo único que se frena es el jugador
## (`player.input_blocked`), así no podés moverte mientras forcejeás con el
## fuego. Si te apura una horda, Escape cancela.

signal finished(success: bool)

enum State { CLOSED, AIM, FRICTION, DONE }

## Porcentaje del círculo que ocupa la zona verde.
const GREEN_FRACTION := 0.15

@export var friction_seconds := 3.0
@export var lighter_seconds := 1.0
@export var needle_speed := 2.6          ## radianes por segundo
@export var speed_up_on_miss := 0.35
@export var progress_decay := 1.6        ## cuánto se cae por segundo si soltás
@export var radius := 96.0

var _state: State = State.CLOSED
var _needle := 0.0
var _green_start := 0.0
var _green_size := TAU * GREEN_FRACTION
var _progress := 0.0
var _duration := 3.0
var _speed := 2.6
var _misses := 0
var _has_lighter := false
# Sin tipar: le llamamos light_fire(), que no existe en Node.
var _campfire = null
## Evita que el mismo E que abrió el minijuego cuente como primer intento.
var _wait_release := true
var _close_timer := 0.0

var _canvas: Control
var _title: Label
var _hint: Label


func _ready() -> void:
	add_to_group("fire_minigame")
	layer = 8
	_build_ui()
	visible = false


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)

	_title = _make_label(24, -170)
	_hint = _make_label(16, 150)


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


## La llama el jugador al interactuar con una fogata apagada.
## `campfire` va sin tipo porque le pedimos light_fire(), propio de campfire.gd.
func start(campfire, has_lighter: bool = false) -> void:
	_campfire = campfire
	_has_lighter = has_lighter
	_misses = 0
	_progress = 0.0
	_needle = randf() * TAU
	_speed = needle_speed
	_wait_release = true
	_close_timer = 0.0
	# maxf evita dividir por cero al dibujar el progreso si alguien pone 0 en el
	# inspector.
	_duration = maxf(0.1, lighter_seconds if has_lighter else friction_seconds)

	# Que no quede el panel de crafteo abierto atrás del minijuego.
	var crafting = get_tree().get_first_node_in_group("crafting")
	if crafting != null and crafting.visible:
		crafting.visible = false

	# Con mechero no hay que apuntar: vas directo a la fricción.
	_state = State.FRICTION if has_lighter else State.AIM
	_randomize_green()

	visible = true
	_set_player_blocked(true)
	_update_text()


func _randomize_green() -> void:
	_green_start = randf() * TAU


func _process(delta: float) -> void:
	if _state == State.CLOSED:
		return

	# Como el juego ya no se pausa, te pueden matar en pleno minijuego.
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.needs.is_dead():
		_close(false)
		return

	# Escape siempre cancela, incluso si todavía tenés apretada la E con la que
	# abriste el minijuego.
	if Input.is_action_just_pressed("ui_cancel"):
		_close(false)
		return

	# Esperamos a que sueltes la tecla con la que abriste el minijuego, así ese
	# mismo E no cuenta como primer intento de timing.
	if _wait_release and not Input.is_action_pressed("interact"):
		_wait_release = false

	match _state:
		State.AIM:
			_needle = fmod(_needle + _speed * delta, TAU)
			if not _wait_release and Input.is_action_just_pressed("interact"):
				_try_strike()
		State.FRICTION:
			_do_friction(delta)
		State.DONE:
			_close_timer -= delta
			if _close_timer <= 0.0:
				_close(true)

	_canvas.queue_redraw()


func _try_strike() -> void:
	if _in_green():
		_state = State.FRICTION
		AudioManager.play("fuego_chispa")
	else:
		_misses += 1
		_speed += speed_up_on_miss
		_randomize_green()
	_update_text()


func _do_friction(delta: float) -> void:
	# Sirve tanto seguir apretando la E con la que abriste el minijuego como
	# volver a apretarla: en los dos casos Input.is_action_pressed da true.
	if Input.is_action_pressed("interact"):
		_progress += delta
		if _progress >= _duration:
			_succeed()
			return
	else:
		_progress = maxf(0.0, _progress - progress_decay * delta)
		if _progress <= 0.0 and not _has_lighter:
			# Se enfrió: hay que volver a acertar el timing.
			_state = State.AIM
			_randomize_green()
			_update_text()


func _succeed() -> void:
	_state = State.DONE
	_close_timer = 0.6
	_progress = _duration
	if _campfire != null and is_instance_valid(_campfire) and _campfire.has_method("light_fire"):
		_campfire.light_fire()
	_update_text()


func _close(success: bool) -> void:
	_state = State.CLOSED
	visible = false
	_set_player_blocked(false)
	_campfire = null
	finished.emit(success)


func is_open() -> bool:
	return _state != State.CLOSED


func _set_player_blocked(blocked: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.input_blocked = blocked


func _in_green() -> bool:
	var diff := fmod(_needle - _green_start + TAU, TAU)
	return diff <= _green_size


func _update_text() -> void:
	match _state:
		State.AIM:
			_title.text = "PRENDER FUEGO"
			var extra := ""
			if _misses > 0:
				extra = "   (fallaste %d: la aguja va más rápido)" % _misses
			_hint.text = "Apretá E justo cuando la aguja pase por el verde" + extra
		State.FRICTION:
			_title.text = "¡FRICCIÓN!"
			if _has_lighter:
				_hint.text = "Mantené E apretado (mechero)"
			else:
				_hint.text = "No sueltes E — si soltás, se enfría"
		State.DONE:
			_title.text = "¡FUEGO!"
			_hint.text = ""
		_:
			_title.text = ""
			_hint.text = ""


func _on_canvas_draw() -> void:
	var center: Vector2 = _canvas.size / 2.0

	# Fondo oscuro para separar el minijuego del mundo.
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0, 0, 0, 0.55))
	_canvas.draw_circle(center, radius + 34.0, Color(0.05, 0.05, 0.06, 0.9))

	# Aro base.
	_canvas.draw_arc(center, radius, 0.0, TAU, 96, Color(0.72, 0.72, 0.76), 6.0)

	# Zona verde (15% del círculo).
	_canvas.draw_arc(center, radius, _green_start, _green_start + _green_size, 32,
			Color(0.25, 0.85, 0.35), 13.0)

	# Progreso de la fricción, como anillo interior.
	if _progress > 0.0:
		var ratio := clampf(_progress / _duration, 0.0, 1.0)
		_canvas.draw_arc(center, radius - 24.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 64,
				Color(1.0, 0.55, 0.15), 11.0)

	# Aguja (gira en sentido horario).
	var tip: Vector2 = center + Vector2.RIGHT.rotated(_needle) * radius
	var needle_color := Color(1.0, 0.95, 0.6) if _state == State.AIM else Color(1.0, 0.62, 0.25)
	_canvas.draw_line(center, tip, needle_color, 4.0)
	_canvas.draw_circle(center, 8.0, Color(0.92, 0.92, 0.92))
