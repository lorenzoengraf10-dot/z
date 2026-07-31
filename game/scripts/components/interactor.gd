class_name Interactor
extends Node
## Acción contextual del jugador (tecla E). Primero mira si tenés algo al lado
## (puerta o fogata) y si no, el tile que tenés enfrente:
##   puerta → la abrís o la cerrás (cerrada frena a los zombies)
##   fogata → la prendés con el minijuego, o le echás leña si ya está prendida
##   árbol  → talás y conseguís madera (hace mucho ruido: los zombies te oyen)
##   agua   → pescás y de paso tomás agua (sacia la sed, pero sin hervir te cae mal)
##   roca / veta → picás y conseguís piedra o metal (hace falta un pico)
##
## Las acciones llevan tiempo y se cancelan si te movés.

signal action_started(label: String, duration: float)
signal action_progress(ratio: float)
signal action_ended(message: String)

const TREE := "T"
const WATER := "~"
const GRASS := "."
const ROCK := "R"
const ORE := "O"

@export var reach := 18.0
## Las fogatas y puertas se agarran desde un poco más lejos que un tile, porque
## son objetos del mundo y no cuadrados de la grilla.
@export var campfire_reach := 30.0
@export var door_reach := 26.0
@export var container_reach := 28.0
@export var chop_seconds := 1.8
@export var fish_seconds := 3.5
@export var mine_seconds := 2.6
# Misma escala que player.gd, medida sobre correr = 190 = 100%.
@export var chop_noise := 143.0    ## 75%
## Picar era 200, o sea MÁS ruidoso que correr, y se salía de la escala. Queda
## en el tope: es la acción más ruidosa que podés hacer sin un arma de fuego.
@export var mine_noise := 190.0    ## 100%
@export var wood_per_tree := 3
@export var stone_per_rock := 2
@export var metal_per_ore := 2
@export var fish_chance := 0.65
## Lo que te cuesta de salud tomar agua del lago sin hervirla.
@export var dirty_water_damage := 6.0
## Con la herramienta adecuada las acciones tardan esta fracción del tiempo.
@export var tool_speedup := 0.55

var _kind := ""
var _elapsed := 0.0
var _duration := 0.0
var _cell := Vector2i.ZERO
## Contenedor que estamos revisando (null si la accion no es esa).
var _container = null
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


## Mira qué haría la **E** ahora mismo, SIN hacer nada.
##
## La usa el cartelito flotante del HUD. Está separada de try_interact() a
## propósito y las dos llaman a este mismo código: si el cartel y la acción se
## calcularan por separado, tarde o temprano dirían cosas distintas.
##
## Devuelve {} si no hay nada, o:
##   {"tipo", "texto", "posicion", "objetivo"}
## donde "objetivo" es el nodo (puerta, fogata, contenedor) o null si es un tile.
func peek() -> Dictionary:
	# Lo que tenés al lado gana sobre el tile de enfrente: una puerta pegada al
	# cuerpo es más urgente que el pasto que estás mirando.
	var door = _nearby_door()
	if door != null:
		return {
			"tipo": "puerta",
			"texto": "Cerrar puerta" if not door.is_open else "Abrir puerta",
			"posicion": door.global_position,
			"objetivo": door,
		}

	var campfire = _nearby_campfire()
	if campfire != null:
		return {
			"tipo": "fogata",
			"texto": "Echarle leña" if campfire.is_lit() else "Prender fuego",
			"posicion": campfire.global_position,
			"objetivo": campfire,
		}

	var container = _nearby_container()
	if container != null:
		return {
			"tipo": "contenedor",
			"texto": "Ya lo revisaste" if container.looted else "Revisar %s" % container.display_name(),
			"posicion": container.global_position,
			"objetivo": container,
		}

	var world = _world()
	if world == null:
		return {}

	var target: Vector2 = _player.global_position + _player.facing * reach
	var cell: Vector2i = world.cell_at(target)
	var texto := ""
	match world.char_at_cell(cell):
		TREE:
			texto = "Talar árbol"
		WATER:
			texto = "Pescar"
		ROCK:
			texto = "Picar piedra" if _has_tool("mineria") else "Necesitás un pico"
		ORE:
			texto = "Picar veta" if _has_tool("mineria") else "Necesitás un pico"
		_:
			return {}

	return {
		"tipo": "tile",
		"texto": texto,
		"posicion": world.center_of(cell),
		"objetivo": null,
	}


## La llama el jugador cuando apretás E. Actúa sobre lo que devuelve peek().
func try_interact() -> void:
	if is_busy():
		_reset()
		action_ended.emit("Acción cancelada")
		return

	var found := peek()
	if found.is_empty():
		action_ended.emit("Nada para hacer acá")
		return

	var target = found.get("objetivo")
	match str(found.get("tipo", "")):
		"puerta":
			target.toggle()
			action_ended.emit("Puerta %s" % target.status_text())
		"fogata":
			_use_campfire(target)
		"contenedor":
			if target.looted:
				action_ended.emit("Ya revisaste eso")
			else:
				_begin_container(target)
		"tile":
			_begin_tile(found)


## Arranca la acción que corresponda al tile que estás mirando.
func _begin_tile(found: Dictionary) -> void:
	var world = _world()
	if world == null:
		return
	var position: Vector2 = found["posicion"]
	var cell: Vector2i = world.cell_at(position)
	match world.char_at_cell(cell):
		TREE:
			_begin("talar", "Talando árbol...", _timed(chop_seconds, "tala"), cell)
		WATER:
			_begin("pescar", "Pescando...", fish_seconds, cell)
		ROCK, ORE:
			_try_mine(cell)


## Empezar a picar exige un pico en la mochila.
func _try_mine(cell: Vector2i) -> void:
	if not _has_tool("mineria"):
		action_ended.emit("Necesitás un pico para picar esto")
		return
	_begin("minar", "Picando...", _timed(mine_seconds, "mineria"), cell)


## Duración de una acción, más corta si tenés la herramienta adecuada.
func _timed(seconds: float, kind: String) -> float:
	return seconds * (tool_speedup if _has_tool(kind) else 1.0)


func _has_tool(kind: String) -> bool:
	for key in _player.inventory.items.keys():
		if ItemDB.tool_kind(str(key)) == kind:
			return true
	return false


## Contenedor más cercano dentro del alcance, o null.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _nearby_container():
	var system = get_tree().get_first_node_in_group("loot_system")
	if system == null:
		return null
	return system.nearest(_player.global_position, container_reach)


## Arranca a revisar un contenedor. Guardamos cuál es para vaciarlo al terminar.
func _begin_container(container) -> void:
	_container = container
	_begin("revisar", "Revisando %s..." % container.display_name(),
			container.search_seconds, Vector2i.ZERO)
	_player.action_noise = container.search_noise


## Puerta más cercana dentro del alcance, o null.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _nearby_door():
	var system = get_tree().get_first_node_in_group("door_system")
	if system == null:
		return null
	return system.nearest(_player.global_position, door_reach)


## Fogata más cercana dentro del alcance, o null.
## Sin tipo de retorno: le pedimos is_lit()/add_fuel(), que no existen en Node2D.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _nearby_campfire():
	var best = null
	var best_dist := campfire_reach
	# El for sobre Array[Node] da elementos tipados como Node, y Node no tiene
	# global_position: lo pasamos a una variable sin tipo.
	for node in get_tree().get_nodes_in_group("campfire"):
		if not (node is Node2D):
			continue
		var fire = node
		var dist: float = _player.global_position.distance_to(fire.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = fire
	return best


func _use_campfire(campfire) -> void:
	if campfire.is_lit():
		# Ya prendida: le echamos leña para que dure más.
		if _player.inventory.remove("madera", 1):
			campfire.add_fuel(1)
			action_ended.emit("Le echaste una madera al fuego")
		else:
			action_ended.emit("Necesitás madera para alimentar el fuego")
		return

	var minigame = get_tree().get_first_node_in_group("fire_minigame")
	if minigame == null:
		action_ended.emit("No se pudo abrir el minijuego de fuego")
		return
	minigame.start(campfire, _player.inventory.has("mechero"))


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
	elif kind == "minar":
		# Picar piedra se escucha todavía más lejos que talar.
		_player.action_noise = mine_noise
	action_started.emit(label, _duration)
	action_progress.emit(0.0)


func _complete() -> void:
	var kind := _kind
	var cell := _cell
	# Nos guardamos el contenedor ANTES de _reset(), que lo limpia.
	var container = _container
	_reset()

	var message := ""
	match kind:
		"revisar":
			message = _finish_container(container)
		"talar":
			var world = _world()
			if world != null:
				world.set_char_at_cell(cell, GRASS)
			_player.inventory.add("madera", wood_per_tree)
			message = "+%d madera" % wood_per_tree
		"pescar":
			_player.needs.set_need(NeedsComponent.SED, _player.needs.max_of(NeedsComponent.SED))
			_player.needs.damage(dirty_water_damage * _player.needs.raw_damage_multiplier)
			if randf() < fish_chance:
				_player.inventory.add("pescado", 1)
				message = "+1 pescado · tomaste agua sucia (te cayó mal)"
			else:
				message = "Se escapó... y el agua sucia te cayó mal"
		"minar":
			var mine_world = _world()
			if mine_world != null:
				var drop: String = mine_world.mineable_at(cell)
				if drop == "":
					message = "Ahí ya no queda nada"
				else:
					var amount := metal_per_ore if drop == "metal" else stone_per_rock
					mine_world.set_char_at_cell(cell, GRASS)
					_player.inventory.add(drop, amount)
					message = "+%d %s" % [amount, ItemDB.display_name(drop)]

	action_ended.emit(message)


func _reset() -> void:
	_kind = ""
	_container = null
	_elapsed = 0.0
	_duration = 0.0
	_player.action_noise = 0.0


# Sin tipar: usamos cell_at/char_at_cell/set_char_at_cell, que son de world.gd
# y no existen en Node.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")


## Vacía el contenedor y mete lo que entre en la mochila. Devuelve el mensaje
## para el HUD.
func _finish_container(container) -> String:
	if container == null or not is_instance_valid(container):
		return "Se te fue de las manos"

	var loot: Dictionary = container.take_loot()
	if loot.is_empty():
		return "Estaba vacío"

	var got: Array[String] = []
	var left_behind := false
	for id in loot.keys():
		var wanted := int(loot[id])
		var taken: int = _player.inventory.add(str(id), wanted)
		if taken > 0:
			got.append("%d %s" % [taken, ItemDB.display_name(str(id))])
		if taken < wanted:
			left_behind = true

	if got.is_empty():
		return "Encontraste cosas pero no te entra nada"
	var text := "Encontraste: " + ", ".join(got)
	if left_behind:
		text += " (algo no te entró)"
	return text
