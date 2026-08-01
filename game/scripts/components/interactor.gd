class_name Interactor
extends Node
## Acción contextual del jugador (tecla E). Primero mira si tenés algo al lado
## (puerta o fogata) y si no, el tile que tenés enfrente:
##   puerta → la abrís o la cerrás (cerrada frena a los zombies)
##   fogata → la prendés con el minijuego, o le echás leña si ya está prendida
##   árbol / roca / veta → abren el minijuego de 3 clicks (ui/click_minigame.gd)
##   agua   → **E pesca (minijuego de burbujas, hace falta caña), T toma agua**
##            — son dos acciones separadas, no una sola que asume por vos
##            (ver try_drink()).
##
## Los minijuegos NO pausan el árbol: mientras están abiertos el jugador queda
## congelado (input_blocked) pero los zombies te siguen buscando igual.

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
# Misma escala que player.gd, medida sobre correr = 190 = 100%.
@export var chop_noise := 143.0    ## 75%
## Picar era 200, o sea MÁS ruidoso que correr, y se salía de la escala. Queda
## en el tope: es la acción más ruidosa que podés hacer sin un arma de fuego.
@export var mine_noise := 190.0    ## 100%
@export var wood_per_tree := 3
@export var stone_per_rock := 2
@export var metal_per_ore := 2
## Lo que te cuesta de salud tomar agua del lago sin hervirla.
@export var dirty_water_damage := 6.0
## No se puede pescar con un zombi encima: ni que te haya visto, ni que esté
## a menos de esta cantidad de celdas (world.gd usa tiles de 16 px).
@export var fish_danger_cells := 15
const _TILE_SIZE := 16.0

var _kind := ""
var _elapsed := 0.0
var _duration := 0.0
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
		# Ya revisado (o un cofre, que arranca así): en vez de decir "ya lo
		# revisaste" y no hacer nada, abre el almacenamiento — es lo que
		# convierte 93 muebles muertos del mapa en lugares donde guardar.
		var texto := ("Guardar cosas (%s)" % container.display_name()) \
				if container.looted else ("Revisar %s" % container.display_name())
		return {
			"tipo": "contenedor",
			"texto": texto,
			"posicion": container.global_position,
			"objetivo": container,
		}

	var world = _world()
	if world == null:
		return {}

	var target: Vector2 = _player.global_position + _player.facing * reach
	var cell: Vector2i = world.cell_at(target)
	var char_here := world.char_at_cell(cell)
	var texto := ""
	match char_here:
		TREE:
			texto = "Talar árbol"
		WATER:
			if not _player.inventory.has("cana_pescar"):
				texto = "Necesitás una caña de pescar"
			elif _fishing_blocked_by_zombies():
				texto = "Necesitás alejarte de los zombies para pescar"
			else:
				texto = "Pescar"
		ROCK:
			texto = "Picar piedra" if _has_tool("mineria") else "Necesitás un pico"
		ORE:
			texto = "Picar veta" if _has_tool("mineria") else "Necesitás un pico"
		_:
			return {}

	var result := {
		"tipo": "tile",
		"texto": texto,
		"posicion": world.center_of(cell),
		"objetivo": null,
	}

	# El agua tiene DOS acciones, no una: E pesca, T toma agua directo. Antes
	# la E hacía las dos juntas (pescaba Y de yapa te hidrataba), y el testeo
	# pidió que sea explícito, no una decisión tomada por el juego.
	if char_here == WATER:
		if _player.inventory.has("recipiente"):
			result["extra_texto"] = "T — Llenar el recipiente (agua sucia)"
		else:
			result["extra_texto"] = "T — Tomar agua directa (sucia, te cae mal)"

	return result


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
				_open_storage(target)
			else:
				_begin_container(target)
		"tile":
			_begin_tile(found)


## Tomar agua directo del lago (tecla **T**), separado de pescar (E). Es
## instantáneo, no cancela ni compite con ninguna acción en curso.
##
## Sin recipiente: tomás ahí mismo, agua sucia, te cae mal — igual que antes
## hacía "pescar" de yapa. Con recipiente: en vez de tomarla, la juntás
## (agua_sucia en la mochila) para hervirla después en la fogata y que salga
## segura. Ver receta "agua_hervida" en data/recipes.json.
func try_drink() -> void:
	var world = _world()
	if world == null:
		return
	var target: Vector2 = _player.global_position + _player.facing * reach
	var cell: Vector2i = world.cell_at(target)
	if world.char_at_cell(cell) != WATER:
		action_ended.emit("No hay agua ahí")
		return

	if _player.inventory.has("recipiente"):
		var added: int = _player.receive("agua_sucia", 1)
		if added > 0:
			action_ended.emit("Llenaste el recipiente con agua sucia")
		else:
			action_ended.emit("No te entra el agua sucia (mochila llena)")
		return

	# Da lo MISMO que tomarse un "agua_sucia" guardada, ni más ni menos. Antes
	# esto llenaba la sed al 100% por los mismos 6 de daño, con lo cual craftear
	# el recipiente te dejaba peor que no tenerlo: el recipiente sirve para
	# guardar el agua y hervirla, no para hidratar menos.
	_player.needs.change(NeedsComponent.SED, ItemDB.value_of("agua_sucia", "sed"))
	_player.needs.damage(dirty_water_damage * _player.needs.raw_damage_multiplier)
	action_ended.emit("Tomaste agua directo del lago (sucia, te cayó mal)")


## Arranca la acción que corresponda al tile que estás mirando.
func _begin_tile(found: Dictionary) -> void:
	var world = _world()
	if world == null:
		return
	var position: Vector2 = found["posicion"]
	var cell: Vector2i = world.cell_at(position)
	match world.char_at_cell(cell):
		TREE:
			_start_click_minigame("talar", "Talando árbol", cell, chop_noise, _has_tool("tala"))
		WATER:
			_try_fish(cell)
		ROCK, ORE:
			_try_mine(cell)


## Empezar a picar exige un pico en la mochila.
func _try_mine(cell: Vector2i) -> void:
	if not _has_tool("mineria"):
		action_ended.emit("Necesitás un pico para picar esto")
		return
	_start_click_minigame("minar", "Picando piedra", cell, mine_noise, true)


## Pescar exige caña Y que no haya zombies cerca — se revisa DE NUEVO acá
## (además de en peek(), que es lo que muestra el cartelito) por si el estado
## cambió justo entre que se mostró el cartel y apretaste E.
func _try_fish(cell: Vector2i) -> void:
	if not _player.inventory.has("cana_pescar"):
		action_ended.emit("Necesitás una caña de pescar")
		return
	if _fishing_blocked_by_zombies():
		action_ended.emit("Hay zombies cerca: no podés pescar tranquilo")
		return

	var minigame = get_tree().get_first_node_in_group("fishing_minigame")
	if minigame == null:
		action_ended.emit("No se pudo abrir el minijuego de pesca")
		return
	minigame.finished.connect(_on_fishing_finished, CONNECT_ONE_SHOT)
	minigame.start()


func _on_fishing_finished(caught: bool) -> void:
	if not caught:
		action_ended.emit("Se te escapó")
		return
	# Ojo con el valor de retorno: si la mochila está llena el pescado NO entra,
	# y antes se anunciaba igual (ver _give_from_tile() para la versión larga
	# de esta misma trampa).
	if _player.receive("pescado", 1) > 0:
		action_ended.emit("+1 pescado")
	else:
		action_ended.emit("Lo pescaste pero no te entra: mochila llena")


## True si algún zombie te vio, o si hay alguno a `fish_danger_cells` celdas
## o menos — cualquiera de las dos alcanza para que no puedas pescar tranquilo.
func _fishing_blocked_by_zombies() -> bool:
	var danger_range := fish_danger_cells * _TILE_SIZE
	for node in get_tree().get_nodes_in_group("hunter"):
		if not (node is Node2D):
			continue
		var hunter = node
		var seen := hunter.has_method("alert_level") and int(hunter.alert_level()) == 2
		if seen:
			return true
		var dist: float = _player.global_position.distance_to(hunter.global_position)
		if dist <= danger_range:
			return true
	return false


## Arranca el minijuego de 3 clicks (talar / picar piedra / picar veta).
## `easier` afloja la velocidad de la aguja si tenés la herramienta adecuada
## (antes eso acortaba el tiempo de espera; ahora hace más fácil el timing).
func _start_click_minigame(kind: String, label: String, cell: Vector2i, noise: float, easier: bool) -> void:
	var minigame = get_tree().get_first_node_in_group("click_minigame")
	if minigame == null:
		action_ended.emit("No se pudo abrir el minijuego")
		return
	_player.action_noise = noise
	minigame.finished.connect(_on_click_minigame_finished.bind(kind, cell), CONNECT_ONE_SHOT)
	minigame.start(label, easier)


## Entrega la recompensa (o no) al terminar el minijuego de 3 clicks. Es acá y
## no adentro del minijuego porque un solo click_minigame.gd sirve para tres
## recompensas distintas (madera, piedra, metal) — el minijuego no sabe nada
## de ítems, solo avisa si ganaste o no.
func _on_click_minigame_finished(success: bool, kind: String, cell: Vector2i) -> void:
	_player.action_noise = 0.0
	if not success:
		action_ended.emit("Acción cancelada")
		return

	var world = _world()
	if world == null:
		return

	match kind:
		"talar":
			_give_from_tile(cell, "madera", wood_per_tree)
		"minar":
			var drop: String = world.mineable_at(cell)
			if drop == "":
				action_ended.emit("Ahí ya no queda nada")
				return
			var amount := metal_per_ore if drop == "metal" else stone_per_rock
			_give_from_tile(cell, drop, amount)


## Entrega el botín de un tile y **recién ahí** lo borra del mapa.
##
## El orden importa muchísimo. Antes era al revés: se borraba el tile y después
## se llamaba a inventory.add() sin mirar lo que devolvía. Con la mochila llena
## el árbol (o la roca, o la veta) desaparecía **para siempre**, no recibías
## nada, y el cartel igual anunciaba "+3 madera". Es la misma queja del testeo
## que ya se había arreglado en pickup.gd y en _finish_container(), pero por
## este camino seguía viva.
##
## Se usa receive() y no inventory.add() para que la munición siga yendo al
## casillero de ArmsComponent sin gastar mochila.
func _give_from_tile(cell: Vector2i, id: String, amount: int) -> void:
	var taken: int = _player.receive(id, amount)
	if taken <= 0:
		# El tile queda intacto: volvés cuando hagas lugar.
		action_ended.emit("No te entra %s: la mochila está llena" % ItemDB.display_name(id))
		return

	var world = _world()
	if world != null:
		world.set_char_at_cell(cell, GRASS)

	if taken < amount:
		action_ended.emit("+%d %s (no entró el resto)" % [taken, ItemDB.display_name(id)])
	else:
		action_ended.emit("+%d %s" % [taken, ItemDB.display_name(id)])


func _has_tool(kind: String) -> bool:
	for key in _player.inventory.items.keys():
		if ItemDB.tool_kind(str(key)) == kind:
			return true
	return false


## Contenedor más cercano dentro del alcance, o null. Busca en el grupo
## "container" directo (mismo patrón que _nearby_campfire() acá abajo) en vez
## de pasar por loot_system: así encuentra tanto los muebles del mapa como los
## cofres que construya el jugador, que no pasan por loot_system.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _nearby_container():
	var best = null
	var best_dist := container_reach
	for node in get_tree().get_nodes_in_group("container"):
		if not (node is Node2D):
			continue
		var candidate = node
		var dist: float = _player.global_position.distance_to(candidate.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = candidate
	return best


## Arranca a revisar un contenedor. Guardamos cuál es para vaciarlo al terminar.
func _begin_container(container) -> void:
	_container = container
	_begin("revisar", "Revisando %s..." % container.display_name(), container.search_seconds)
	_player.action_noise = container.search_noise


## Un mueble ya revisado (o un cofre) no se "revisa" de nuevo: abre directo
## la pantalla de guardar/sacar. Es instantáneo, no hace falta el timer de
## _begin() como al saquear.
func _open_storage(container) -> void:
	var screen = get_tree().get_first_node_in_group("storage_screen")
	if screen == null or not screen.has_method("open_for"):
		action_ended.emit("No se pudo abrir el almacenamiento")
		return
	screen.open_for(container)


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


## Solo la usa "revisar" (saquear un contenedor) — talar/picar/pescar pasan
## por minijuegos ahora (_start_click_minigame() / _try_fish() más arriba),
## que no cancelan por moverte porque el jugador queda congelado mientras
## están abiertos.
func _begin(kind: String, label: String, duration: float) -> void:
	_kind = kind
	_duration = maxf(duration, 0.1)
	_elapsed = 0.0
	_anchor = _player.global_position
	action_started.emit(label, _duration)
	action_progress.emit(0.0)


func _complete() -> void:
	var kind := _kind
	# Nos guardamos el contenedor ANTES de _reset(), que lo limpia.
	var container = _container
	_reset()

	var message := ""
	if kind == "revisar":
		message = _finish_container(container)

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
		# receive() reparte igual que collect(): la munición del arma
		# equipada va directo al casillero libre, el resto a la mochila.
		var taken: int = _player.receive(str(id), wanted)
		if taken > 0:
			got.append("%d %s" % [taken, ItemDB.display_name(str(id))])
		# Lo que no entró NO se pierde: se queda guardado en el mismo mueble
		# (container.stored), listo para venir a buscarlo con más lugar o
		# cuando el mueble ya sirva de almacenamiento (ver ui/storage_screen.gd).
		if taken < wanted:
			container.add_leftover(str(id), wanted - taken)
			left_behind = true

	if got.is_empty():
		return "Encontraste cosas pero no te entra nada (quedó guardado ahí)"
	var text := "Encontraste: " + ", ".join(got)
	if left_behind:
		text += " (lo que no entró quedó guardado ahí)"
	return text
