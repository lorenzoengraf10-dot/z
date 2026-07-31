extends Node2D
## Números de daño que suben y se desvanecen.
##
## Sin esto no sabés si le estás pegando al zombi o si estás golpeando al aire,
## y menos todavía cuánto te sacó a vos la mordida. Es de las cosas más baratas
## que más cambian cómo se siente pelear.
##
## Se usa desde cualquier lado así:
##     var textos = get_tree().get_first_node_in_group("floating_text")
##     if textos != null:
##         textos.show_at(global_position, "-12", Color.YELLOW)

## Cuánto tarda en apagarse cada número.
@export var lifetime := 0.75
## Cuánto sube, en píxeles.
@export var rise := 22.0
## Para que dos números en el mismo lugar no se tapen.
@export var spread := 6.0

const DAMAGE_DEALT := Color(1.0, 0.92, 0.45)   ## el daño que hacés vos
const DAMAGE_TAKEN := Color(1.0, 0.36, 0.32)   ## el que te hacen a vos
const HEAL := Color(0.45, 0.95, 0.50)

var _live: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("floating_text")
	z_index = 40   # por encima del techo de los edificios


func _process(delta: float) -> void:
	if _live.is_empty():
		return
	var still_alive: Array[Dictionary] = []
	for item in _live:
		var age := float(item["edad"]) + delta
		var label: Label = item["label"]
		if age >= lifetime or not is_instance_valid(label):
			if is_instance_valid(label):
				label.queue_free()
			continue
		var t := age / lifetime
		var start: Vector2 = item["origen"]
		label.position = start + Vector2(0, -rise * t)
		# Se mantiene entero la primera mitad y recién ahí se desvanece.
		label.modulate.a = 1.0 if t < 0.5 else 1.0 - (t - 0.5) * 2.0
		item["edad"] = age
		still_alive.append(item)
	_live = still_alive


## Muestra un texto flotante en una posición del mundo.
func show_at(world_position: Vector2, text: String, tint: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = tint
	label.size = Vector2(60, 16)

	# El Label ancla arriba a la izquierda: lo corremos para centrarlo.
	var origin := world_position + Vector2(-30, -18)
	origin.x += randf_range(-spread, spread)
	label.position = origin
	add_child(label)

	_live.append({"label": label, "origen": origin, "edad": 0.0})


## Atajo para el daño: redondea y elige el color según quién lo recibió.
func damage(world_position: Vector2, amount: float, to_player: bool) -> void:
	if amount <= 0.0:
		return
	show_at(world_position, "-%d" % int(round(amount)),
			DAMAGE_TAKEN if to_player else DAMAGE_DEALT)
