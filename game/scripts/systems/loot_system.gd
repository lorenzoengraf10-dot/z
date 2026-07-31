extends Node2D
## Reparte contenedores saqueables **dentro de los edificios**.
##
## Usa las celdas de piso de madera (`,`) del mapa, que son las mismas que
## `roof_system.gd` usa para saber qué es interior. Así los edificios dejan de
## ser decorado: entrás a revisarlos.
##
## Los contenedores se pegan contra las paredes (una celda de piso que toca una
## pared), que es donde uno espera encontrar un armario, y nunca tapan la puerta.

const CONTAINER_SCENE := "res://scenes/Container.tscn"
const FLOOR := ","
const WALL := "#"
const DOOR := "D"

## Cuántas celdas de piso por contenedor (más chico = más contenedores).
@export var cells_per_container := 7
@export var max_per_building := 4

## Con qué frecuencia sale cada tipo. La caja militar es la rara.
const TYPE_WEIGHTS := {
	"armario": 40,
	"cajon": 30,
	"botiquin": 18,
	"militar": 12,
}

var _scene: PackedScene
var _containers: Dictionary = {}   ## "x,y" -> nodo


func _ready() -> void:
	add_to_group("loot_system")
	_scene = load(CONTAINER_SCENE) as PackedScene
	# Diferido: esperamos a que world.gd termine de pintar el nivel.
	_populate.call_deferred()


func _populate() -> void:
	var world = _world()
	if world == null or _scene == null:
		return

	for room in _rooms(world):
		var spots := _wall_spots(room, world)
		spots.shuffle()
		var wanted := clampi(int(room.size() / float(cells_per_container)), 1, max_per_building)
		for i in range(mini(wanted, spots.size())):
			_spawn(spots[i], _random_type(), world)


## Agrupa las celdas de piso en edificios (mismo criterio que roof_system.gd).
func _rooms(world) -> Array:
	var bounds: Rect2i = world.bounds()
	var pending := {}
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if world.char_at_cell(cell) == FLOOR:
				pending[_key(cell)] = cell

	var rooms: Array = []
	while not pending.is_empty():
		var start: Vector2i = pending[pending.keys()[0]]
		var group: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			var key := _key(cell)
			if not pending.has(key):
				continue
			pending.erase(key)
			group.append(cell)
			queue.append(cell + Vector2i.RIGHT)
			queue.append(cell + Vector2i.LEFT)
			queue.append(cell + Vector2i.UP)
			queue.append(cell + Vector2i.DOWN)
		if group.size() >= 4:
			rooms.append(group)
	return rooms


## Celdas de piso pegadas a una pared, que no estén al lado de la puerta.
func _wall_spots(room: Array, world) -> Array:
	var spots: Array = []
	for cell in room:
		var touches_wall := false
		var touches_door := false
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var ch: String = world.char_at_cell(cell + offset)
			if ch == WALL:
				touches_wall = true
			elif ch == DOOR:
				touches_door = true
		if touches_wall and not touches_door:
			spots.append(cell)
	return spots


func _random_type() -> String:
	var total := 0
	for key in TYPE_WEIGHTS.keys():
		total += int(TYPE_WEIGHTS[key])
	var pick := randi_range(1, maxi(total, 1))
	var running := 0
	for key in TYPE_WEIGHTS.keys():
		running += int(TYPE_WEIGHTS[key])
		if pick <= running:
			return str(key)
	return "armario"


func _spawn(cell: Vector2i, container_type: String, world) -> void:
	var key := _key(cell)
	if _containers.has(key):
		return
	var node = _scene.instantiate()
	node.container_type = container_type
	add_child(node)
	node.global_position = world.center_of(cell)
	_containers[key] = node


## Contenedor más cercano dentro del alcance, o null.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func nearest(world_position: Vector2, reach: float):
	var best = null
	var best_dist := reach
	for key in _containers.keys():
		var node = _containers[key]
		if not is_instance_valid(node):
			continue
		var dist: float = node.global_position.distance_to(world_position)
		if dist <= best_dist:
			best_dist = dist
			best = node
	return best


func total() -> int:
	return _containers.size()


# --- Guardado ---

func to_dict() -> Dictionary:
	var out := {}
	for key in _containers.keys():
		var node = _containers[key]
		if is_instance_valid(node):
			out[key] = node.to_dict()
	return out


func from_dict(data: Dictionary) -> void:
	for key in data.keys():
		var node = _containers.get(str(key))
		if node != null and is_instance_valid(node):
			var state: Variant = data[key]
			if typeof(state) == TYPE_DICTIONARY:
				node.from_dict(state)


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


# Sin tipar: usamos bounds()/char_at_cell()/center_of(), propios de world.gd.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")
