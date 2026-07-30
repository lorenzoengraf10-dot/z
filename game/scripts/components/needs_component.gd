class_name NeedsComponent
extends Node
## Necesidades del personaje. Todas viven en un mismo diccionario para que el
## HUD pueda dibujarlas en bucle y para poder agregar necesidades nuevas sin
## tocar el resto del código.
##
##   salud       cae por hambre/sed/frío/infección o por golpes. En 0 → morís.
##   hambre      baja sola con el tiempo. En 0 → perdés salud.
##   sed         baja más rápido que el hambre. En 0 → perdés salud (más rápido).
##   energia     se gasta corriendo y se recupera al no correr. En 0 → no podés correr.
##   temperatura tiende hacia la temperatura ambiente. Muy baja → perdés salud.
##   infeccion   sube por mordeduras y carne cruda. Alta → perdés salud. Es la
##               única necesidad "invertida": 0 es bueno, 100 es malo.

signal need_changed(id: String, current: float, maximum: float)
signal died

const SALUD := "salud"
const HAMBRE := "hambre"
const SED := "sed"
const ENERGIA := "energia"
const TEMPERATURA := "temperatura"
const INFECCION := "infeccion"

## Orden en que el HUD las dibuja.
const ORDER: Array[String] = [SALUD, HAMBRE, SED, ENERGIA, TEMPERATURA, INFECCION]

## "invertida" = 0 es lo bueno (solo infección).
const CONFIG := {
	SALUD:       {"max": 100.0, "inicial": 100.0, "invertida": false},
	HAMBRE:      {"max": 100.0, "inicial": 100.0, "invertida": false},
	SED:         {"max": 100.0, "inicial": 100.0, "invertida": false},
	ENERGIA:     {"max": 100.0, "inicial": 100.0, "invertida": false},
	TEMPERATURA: {"max": 100.0, "inicial": 70.0,  "invertida": false},
	INFECCION:   {"max": 100.0, "inicial": 0.0,   "invertida": true},
}

# --- Ritmos (se ajustan después del playtest) ---
@export var hunger_decay := 0.55       ## hambre perdida por segundo
@export var thirst_decay := 0.85       ## sed perdida por segundo
@export var stamina_drain := 14.0      ## energía por segundo corriendo
@export var stamina_regen := 9.0       ## energía por segundo descansando
@export var temperature_rate := 1.5    ## qué tan rápido se acerca a la ambiente

@export var starving_damage := 1.8     ## daño/seg con hambre en 0
@export var dehydration_damage := 2.6  ## daño/seg con sed en 0
@export var freezing_damage := 1.2     ## daño/seg con temperatura muy baja
@export var infection_damage := 1.0    ## daño/seg con infección alta

@export var cold_threshold := 25.0     ## debajo de esto empezás a congelarte
@export var infection_threshold := 35.0 ## arriba de esto la infección hace daño
@export var infection_growth := 0.45   ## cuánto crece sola por segundo si ya empezó

## Temperatura del ambiente hacia la que tiende el cuerpo. La puede cambiar el
## clima, la noche o estar cerca de una fogata.
var ambient_temperature := 70.0
## Esfuerzo actual, lo setea el jugador cada frame: 0 = quieto/caminando, 1 = corriendo.
var exertion := 0.0

var _values: Dictionary = {}
var _dead := false


func _ready() -> void:
	for id in ORDER:
		_values[id] = float(CONFIG[id]["inicial"])


func _process(delta: float) -> void:
	if _dead:
		return

	change(HAMBRE, -hunger_decay * delta)
	change(SED, -thirst_decay * delta)

	if exertion > 0.0:
		change(ENERGIA, -stamina_drain * exertion * delta)
	else:
		change(ENERGIA, stamina_regen * delta)

	# La temperatura corporal tiende a la del ambiente.
	var temp := get_need(TEMPERATURA)
	var diff := ambient_temperature - temp
	if absf(diff) > 0.01:
		change(TEMPERATURA, signf(diff) * minf(absf(diff), temperature_rate * delta))

	# Una vez que arrancó, la infección crece sola.
	if get_need(INFECCION) > 0.0:
		change(INFECCION, infection_growth * delta)

	_apply_damage_over_time(delta)


func _apply_damage_over_time(delta: float) -> void:
	var dps := 0.0
	if get_need(HAMBRE) <= 0.0:
		dps += starving_damage
	if get_need(SED) <= 0.0:
		dps += dehydration_damage
	if get_need(TEMPERATURA) <= cold_threshold:
		dps += freezing_damage
	if get_need(INFECCION) >= infection_threshold:
		dps += infection_damage
	if dps > 0.0:
		change(SALUD, -dps * delta)


# --- API ---

func get_need(id: String) -> float:
	return float(_values.get(id, 0.0))


func max_of(id: String) -> float:
	var cfg: Variant = CONFIG.get(id, {})
	if typeof(cfg) != TYPE_DICTIONARY:
		return 100.0
	return float(cfg.get("max", 100.0))


func is_inverted(id: String) -> bool:
	var cfg: Variant = CONFIG.get(id, {})
	if typeof(cfg) != TYPE_DICTIONARY:
		return false
	return bool(cfg.get("invertida", false))


func set_need(id: String, value: float) -> void:
	if not _values.has(id):
		return
	var clamped := clampf(value, 0.0, max_of(id))
	if is_equal_approx(clamped, float(_values[id])):
		return
	_values[id] = clamped
	need_changed.emit(id, clamped, max_of(id))
	if id == SALUD and clamped <= 0.0 and not _dead:
		_dead = true
		died.emit()


func change(id: String, delta_value: float) -> void:
	set_need(id, get_need(id) + delta_value)


func is_dead() -> bool:
	return _dead


func can_run() -> bool:
	return get_need(ENERGIA) > 1.0


# --- Atajos usados por el resto del juego ---

func damage(amount: float) -> void:
	change(SALUD, -amount)


func heal(amount: float) -> void:
	change(SALUD, amount)


func infect(amount: float) -> void:
	change(INFECCION, amount)


## Aplica los efectos de un ítem comestible (hambre, sed, infección, cura).
func consume_item(id: String) -> void:
	change(HAMBRE, ItemDB.value_of(id, "hambre"))
	change(SED, ItemDB.value_of(id, "sed"))
	change(INFECCION, ItemDB.value_of(id, "infeccion"))
	change(SALUD, ItemDB.value_of(id, "cura"))
	change(INFECCION, -ItemDB.value_of(id, "cura_infeccion"))


func to_dict() -> Dictionary:
	return _values.duplicate()


func from_dict(data: Dictionary) -> void:
	for id in ORDER:
		if data.has(id):
			set_need(id, float(data[id]))
	_dead = get_need(SALUD) <= 0.0
