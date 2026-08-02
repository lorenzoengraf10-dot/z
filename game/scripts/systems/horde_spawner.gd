extends Node2D
## Spawner de hordas. Va acumulando el "calor" del ruido que hace el jugador:
## correr, talar y pelear lo suben; ir agachado casi no. Cuando pasa el umbral
## aparece un grupo de zombies desde fuera de pantalla, en dirección al ruido.
##
## Es la traducción directa del pilar de diseño: el ruido tiene consecuencias.

const ZOMBIE_SCENE := "res://scenes/Zombie.tscn"

## Variantes que tienen su propio dibujo en vez del compartido de zombi.gd.
## Carpeta esperada: assets/sprites/<nombre>/, 3 direcciones, igual que
## cualquier otro personaje (ver docs/ARTE_SPEC.md). Mientras esa carpeta no
## tenga PNG, la variante sigue mostrando el dibujo base tintado, como hasta
## ahora: no hay que esperar a tener el arte para agregarla acá.
##
## El "fps" va acá y no en Zombie.tscn porque la escena la comparten las tres
## variantes y cada dibujo tiene su propia cantidad de cuadros.
##
## Para elegir el fps: un ciclo completo dura `cuadros / fps` segundos.
## El zombi pesado tiene 8 cuadros, así que a 12 fps el ciclo son 666 ms — el
## doble de lento que un paso normal, que es justo lo que se busca para el
## zombi lento y pesado. Si lo quieren más arrastrado, bajen el número.
const SPRITE_OVERRIDE := {
	"resistente": {"sprite": "zombi_resistente", "fps": 12.0},
}

## Variantes. El spawner sobreescribe los @export del zombie al crearlo.
const VARIANTS := {
	"normal": {
		"chase_speed": 110.0, "wander_speed": 30.0, "max_health": 45.0,
		"attack_damage": 8.0, "color": Color(0.50, 0.15, 0.15),
	},
	"corredor": {
		"chase_speed": 168.0, "wander_speed": 42.0, "max_health": 26.0,
		"attack_damage": 6.0, "color": Color(0.72, 0.32, 0.14),
	},
	# 16 y no 15 para que la tabla de resistencia de las construcciones cierre
	# redonda: un muro de piedra (240) aguanta 30 golpes del zombi normal (8) y
	# 15 de este; una puerta (160), 20 y 10. Contra el jugador la diferencia
	# entre 15 y 16 no se nota.
	"resistente": {
		"chase_speed": 76.0, "wander_speed": 22.0, "max_health": 115.0,
		"attack_damage": 16.0, "color": Color(0.34, 0.10, 0.30),
	},
}

# Cuentas para tocar estos números: correr hace 190 de ruido, así que el calor
# sube 190 * heat_per_noise por segundo. Con 0.030 y umbral 150 son 26 segundos
# de correr sin parar antes de que te caiga una horda. Antes eran 15, que con el
# mapa chico estaba bien pero en 160×100 te castigaba por el solo hecho de
# cruzarlo.
@export var enabled := true
@export var heat_per_noise := 0.030   ## cuánto sube el calor por unidad de ruido, por segundo
@export var heat_decay := 4.0         ## cuánto baja por segundo si no hacés ruido
@export var heat_threshold := 150.0
@export var horde_min := 2
@export var horde_max := 4
@export var spawn_distance := 340.0
## Subió de 14 a 18: el mapa es mucho más grande y ahora los zombies se quedan
## encerrados en los edificios en vez de atravesar las paredes.
@export var max_zombies := 18
@export var cooldown_seconds := 25.0
## Espera corta cuando el calor llegó al umbral pero no había dónde spawnear.
const RETRY_SECONDS := 3.0

signal horde_spawned(count: int)

var heat := 0.0

var _zombie: PackedScene
var _cooldown := 0.0


func _ready() -> void:
	add_to_group("horde_spawner")
	_zombie = load(ZOMBIE_SCENE) as PackedScene


func _process(delta: float) -> void:
	if not enabled:
		return
	_cooldown = maxf(0.0, _cooldown - delta)

	var player = _player()
	if player == null:
		return

	var noise := 0.0
	if player.has_method("get_noise_radius"):
		noise = player.get_noise_radius()

	if noise > 0.0:
		heat += noise * heat_per_noise * delta
	else:
		heat = maxf(0.0, heat - heat_decay * delta)

	if heat >= heat_threshold and _cooldown <= 0.0:
		# El calor se limpia SOLO si de verdad apareció alguien. _spawn_horde()
		# tiene dos salidas que no crean nada: que ya haya `max_zombies` vivos, y
		# que no encuentre una celda libre cerca (pasa contra el borde del mapa o
		# encerrado en un edificio). Antes se limpiaba igual, así que justo
		# cuando el mapa estaba lleno de zombies hacer ruido salía gratis y encima
		# te regalaba los 25 s de cooldown.
		if _spawn_horde(player) > 0:
			heat = 0.0
			_cooldown = cooldown_seconds
		else:
			# Reintento corto: el calor queda cargado esperando que se libere
			# lugar, pero no probamos una vez por frame.
			_cooldown = RETRY_SECONDS


## Devuelve cuántos zombies llegó a crear (0 = no había lugar, ver _process()).
func _spawn_horde(player) -> int:
	var alive := get_tree().get_nodes_in_group("zombie").size()
	var room := max_zombies - alive
	if room <= 0:
		return 0

	var count := mini(randi_range(horde_min, horde_max), room)
	var spawned := 0
	for i in range(count):
		var pos := _find_spawn_position(player)
		if pos == Vector2.INF:
			continue
		_spawn_one(pos, _random_variant())
		spawned += 1

	if spawned > 0:
		horde_spawned.emit(spawned)
	return spawned


func _random_variant() -> String:
	var roll := randf()
	if roll < 0.15:
		return "resistente"
	if roll < 0.45:
		return "corredor"
	return "normal"


## Busca una celda libre lejos del jugador. Devuelve Vector2.INF si no encuentra.
func _find_spawn_position(player) -> Vector2:
	var world = _world()
	for attempt in range(12):
		var angle := randf() * TAU
		var dist := spawn_distance * randf_range(0.85, 1.25)
		var candidate: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * dist
		if world == null:
			return candidate
		if not world.is_solid(candidate):
			return candidate
	return Vector2.INF


func spawn_at(position_global: Vector2, variant: String = "normal") -> void:
	_spawn_one(position_global, variant)


func _spawn_one(position_global: Vector2, variant: String) -> void:
	if _zombie == null:
		return
	var stats: Dictionary = VARIANTS.get(variant, VARIANTS["normal"])
	# Sin ":=" : instantiate() devuelve Node y acá le seteamos las stats propias.
	var z = _zombie.instantiate()
	z.zombie_type = variant

	# Si esta variante tiene su propio dibujo (SPRITE_OVERRIDE), hay que
	# pedírselo al SpriteDirectional ANTES de add_child(): _ready() carga los
	# PNG apenas el nodo entra al árbol, así que después ya es tarde.
	var override: Dictionary = SPRITE_OVERRIDE.get(variant, {})
	var art: SpriteDirectional = null
	if not override.is_empty():
		art = z.get_node_or_null("SpriteDirectional") as SpriteDirectional
		if art != null:
			art.sprite_name = str(override["sprite"])
			art.sprite_name_fallback = "zombi"
			art.fps = float(override["fps"])

	z.chase_speed = float(stats["chase_speed"])
	z.wander_speed = float(stats["wander_speed"])
	z.max_health = float(stats["max_health"])
	z.attack_damage = float(stats["attack_damage"])
	add_child(z)
	z.global_position = position_global

	# Recién acá se sabe si el PNG propio existía de verdad o si tuvo que caer
	# al de respaldo (art.active_sprite_name() se llena en _ready(), que ya
	# corrió). Si es el propio, que no lo tiña: ya se distingue solo.
	if art != null:
		# Ojo: contra override["sprite"] (un String), NO contra `override`, que
		# es el diccionario entero {"sprite":..., "fps":...}. Comparar un String
		# con un Dictionary da siempre false y no rompe nada: el zombi seguía
		# saliendo tintado por encima de su propio dibujo, justo lo que el
		# comentario de acá arriba dice que hay que evitar.
		z.uses_dedicated_art = art.active_sprite_name() == str(override["sprite"])

	# Color distinto por variante, para distinguirlas mientras el arte es
	# placeholder o compartido. Se lo pedimos al zombi en vez de meterle mano a
	# sus nodos: así el día que Visual cambie de forma, esto no se rompe.
	var tint: Color = stats["color"]
	z.set_tint(tint)


# Sin tipar: usamos player.get_noise_radius(), que no existe en Node2D.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _player():
	return get_tree().get_first_node_in_group("player")


# Sin tipar: usamos is_solid(), propio de world.gd.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _world():
	return get_tree().get_first_node_in_group("world")
