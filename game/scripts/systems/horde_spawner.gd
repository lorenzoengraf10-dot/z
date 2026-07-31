extends Node2D
## Spawner de hordas. Va acumulando el "calor" del ruido que hace el jugador:
## correr, talar y pelear lo suben; ir agachado casi no. Cuando pasa el umbral
## aparece un grupo de zombies desde fuera de pantalla, en dirección al ruido.
##
## Es la traducción directa del pilar de diseño: el ruido tiene consecuencias.

const ZOMBIE_SCENE := "res://scenes/Zombie.tscn"

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
	"resistente": {
		"chase_speed": 76.0, "wander_speed": 22.0, "max_health": 115.0,
		"attack_damage": 15.0, "color": Color(0.34, 0.10, 0.30),
	},
}

@export var enabled := true
@export var heat_per_noise := 0.035   ## cuánto sube el calor por unidad de ruido, por segundo
@export var heat_decay := 4.0         ## cuánto baja por segundo si no hacés ruido
@export var heat_threshold := 100.0
@export var horde_min := 2
@export var horde_max := 4
@export var spawn_distance := 340.0
@export var max_zombies := 14
@export var cooldown_seconds := 25.0

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
		heat = 0.0
		_cooldown = cooldown_seconds
		_spawn_horde(player)


func _spawn_horde(player) -> void:
	var alive := get_tree().get_nodes_in_group("zombie").size()
	var room := max_zombies - alive
	if room <= 0:
		return

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
	z.chase_speed = float(stats["chase_speed"])
	z.wander_speed = float(stats["wander_speed"])
	z.max_health = float(stats["max_health"])
	z.attack_damage = float(stats["attack_damage"])
	add_child(z)
	z.global_position = position_global

	# Color distinto por variante, para distinguirlas mientras el arte es
	# placeholder. Se lo pedimos al zombi en vez de meterle mano a sus nodos:
	# así el día que Visual cambie de forma, esto no se rompe.
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
