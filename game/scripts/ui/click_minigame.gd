extends MinigameBase
## Minijuego de 3 clicks para talar, picar piedra y picar veta. Mismo molde que
## el de prender fuego (una aguja gira, apretás E cuando pasa por el verde),
## pero en vez de una sola zona son **3 rondas seguidas** y cada una tiene la
## zona verde más chica que la anterior: 20% → 15% → 10% de la vuelta.
##
## No entrega ninguna recompensa por su cuenta — eso lo hace quien lo abrió,
## escuchando la señal `finished` (ver interactor.gd: _on_click_minigame_finished).
## Así un solo minijuego sirve para tres recompensas distintas (madera, piedra,
## metal) sin saber nada de ítems.

## Fracción de la vuelta (de TAU) que ocupa la zona verde en cada ronda.
const ROUND_SIZES := [0.20, 0.15, 0.10]

@export var needle_speed := 3.4          ## radianes por segundo
## Con la herramienta correcta la aguja va más lenta: más fácil de acertar.
@export var easier_speed_mult := 0.7
@export var speed_up_on_miss := 0.4
## Techo de la aceleración por fallar, como múltiplo de la velocidad inicial.
##
## Sin tope, cada fallo sumaba 0.4 rad/s para siempre: a los ~15 errores la
## aguja era imposible de acertar y, como este minijuego no tiene forma de
## perder, la única salida era Escape (que cancela la acción entera). Ahora
## fallar sigue costando, pero siempre queda jugable.
@export var max_speed_mult := 2.0
@export var radius := 90.0

var _round := 0
var _needle := 0.0
var _green_start := 0.0
var _green_size := 0.0
var _speed := 3.4
## Velocidad con la que arrancó esta ronda: de acá sale el techo de _speed.
var _base_speed := 3.4
var _misses := 0
var _wait_release := true
var _done := false
var _close_timer := 0.0
var _label_text := ""


func _ready_extra() -> void:
	add_to_group("click_minigame")


## `label_text` es lo que se ve como título ("Talando árbol", "Picando piedra").
## `easier` afloja la velocidad si tenés la herramienta adecuada.
func start(label_text: String, easier: bool = false) -> void:
	_label_text = label_text
	_round = 0
	_misses = 0
	_base_speed = needle_speed * (easier_speed_mult if easier else 1.0)
	_speed = _base_speed
	_wait_release = true
	_done = false
	_close_timer = 0.0
	_needle = randf() * TAU
	_randomize_green()
	_open()
	_update_text()


func _randomize_green() -> void:
	_green_size = TAU * ROUND_SIZES[_round]
	_green_start = randf() * TAU


func _tick(delta: float) -> void:
	if _wait_release and not Input.is_action_pressed("interact"):
		_wait_release = false

	if _done:
		_close_timer -= delta
		if _close_timer <= 0.0:
			_finish(true)
		return

	_needle = fmod(_needle + _speed * delta, TAU)
	if not _wait_release and Input.is_action_just_pressed("interact"):
		_try_click()


func _try_click() -> void:
	if _in_green():
		AudioManager.play("golpe")
		_round += 1
		if _round >= ROUND_SIZES.size():
			_succeed()
		else:
			_randomize_green()
	else:
		_misses += 1
		_speed = minf(_speed + speed_up_on_miss, _base_speed * max_speed_mult)
		_randomize_green()
	_update_text()


func _succeed() -> void:
	_done = true
	_close_timer = 0.4


func _in_green() -> bool:
	var diff := fmod(_needle - _green_start + TAU, TAU)
	return diff <= _green_size


func _update_text() -> void:
	if _done:
		title_label.text = "¡LISTO!"
		hint_label.text = ""
		return
	title_label.text = _label_text.to_upper()
	var extra := "   (fallaste %d: la aguja va más rápido)" % _misses if _misses > 0 else ""
	hint_label.text = "Click %d de %d — apretá E cuando pase por el verde%s" % [
		_round + 1, ROUND_SIZES.size(), extra,
	]


func _draw_game(canvas_ctrl: Control, center: Vector2) -> void:
	canvas_ctrl.draw_circle(center, radius + 30.0, Color(0.05, 0.05, 0.06, 0.9))
	canvas_ctrl.draw_arc(center, radius, 0.0, TAU, 96, Color(0.72, 0.72, 0.76), 6.0)

	if not _done:
		canvas_ctrl.draw_arc(center, radius, _green_start, _green_start + _green_size, 32,
				Color(0.25, 0.85, 0.35), 13.0)
		var tip: Vector2 = center + Vector2.RIGHT.rotated(_needle) * radius
		canvas_ctrl.draw_line(center, tip, Color(1.0, 0.95, 0.6), 4.0)

	canvas_ctrl.draw_circle(center, 8.0, Color(0.92, 0.92, 0.92))

	# Puntitos de progreso (rondas ya completadas), abajo del círculo.
	var total := ROUND_SIZES.size()
	var start_x := center.x - float(total - 1) * 15.0
	for i in range(total):
		var pos := Vector2(start_x + i * 30.0, center.y + radius + 40.0)
		var done_round := i < _round
		canvas_ctrl.draw_circle(pos, 6.0, Color(0.3, 0.9, 0.4) if done_round else Color(0.4, 0.4, 0.42))
