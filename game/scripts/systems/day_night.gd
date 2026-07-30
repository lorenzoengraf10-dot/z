extends CanvasModulate
## Ciclo día/noche. Oscurece el mundo de noche (el HUD no se ve afectado porque
## vive en otro CanvasLayer) y baja la temperatura ambiente del jugador.
##
## Es la base para que la fogata tenga sentido: de noche no ves y te enfriás.
## Las fogatas prendidas (grupo "heat_source") suben la temperatura si estás cerca.

signal phase_changed(night: bool)
signal hour_changed(hour: float)

## Cuánto dura un día completo, en segundos reales.
@export var day_seconds := 240.0
@export var start_hour := 8.0

@export var day_color := Color(1.0, 1.0, 1.0)
@export var night_color := Color(0.22, 0.26, 0.42)
## Horas en las que arranca y termina la transición.
@export var dusk_start := 19.0
@export var night_start := 21.0
@export var dawn_start := 5.0
@export var day_start := 7.0

@export var day_ambient_temp := 70.0
@export var night_ambient_temp := 28.0

var hour := 8.0

var _was_night := false


func _ready() -> void:
	add_to_group("day_night")
	hour = start_hour
	_apply()


func _process(delta: float) -> void:
	# 24 horas de juego repartidas en day_seconds reales.
	hour = fmod(hour + (24.0 / day_seconds) * delta, 24.0)
	_apply()
	hour_changed.emit(hour)

	var night := is_night()
	if night != _was_night:
		_was_night = night
		phase_changed.emit(night)


func _apply() -> void:
	var darkness := _darkness_at(hour)
	color = day_color.lerp(night_color, darkness)
	_update_player_temperature(darkness)


## 0.0 = pleno día, 1.0 = noche cerrada.
func _darkness_at(h: float) -> float:
	if h >= night_start or h < dawn_start:
		return 1.0
	if h >= day_start and h < dusk_start:
		return 0.0
	if h >= dusk_start and h < night_start:
		return inverse_lerp(dusk_start, night_start, h)
	# amanecer
	return 1.0 - inverse_lerp(dawn_start, day_start, h)


func is_night() -> bool:
	return _darkness_at(hour) > 0.5


func time_string() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


func _update_player_temperature(darkness: float) -> void:
	var player = _player()
	if player == null:
		return

	var ambient: float = lerpf(day_ambient_temp, night_ambient_temp, darkness)

	# Estar cerca de una fogata prendida te abriga.
	for source in get_tree().get_nodes_in_group("heat_source"):
		if not (source is Node2D) or not source.has_method("heat_at"):
			continue
		ambient = maxf(ambient, source.heat_at(player.global_position))

	player.needs.ambient_temperature = ambient


# Sin tipar: usamos player.needs, que no existe en Node2D.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
