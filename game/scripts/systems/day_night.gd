extends CanvasModulate
## Ciclo día/noche con amanecer y atardecer. Tiñe el mundo según la hora (el HUD
## no se ve afectado porque vive en otro CanvasLayer) y baja la temperatura
## ambiente del jugador de noche.
##
## Los colores salen de una tabla de momentos del día: para cambiar cómo se ve
## el atardecer alcanza con tocar la tabla, sin cambiar nada de la lógica.
##
## Es la base de la fogata: de noche no ves y te enfriás. Las fogatas prendidas
## (grupo "heat_source") suben la temperatura si estás cerca.

signal phase_changed(phase: String)
signal hour_changed(hour: float)

## Cuánto dura un día completo, en segundos reales.
@export var day_seconds := 240.0
@export var start_hour := 8.0

@export var day_ambient_temp := 70.0
@export var night_ambient_temp := 28.0

## Ojo con bajarlo más: si la noche queda demasiado oscura no se ve nada y el
## juego se vuelve injusto. Este valor deja ver siluetas sin fogata.
const NIGHT_COLOR := Color(0.32, 0.36, 0.56)   # azul de noche
const DAWN_COLOR := Color(0.92, 0.66, 0.62)    # rosa cálido del amanecer
const DAY_COLOR := Color(1.0, 1.0, 1.0)
const DUSK_COLOR := Color(1.0, 0.62, 0.40)     # naranja del atardecer

## Momentos del día: hora, color del cielo y qué tan oscuro está (0 = pleno día).
## Tiene que estar ordenada por hora y cubrir de 0 a 24.
const SKY := [
	{"h": 0.0,  "color": NIGHT_COLOR, "osc": 1.00},
	{"h": 5.0,  "color": NIGHT_COLOR, "osc": 1.00},
	{"h": 6.2,  "color": DAWN_COLOR,  "osc": 0.55},  # amanecer
	{"h": 7.5,  "color": DAY_COLOR,   "osc": 0.00},
	{"h": 18.0, "color": DAY_COLOR,   "osc": 0.00},
	{"h": 19.3, "color": DUSK_COLOR,  "osc": 0.45},  # atardecer
	{"h": 21.0, "color": NIGHT_COLOR, "osc": 1.00},
	{"h": 24.0, "color": NIGHT_COLOR, "osc": 1.00},
]

const DAWN_START := 5.0
const DAY_START := 7.5
const DUSK_START := 18.0
const NIGHT_START := 21.0

var hour := 8.0

var _phase := ""


func _ready() -> void:
	add_to_group("day_night")
	hour = clampf(start_hour, 0.0, 23.99)
	_phase = phase_name()
	_apply()


func _process(delta: float) -> void:
	# 24 horas de juego repartidas en day_seconds reales.
	hour = fmod(hour + (24.0 / maxf(day_seconds, 1.0)) * delta, 24.0)
	_apply()
	hour_changed.emit(hour)

	var current := phase_name()
	if current != _phase:
		_phase = current
		phase_changed.emit(current)


func _apply() -> void:
	var sky := _sky_at(hour)
	# Pasamos por una variable tipada para no depender de la conversión
	# automática de Variant a Color.
	var sky_color: Color = sky["color"]
	color = sky_color
	_update_player_temperature(float(sky["osc"]))


## Interpola color y oscuridad entre los dos momentos que rodean a esta hora.
func _sky_at(h: float) -> Dictionary:
	for i in range(SKY.size() - 1):
		var a: Dictionary = SKY[i]
		var b: Dictionary = SKY[i + 1]
		var ha := float(a["h"])
		var hb := float(b["h"])
		if h >= ha and h <= hb:
			var span := hb - ha
			var t := 0.0 if span <= 0.0 else (h - ha) / span
			var ca: Color = a["color"]
			var cb: Color = b["color"]
			return {
				"color": ca.lerp(cb, t),
				"osc": lerpf(float(a["osc"]), float(b["osc"]), t),
			}
	# Fuera de rango (no debería pasar): devolvemos noche cerrada.
	return {"color": NIGHT_COLOR, "osc": 1.0}


## 0.0 = pleno día, 1.0 = noche cerrada.
func darkness() -> float:
	return float(_sky_at(hour)["osc"])


func is_night() -> bool:
	return hour >= NIGHT_START or hour < DAWN_START


func is_dawn() -> bool:
	return hour >= DAWN_START and hour < DAY_START


func is_dusk() -> bool:
	return hour >= DUSK_START and hour < NIGHT_START


func phase_name() -> String:
	if is_night():
		return "Noche"
	if is_dawn():
		return "Amanecer"
	if is_dusk():
		return "Atardecer"
	return "Día"


func time_string() -> String:
	var h := int(hour)
	var m := int((hour - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]


func _update_player_temperature(dark: float) -> void:
	var player = _player()
	if player == null:
		return

	var ambient: float = lerpf(day_ambient_temp, night_ambient_temp, dark)

	# Estar cerca de una fogata prendida te abriga.
	for source in get_tree().get_nodes_in_group("heat_source"):
		if not (source is Node2D) or not source.has_method("heat_at"):
			continue
		ambient = maxf(ambient, float(source.heat_at(player.global_position)))

	player.needs.ambient_temperature = ambient


# Sin tipar: usamos player.needs, que no existe en Node2D.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")
