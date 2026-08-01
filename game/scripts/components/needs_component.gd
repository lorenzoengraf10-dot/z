class_name NeedsComponent
extends Node
## Necesidades del personaje. Todas viven en un mismo diccionario para que el
## HUD pueda dibujarlas en bucle y para poder agregar necesidades nuevas sin
## tocar el resto del código.
##
##   salud       cae por hambre/sed/frío/sangrado o por golpes. En 0 → morís.
##   hambre      baja sola con el tiempo. En 0 → perdés salud.
##   sed         baja más rápido que el hambre. En 0 → perdés salud (más rápido).
##   energia     se gasta corriendo y se recupera al no correr. En 0 → no podés correr.
##   temperatura tiende hacia la temperatura ambiente. Muy baja → perdés salud.
##   sangrado    lo abren las mordidas. Drena salud sostenido y casi no cede
##               solo: hay que vendarse. Es la única "invertida": 0 es bueno.
##
## Antes había también una necesidad de **infección**, que se sacó a propósito:
## hacía lo mismo que el sangrado (drenar salud despacio por una mordida) pero
## más lento y con una barra más para leer. Lo que hacía quedó repartido: las
## mordidas ahora sangran más, y la comida cruda y el agua sin hervir pegan
## directo a la salud.

signal need_changed(id: String, current: float, maximum: float)
signal died

const SALUD := "salud"
const HAMBRE := "hambre"
const SED := "sed"
const ENERGIA := "energia"
const TEMPERATURA := "temperatura"
const SANGRADO := "sangrado"

## Orden en que el HUD las dibuja.
const ORDER: Array[String] = [SALUD, HAMBRE, SED, ENERGIA, TEMPERATURA, SANGRADO]

## "invertida" = 0 es lo bueno (el sangrado).
const CONFIG := {
	SALUD:       {"max": 100.0, "inicial": 100.0, "invertida": false},
	HAMBRE:      {"max": 100.0, "inicial": 100.0, "invertida": false},
	SED:         {"max": 100.0, "inicial": 100.0, "invertida": false},
	ENERGIA:     {"max": 100.0, "inicial": 100.0, "invertida": false},
	TEMPERATURA: {"max": 100.0, "inicial": 70.0,  "invertida": false},
	SANGRADO:    {"max": 100.0, "inicial": 0.0,   "invertida": true},
}

# --- Ritmos (se ajustan después del playtest) ---
#
# Referencia para tocarlos: un día de juego dura `day_seconds` de day_night.gd
# (300 s). Con estos números el hambre te dura ~222 s y la sed ~238 s, así que
# en un día tenés que comer una vez y tomar agua una.
#
# La sed era 0.70 (se vaciaba en 143 s, ¡más rápido que el hambre!) y pegaba
# más fuerte que el hambre al llegar a 0 (2.6 contra 1.8). El testeo la marcó
# como demasiado agresiva. Ahora se vacía más lento que el hambre y pega
# exactamente igual — deja de ser "la necesidad injustamente dura" del grupo.
@export var hunger_decay := 0.45       ## hambre perdida por segundo
@export var thirst_decay := 0.42       ## sed perdida por segundo
@export var stamina_drain := 14.0      ## energía por segundo corriendo
@export var stamina_regen := 9.0       ## energía por segundo descansando
@export var temperature_rate := 1.5    ## qué tan rápido se acerca a la ambiente

@export var starving_damage := 1.8     ## daño/seg con hambre en 0
@export var dehydration_damage := 1.8  ## daño/seg con sed en 0
@export var freezing_damage := 1.2     ## daño/seg con temperatura muy baja

@export var cold_threshold := 25.0     ## debajo de esto empezás a congelarte

## Sangrado: es lo que más rápido te mata. No se frena solo, hay que vendarse.
@export var bleed_damage_factor := 0.06  ## daño/seg por punto de sangrado
@export var bleed_natural_stop := 0.35   ## cuánto baja solo por segundo (muy poco)
## Lo baja el perk "Sangre fría" (1.0 = normal, 0.6 = sangrás menos).
var bleed_rate_multiplier := 1.0
## Lo baja el perk "Estómago de hierro" (1.0 = normal, 0.5 = la comida cruda
## te hace la mitad de daño).
var raw_damage_multiplier := 1.0

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

	# El sangrado cede solo muy de a poco: en la práctica hay que vendarse.
	if get_need(SANGRADO) > 0.0:
		change(SANGRADO, -bleed_natural_stop * delta)

	_apply_damage_over_time(delta)


func _apply_damage_over_time(delta: float) -> void:
	var dps := 0.0
	if get_need(HAMBRE) <= 0.0:
		dps += starving_damage
	if get_need(SED) <= 0.0:
		dps += dehydration_damage
	if get_need(TEMPERATURA) <= cold_threshold:
		dps += freezing_damage
	# El sangrado pega proporcional a cuánto estés sangrando.
	dps += get_need(SANGRADO) * bleed_damage_factor
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


## Empezar (o empeorar) una hemorragia. La llaman los zombies y los lobos.
func bleed(amount: float) -> void:
	change(SANGRADO, amount * bleed_rate_multiplier)


func is_bleeding() -> bool:
	return get_need(SANGRADO) > 0.0


## Aplica los efectos de un ítem (comida, vendaje, trapo).
func consume_item(id: String) -> void:
	change(HAMBRE, ItemDB.value_of(id, "hambre"))
	change(SED, ItemDB.value_of(id, "sed"))
	change(SALUD, ItemDB.value_of(id, "cura"))
	# Lo que cae mal (carne cruda, agua sin hervir) pega directo a la salud.
	# El perk "Estómago de hierro" amortigua justo esto.
	change(SALUD, -ItemDB.value_of(id, "dano_salud") * raw_damage_multiplier)

	# Los vendajes cortan del todo; los trapos solo una parte.
	var stops := ItemDB.value_of(id, "corta_sangrado")
	if stops > 0.0:
		change(SANGRADO, -get_need(SANGRADO) * (stops / 100.0))


func to_dict() -> Dictionary:
	return _values.duplicate()


func from_dict(data: Dictionary) -> void:
	for id in ORDER:
		if data.has(id):
			set_need(id, float(data[id]))
	_dead = get_need(SALUD) <= 0.0
