extends MinigameBase
## Minijuego de pesca: pantalla de agua donde van apareciendo, por momentos,
## **zonas de burbujas**. Si le hacés clic mientras está la burbuja, pescaste;
## si no llegás a tiempo, se va y aparece otra en otro lado. Es de reacción:
## la burbuja dura poco y hay que estar mirando.
##
## Se tienen `MAX_ATTEMPTS` burbujas — si pescás en cualquiera, listo; si se
## te escapan todas, se fue el pez. No entrega el pescado por su cuenta: eso
## lo hace interactor.gd escuchando `finished` (ver _try_fish()/_on_fishing_finished).

const MAX_ATTEMPTS := 5

## Cuánto dura visible cada burbuja antes de irse si no le pegaste.
@export var bubble_lifetime := 0.85
@export var bubble_radius := 30.0
## Pausa entre que se va una burbuja y aparece la próxima.
@export var gap_min := 0.35
@export var gap_max := 0.9
## Radio (desde el centro de la pantalla) donde pueden aparecer las burbujas.
@export var play_radius := 150.0

enum State { GAP, BUBBLE, DONE }

var _state: State = State.GAP
var _timer := 0.0
var _bubble_pos := Vector2.ZERO
var _attempts_left := MAX_ATTEMPTS
var _caught := false


func _ready_extra() -> void:
	add_to_group("fishing_minigame")


func start() -> void:
	_attempts_left = MAX_ATTEMPTS
	_caught = false
	_state = State.GAP
	_timer = randf_range(gap_min, gap_max)
	_open()
	_update_text()


func _tick(delta: float) -> void:
	match _state:
		State.GAP:
			_timer -= delta
			if _timer <= 0.0:
				_spawn_bubble()
		State.BUBBLE:
			_timer -= delta
			if Input.is_action_just_pressed("attack"):
				if _click_in_bubble():
					_catch()
					return
				# Clickear afuera de la burbuja NO cuenta como intento perdido
				# (sería castigar la puntería del mouse en vez de la reacción):
				# solo importa si la burbuja se apaga sola sin que la tocaras.
			if _timer <= 0.0:
				_miss()
		State.DONE:
			_timer -= delta
			if _timer <= 0.0:
				_finish(_caught)


func _spawn_bubble() -> void:
	var angle := randf() * TAU
	var dist := randf() * play_radius
	_bubble_pos = Vector2.RIGHT.rotated(angle) * dist
	_state = State.BUBBLE
	_timer = bubble_lifetime
	_update_text()


func _click_in_bubble() -> bool:
	var center: Vector2 = canvas.size / 2.0
	var mouse: Vector2 = canvas.get_local_mouse_position() - center
	return mouse.distance_to(_bubble_pos) <= bubble_radius


func _catch() -> void:
	_caught = true
	_state = State.DONE
	_timer = 0.5
	AudioManager.play("pescar")
	_update_text()


func _miss() -> void:
	_attempts_left -= 1
	if _attempts_left <= 0:
		_state = State.DONE
		_timer = 0.6
		_update_text()
		return
	_state = State.GAP
	_timer = randf_range(gap_min, gap_max)
	_update_text()


func _update_text() -> void:
	match _state:
		State.GAP:
			title_label.text = "PESCANDO"
			hint_label.text = "Mirá el agua... quedan %d intentos" % _attempts_left
		State.BUBBLE:
			title_label.text = "¡AHORA!"
			hint_label.text = "Clic en la burbuja"
		State.DONE:
			title_label.text = "¡PESCASTE!" if _caught else "Se te escapó..."
			hint_label.text = ""


func _draw_game(canvas_ctrl: Control, center: Vector2) -> void:
	# El agua de fondo, más oscura hacia afuera para que se note el borde.
	canvas_ctrl.draw_circle(center, play_radius + 50.0, Color(0.08, 0.16, 0.24, 0.95))
	canvas_ctrl.draw_circle(center, play_radius, Color(0.14, 0.28, 0.40, 0.95))
	canvas_ctrl.draw_arc(center, play_radius, 0.0, TAU, 64, Color(0.25, 0.45, 0.58), 3.0)

	if _state == State.BUBBLE:
		var ratio := clampf(_timer / bubble_lifetime, 0.0, 1.0)
		var pos := center + _bubble_pos
		canvas_ctrl.draw_circle(pos, bubble_radius, Color(0.65, 0.90, 0.98, 0.30 + 0.35 * ratio))
		canvas_ctrl.draw_arc(pos, bubble_radius, 0.0, TAU, 24, Color(0.88, 0.97, 1.0), 3.0)
		# Aro que se achica: cuánto tiempo te queda para clickearla.
		canvas_ctrl.draw_arc(pos, bubble_radius * ratio, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.8), 2.0)

	# Puntitos de intentos que quedan, abajo.
	var start_x := center.x - float(MAX_ATTEMPTS - 1) * 10.0
	for i in range(MAX_ATTEMPTS):
		var pos := Vector2(start_x + i * 20.0, center.y + play_radius + 55.0)
		var used := i >= _attempts_left
		canvas_ctrl.draw_circle(pos, 5.0, Color(0.35, 0.35, 0.38) if used else Color(0.5, 0.8, 0.95))
