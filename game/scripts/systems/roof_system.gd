extends Node2D
## Techos de los edificios.
##
## Un edificio se define por su **piso de madera** (el tile `,` del mapa): cada
## grupo de celdas de piso pegadas entre sí es una habitación, y su techo cubre
## ese piso más las paredes y puertas que lo rodean.
##
## Desde afuera ves el techo tapando todo el edificio; al entrar, ese techo se
## oculta y ves el interior.
##
## **La puerta NO se tapa.** Antes sí, y el resultado era que desde afuera el
## edificio era un rectángulo liso donde no se sabía por dónde entrar. Dejando
## el hueco se ve el nodo Door de verdad, que además ya se dibuja distinto según
## esté abierta o cerrada: de un vistazo sabés dónde está la puerta y cómo está.
##
## Las paredes van de un color más oscuro que el interior, así el edificio tiene
## un borde y se lee como una construcción y no como una mancha.
##
## Se probó detectarlo con un flood fill desde el borde del mapa (todo lo
## caminable que no se alcanza desde afuera = interior), pero eso también toma
## los claros del bosque cerrados por árboles: en el mapa actual daba 501 celdas
## "interiores" cuando los edificios tienen 229. Con el piso de madera queda
## exacto, y además es más fácil de dibujar para quien haga niveles: paredes,
## piso y una puerta.

const FLOOR := ","
const WALL := "#"
const DOOR := "D"

## Color del techo visto desde afuera.
@export var roof_color := Color(0.34, 0.29, 0.26)
## Color del borde (las paredes). Más oscuro, para que el edificio tenga forma.
@export var roof_edge_color := Color(0.22, 0.18, 0.16)

var _rooms: Array[Node2D] = []
## "x,y" -> índice de habitación (incluye interiores y sus puertas)
var _cell_room: Dictionary = {}
var _current_room := -1


func _ready() -> void:
	add_to_group("roof_system")
	z_index = 20  # por encima del mundo y de lo que haya adentro
	# Diferido: esperamos a que world.gd termine de pintar el nivel.
	_build.call_deferred()


func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var world = _world()
	if world == null:
		return

	var room := int(_cell_room.get(_key(world.cell_at(player.global_position)), -1))
	if room == _current_room:
		return
	_current_room = room
	for i in range(_rooms.size()):
		_rooms[i].visible = i != room


func _build() -> void:
	var world = _world()
	if world == null:
		return

	var bounds: Rect2i = world.bounds()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return

	# Juntamos todas las celdas de piso de madera: son los interiores.
	var interior := {}
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if world.char_at_cell(cell) == FLOOR:
				interior[_key(cell)] = cell

	_group_into_rooms(interior, world)


## Separa las celdas interiores en habitaciones conectadas y arma un techo por
## cada una (incluyendo las paredes y puertas que la rodean, para que desde
## afuera se vea un bloque tapado).
func _group_into_rooms(interior: Dictionary, world) -> void:
	var pending := interior.duplicate()

	while not pending.is_empty():
		var start_key: String = pending.keys()[0]
		var room_cells: Array[Vector2i] = []
		var queue: Array[Vector2i] = [pending[start_key]]

		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			var key := _key(cell)
			if not pending.has(key):
				continue
			pending.erase(key)
			room_cells.append(cell)
			queue.append(cell + Vector2i.RIGHT)
			queue.append(cell + Vector2i.LEFT)
			queue.append(cell + Vector2i.DOWN)
			queue.append(cell + Vector2i.UP)

		if room_cells.size() < 2:
			continue  # un hueco suelto no es un edificio

		_make_room(room_cells, world)


func _make_room(cells: Array[Vector2i], world) -> void:
	var index := _rooms.size()
	var room := Node2D.new()
	add_child(room)
	_rooms.append(room)

	# El techo cubre el interior y las paredes. La puerta queda **destapada** a
	# propósito: es lo único que te dice desde afuera por dónde se entra.
	var covered := {}   ## "x,y" -> {"celda": Vector2i, "color": Color}
	for cell in cells:
		_cell_room[_key(cell)] = index
		covered[_key(cell)] = {"celda": cell, "color": roof_color}
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var neighbour: Vector2i = cell + offset
			var key := _key(neighbour)
			var ch: String = world.char_at_cell(neighbour)
			if ch == WALL:
				# Una pared no pisa un techo interior ya puesto: en las esquinas
				# los vecinos diagonales pueden ser piso de la misma habitación.
				if not covered.has(key):
					covered[key] = {"celda": neighbour, "color": roof_edge_color}
			elif ch == DOOR:
				# Pararte en la puerta ya cuenta como estar adentro: si no, el
				# techo parpadea justo al cruzarla.
				_cell_room[key] = index

	for key in covered.keys():
		var data: Dictionary = covered[key]
		var cell: Vector2i = data["celda"]
		var tint: Color = data["color"]
		room.add_child(_roof_tile(world.center_of(cell), tint))


func _roof_tile(center: Vector2, tint: Color) -> Polygon2D:
	var tile := Polygon2D.new()
	tile.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	tile.color = tint
	tile.position = center
	return tile


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


# Sin tipar: usamos bounds()/cell_at()/char_at_cell(), propios de world.gd.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")
