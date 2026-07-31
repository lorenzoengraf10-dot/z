extends Node
## Maneja la **partida** (run) al estilo Mini DAYZ.
##
## Cada partida arranca en un punto **al azar** del mapa y termina cuando morís:
## ahí se pierde todo lo que juntaste. Lo que **no** se pierde son las
## estadísticas acumuladas y los **perks** que vas desbloqueando, que quedan
## guardados en `user://perfil.json` y valen para todas las partidas siguientes.
##
## Esa es la gracia: cada muerte duele, pero el personaje siguiente arranca un
## poquito mejor.

signal run_ended(stats: Dictionary)
signal perk_unlocked(perk: Dictionary)

const PROFILE_PATH := "user://perfil.json"
const PERKS_PATH := "res://data/perks.json"

## Estadísticas de la partida en curso.
var stats := {
	"dias": 0,
	"zombies": 0,
	"lobos": 0,
	"contenedores": 0,
}
## Totales de todas las partidas + perks desbloqueados.
var profile := {
	"partidas": 0,
	"mejor_dias": 0,
	"total_zombies": 0,
	"total_contenedores": 0,
	"perks": [],
}

var perks: Array = []
var _ended := false
var _last_hour := 0.0


func _ready() -> void:
	add_to_group("run_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	perks = _load_perks()
	profile = _load_profile()
	_start_run.call_deferred()


# --- Arranque de partida ---

func _start_run() -> void:
	_ended = false
	stats = {"dias": 0, "zombies": 0, "lobos": 0, "contenedores": 0}

	var player = _player()
	if player == null:
		return

	player.needs.died.connect(_on_player_died)
	_place_player_randomly(player)
	_apply_perks(player)

	var day_night = get_tree().get_first_node_in_group("day_night")
	if day_night != null:
		_last_hour = day_night.hour
		day_night.hour_changed.connect(_on_hour_changed)


## Elige una celda caminable al aire libre y pone ahí al jugador.
func _place_player_randomly(player) -> void:
	var world = _world()
	if world == null:
		return

	var bounds: Rect2i = world.bounds()
	# Nos alejamos del borde para no aparecer pegado a los árboles del límite.
	var margin := 4
	for attempt in range(300):
		var cell := Vector2i(
			randi_range(bounds.position.x + margin, bounds.end.x - margin - 1),
			randi_range(bounds.position.y + margin, bounds.end.y - margin - 1)
		)
		if not _is_good_spawn(world, cell):
			continue
		player.global_position = world.center_of(cell)
		return
	# Si no encontró nada (mapa raro), lo dejamos donde estaba.


## Un buen spawn es pasto o camino, al aire libre y sin nada sólido alrededor.
func _is_good_spawn(world, cell: Vector2i) -> bool:
	var ch: String = world.char_at_cell(cell)
	if ch != "." and ch != "=":
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if world.is_solid_cell(cell + Vector2i(dx, dy)):
				return false
	return true


# --- Perks ---

func has_perk(perk_id: String) -> bool:
	return perk_id in profile.get("perks", [])


## Aplica al jugador los perks ya desbloqueados.
func _apply_perks(player) -> void:
	if has_perk("sangre_fria"):
		player.needs.bleed_rate_multiplier = 0.6
	if has_perk("espalda_ancha"):
		player.inventory.bonus_capacity = 3
	if has_perk("liviano"):
		player.noise_multiplier = 0.75
	if has_perk("estomago"):
		player.needs.raw_damage_multiplier = 0.5
	if has_perk("veterano"):
		player.inventory.add("cuchillo", 1)
		player.inventory.add("vendaje", 2)
	# "explorador" no toca al jugador: lo lee map_screen.gd para destapar los
	# edificios del mapa desde el arranque.


# --- Eventos de la partida ---

func _on_hour_changed(hour: float) -> void:
	# Cada vez que el reloj da la vuelta pasó un día.
	if hour < _last_hour:
		stats["dias"] = int(stats["dias"]) + 1
	_last_hour = hour


func count_kill(kind: String) -> void:
	if kind == "wolf":
		stats["lobos"] = int(stats["lobos"]) + 1
	else:
		stats["zombies"] = int(stats["zombies"]) + 1


func count_container() -> void:
	stats["contenedores"] = int(stats["contenedores"]) + 1


func _on_player_died() -> void:
	if _ended:
		return
	_ended = true

	profile["partidas"] = int(profile.get("partidas", 0)) + 1
	profile["mejor_dias"] = maxi(int(profile.get("mejor_dias", 0)), int(stats["dias"]))
	profile["total_zombies"] = int(profile.get("total_zombies", 0)) + int(stats["zombies"])
	profile["total_contenedores"] = int(profile.get("total_contenedores", 0)) + int(stats["contenedores"])

	var unlocked := _check_unlocks()
	_save_profile()

	var summary := stats.duplicate()
	summary["nuevos_perks"] = unlocked
	summary["mejor_dias"] = profile["mejor_dias"]
	summary["partidas"] = profile["partidas"]
	run_ended.emit(summary)


## Devuelve la lista de perks que se desbloquearon recién.
func _check_unlocks() -> Array:
	var unlocked: Array = []
	var owned: Array = profile.get("perks", [])
	for perk in perks:
		var id := str(perk.get("id", ""))
		if id == "" or id in owned:
			continue
		var req: Dictionary = perk.get("requisito", {})
		var value := int(req.get("valor", 0))
		var reached := false
		match str(req.get("tipo", "")):
			"dias":
				reached = int(profile["mejor_dias"]) >= value
			"zombies":
				reached = int(profile["total_zombies"]) >= value
			"contenedores":
				reached = int(profile["total_contenedores"]) >= value
		if reached:
			owned.append(id)
			unlocked.append(perk)
			perk_unlocked.emit(perk)
	profile["perks"] = owned
	return unlocked


## Empieza una partida nueva desde cero (la llama la pantalla de resumen).
##
## Recargar la escena borra este mismo nodo y crea uno nuevo, que en su _ready()
## vuelve a leer el perfil (ya guardado) y arranca la partida siguiente. Por eso
## acá NO hace falta llamar a _start_run(): lo haría sobre un nodo muerto.
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- Persistencia del perfil (aparte del guardado de la partida) ---

func _load_perks() -> Array:
	if not FileAccess.file_exists(PERKS_PATH):
		return []
	var file := FileAccess.open(PERKS_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _load_profile() -> Dictionary:
	var base := {
		"partidas": 0, "mejor_dias": 0, "total_zombies": 0,
		"total_contenedores": 0, "perks": [],
	}
	if not FileAccess.file_exists(PROFILE_PATH):
		return base
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return base
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("run_manager: perfil.json corrupto, se ignora")
		return base
	# Completamos las claves que falten, por si el perfil es de una versión vieja.
	for key in base.keys():
		if not parsed.has(key):
			parsed[key] = base[key]
	return parsed


func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("run_manager: no se pudo guardar el perfil")
		return
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()


# Ojo: quien las llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")


func _world():
	return get_tree().get_first_node_in_group("world")
