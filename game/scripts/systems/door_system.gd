extends Node2D
## Coloca una puerta por cada celda marcada con `D` en el mapa, y guarda/carga
## el estado (abierta o cerrada) de todas.
##
## El tile de puerta es caminable a propósito: la colisión la pone el nodo Door
## cuando está cerrada, así se puede abrir y pasar.

const DOOR_SCENE := "res://scenes/Door.tscn"

var _doors: Dictionary = {}   ## "x,y" -> nodo Door
var _scene: PackedScene


func _ready() -> void:
	add_to_group("door_system")
	_scene = load(DOOR_SCENE) as PackedScene
	# Diferido: esperamos a que world.gd haya pintado el nivel.
	_spawn_all.call_deferred()


func _spawn_all() -> void:
	var world = _world()
	if world == null or _scene == null:
		return
	for cell in world.door_cells():
		var key := _key(cell)
		if _doors.has(key):
			continue
		var door = _scene.instantiate()
		add_child(door)
		door.global_position = world.center_of(cell)
		_doors[key] = door


## Puerta más cercana a una posición, dentro del alcance. null si no hay.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func nearest(world_position: Vector2, reach: float):
	var best = null
	var best_dist := reach
	for key in _doors.keys():
		var door = _doors[key]
		if not is_instance_valid(door):
			continue
		var dist: float = door.global_position.distance_to(world_position)
		if dist <= best_dist:
			best_dist = dist
			best = door
	return best


# --- Guardado ---

func to_dict() -> Dictionary:
	var out := {}
	for key in _doors.keys():
		var door = _doors[key]
		if is_instance_valid(door):
			out[key] = door.to_dict()
	return out


func from_dict(data: Dictionary) -> void:
	for key in data.keys():
		var door = _doors.get(str(key))
		if door != null and is_instance_valid(door):
			var state: Variant = data[key]
			if typeof(state) == TYPE_DICTIONARY:
				door.from_dict(state)


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


# Sin tipar: usamos door_cells()/center_of(), propios de world.gd.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")
