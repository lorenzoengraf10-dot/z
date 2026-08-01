extends MinigameBase
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
## El resto (fondo, título/pista, que no pausa el árbol, Escape cancela) sale
## de ui/minigame_base.gd.

enum State { AIM, FRICTION, DONE }

## Porcentaje del círculo que ocupa la zona verde.
const GREEN_FRACTION := 0.15

@export var friction_seconds := 3.0
@export var lighter_seconds := 1.0
@export var needle_speed := 2.6          ## radianes por segundo
@export var speed_up_on_miss := 0.35
@export var progress_decay := 1.6        ## cuánto se cae por segundo si soltás
@export var radius := 96.0

var _state: State = State.AIM
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


func _ready_extra() -> void:
	add_to_group("fire_minigame")


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

	_open()
	_update_text()


func _randomize_green() -> void:
	_green_start = randf() * TAU


func _tick(delta: float) -> void:
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
				_finish(true)


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


func _on_finish(_success: bool) -> void:
	_campfire = null


func _in_green() -> bool:
	var diff := fmod(_needle - _green_start + TAU, TAU)
	return diff <= _green_size


func _update_text() -> void:
	match _state:
		State.AIM:
			title_label.text = "PRENDER FUEGO"
			var extra := ""
			if _misses > 0:
				extra = "   (fallaste %d: la aguja va más rápido)" % _misses
			hint_label.text = "Apretá E justo cuando la aguja pase por el verde" + extra
		State.FRICTION:
			title_label.text = "¡FRICCIÓN!"
			if _has_lighter:
				hint_label.text = "Mantené E apretado (mechero)"
			else:
				hint_label.text = "No sueltes E — si soltás, se enfría"
		State.DONE:
			title_label.text = "¡FUEGO!"
			hint_label.text = ""


func _draw_game(canvas_ctrl: Control, center: Vector2) -> void:
	canvas_ctrl.draw_circle(center, radius + 34.0, Color(0.05, 0.05, 0.06, 0.9))

	# Aro base.
	canvas_ctrl.draw_arc(center, radius, 0.0, TAU, 96, Color(0.72, 0.72, 0.76), 6.0)

	# Zona verde (15% del círculo).
	canvas_ctrl.draw_arc(center, radius, _green_start, _green_start + _green_size, 32,
			Color(0.25, 0.85, 0.35), 13.0)

	# Progreso de la fricción, como anillo interior.
	if _progress > 0.0:
		var ratio := clampf(_progress / _duration, 0.0, 1.0)
		canvas_ctrl.draw_arc(center, radius - 24.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 64,
				Color(1.0, 0.55, 0.15), 11.0)

	# Aguja (gira en sentido horario).
	var tip: Vector2 = center + Vector2.RIGHT.rotated(_needle) * radius
	var needle_color := Color(1.0, 0.95, 0.6) if _state == State.AIM else Color(1.0, 0.62, 0.25)
	canvas_ctrl.draw_line(center, tip, needle_color, 4.0)
	canvas_ctrl.draw_circle(center, 8.0, Color(0.92, 0.92, 0.92))
