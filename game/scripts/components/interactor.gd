class_name Interactor
extends Node
## Acción contextual del jugador (tecla E). Mira el tile que tenés enfrente y
## decide qué hacer con él:
##   árbol → talás y conseguís madera (hace mucho ruido: los zombies te oyen)
##   agua  → pescás y de paso tomás agua (sacia la sed, pero el agua sin hervir
##           te suma un poco de infección)
##
## Las acciones llevan tiempo y se cancelan si te movés.

signal action_started(label: String, duration: float)
signal action_progress(ratio: float)
signal action_ended(message: String)

const TREE := "T"
const WATER := "~"
const GRASS := "."

@export var reach := 18.0
@export var chop_seconds := 1.8
@export var fish_seconds := 3.5
@export var chop_noise := 170.0
@export var wood_per_tree := 3
@export var fish_chance := 0.65
@export var dirty_water_infection := 5.0

var _kind := ""
var _elapsed := 0.0
var _duration := 0.0
var _cell := Vector2i.ZERO
var _anchor := Vector2.ZERO

# Sin tipar a propósito: accedemos a propiedades del jugador (inventory, needs,
# facing, action_noise) que no existen en Node2D, y GDScript valida los tipos
# estáticos al compilar.
@onready var _player = get_parent()


func _process(delta: float) -> void:
	if _kind == "":
		return

	# Moverse cancela la acción.
	if _player.global_position.distance_to(_anchor) > 6.0:
		_reset()
		action_ended.emit("Acción cancelada")
		return

	_elapsed += delta
	action_progress.emit(clampf(_elapsed / _duration, 0.0, 1.0))
	if _elapsed >= _duration:
		_complete()


func is_busy() -> bool:
	return _kind != ""


## La llama el jugador cuando apretás E.
func try_interact() -> void:
	if is_busy():
		_reset()
		action_ended.emit("Acción cancelada")
		return

	var world := _world()
	if world == null:
		return

	var target: Vector2 = _player.global_position + _player.facing * reach
	var cell: Vector2i = world.cell_at(target)
	match world.char_at_cell(cell):
		TREE:
			_begin("talar", "Talando árbol...", chop_seconds, cell)
		WATER:
			_begin("pescar", "Pescando...", fish_seconds, cell)
		_:
			action_ended.emit("Nada para hacer acá")


func cancel() -> void:
	if is_busy():
		_reset()
		action_ended.emit("Acción cancelada")


func _begin(kind: String, label: String, duration: float, cell: Vector2i) -> void:
	_kind = kind
	_duration = maxf(duration, 0.1)
	_elapsed = 0.0
	_cell = cell
	_anchor = _player.global_position
	if kind == "talar":
		_player.action_noise = chop_noise
	action_started.emit(label, _duration)
	action_progress.emit(0.0)


func _complete() -> void:
	var kind := _kind
	var cell := _cell
	_reset()

	var message := ""
	match kind:
		"talar":
			var world := _world()
			if world != null:
				world.set_char_at_cell(cell, GRASS)
			_player.inventory.add("madera", wood_per_tree)
			message = "+%d madera" % wood_per_tree
		"pescar":
			_player.needs.set_need(NeedsComponent.SED, _player.needs.max_of(NeedsComponent.SED))
			_player.needs.infect(dirty_water_infection)
			if randf() < fish_chance:
				_player.inventory.add("pescado", 1)
				message = "+1 pescado · tomaste agua (sin hervir)"
			else:
				message = "Se escapó... pero tomaste agua (sin hervir)"

	action_ended.emit(message)


func _reset() -> void:
	_kind = ""
	_elapsed = 0.0
	_duration = 0.0
	_player.action_noise = 0.0


# Sin tipar: usamos cell_at/char_at_cell/set_char_at_cell, que son de world.gd
# y no existen en Node.
func _world():
	return get_tree().get_first_node_in_group("world")
