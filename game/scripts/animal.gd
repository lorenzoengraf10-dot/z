extends CharacterBody2D
## Animal salvaje (presa). Pasta tranquilo hasta que te escucha o te ve cerca:
## ahí sale corriendo en dirección contraria. Cazarlo deja carne en el piso.
##
## La idea de diseño es que el sigilo también sirva para cazar: si vas corriendo
## hacés ruido y los animales se escapan antes de que llegues.

enum State { GRAZE, FLEE }

@export var graze_speed := 22.0
@export var flee_speed := 135.0
@export var sight_range := 70.0
@export var max_health := 20.0
@export var meat_drop := 2
@export var flee_seconds := 2.5

var state: State = State.GRAZE
var health := 0.0

@onready var _art: SpriteDirectional = $SpriteDirectional

var _target := Vector2.ZERO
var _timer := 0.0
var _flee_dir := Vector2.RIGHT
var _flee_left := 0.0
var _world_cache = null


func _ready() -> void:
	add_to_group("animal")
	add_to_group("damageable")
	health = max_health
	_pick_target()


func _physics_process(delta: float) -> void:
	# El animal no tenía dirección propia: la sacamos de para dónde se mueve.
	if velocity.length() > 4.0:
		_art.set_facing(velocity)

	match state:
		State.GRAZE:
			_graze(delta)
			if _senses_player():
				_start_flee()
		State.FLEE:
			_flee(delta)


func _senses_player() -> bool:
	# El for sobre Array[Node] da elementos tipados como Node: los pasamos a una
	# variable sin tipo para poder pedirles cosas del jugador.
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node2D):
			continue
		var p = node
		var dist: float = global_position.distance_to(p.global_position)
		var noise := 0.0
		if p.has_method("get_noise_radius"):
			noise = p.get_noise_radius()
		if (noise > 0.0 and dist <= noise) or dist <= sight_range:
			_flee_dir = (global_position - p.global_position).normalized()
			return true
	return false


func _start_flee() -> void:
	state = State.FLEE
	_flee_left = flee_seconds
	if _flee_dir == Vector2.ZERO:
		_flee_dir = Vector2.RIGHT


func _graze(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 or global_position.distance_to(_target) < 6.0:
		_pick_target()
	var dir := _target - global_position
	velocity = dir.normalized() * graze_speed if dir.length() > 4.0 else Vector2.ZERO
	velocity *= _terrain_speed()
	move_and_slide()


## Cuánto lo frena el suelo que está pisando (1.0 normal, menos en agua/monte).
##
## Los animales también, no solo los enemigos: si un conejo cruzara el lago a
## toda velocidad mientras vos nadás a menos de la mitad, cazar se volvería
## imposible de un modo que no se entiende mirando la pantalla.
## Mismo patrón de caché que player.gd::terrain_speed_multiplier().
# Sin tipar el caché: usamos speed_at(), que es propio de world.gd.
func _terrain_speed() -> float:
	if _world_cache == null or not is_instance_valid(_world_cache):
		_world_cache = get_tree().get_first_node_in_group("world")
	if _world_cache == null:
		return 1.0
	return _world_cache.speed_at(global_position)


func _pick_target() -> void:
	var angle := randf() * TAU
	_target = global_position + Vector2.RIGHT.rotated(angle) * randf_range(20.0, 90.0)
	_timer = randf_range(1.5, 3.5)


func _flee(delta: float) -> void:
	_flee_left -= delta
	velocity = _flee_dir * flee_speed * _terrain_speed()
	move_and_slide()
	# Si choca contra algo, prueba otra dirección en vez de quedarse trabado.
	if get_slide_collision_count() > 0:
		_flee_dir = _flee_dir.rotated(randf_range(-1.2, 1.2)).normalized()
	if _flee_left <= 0.0:
		state = State.GRAZE
		_pick_target()


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_die()
	else:
		_start_flee()


func _die() -> void:
	_drop_meat()
	queue_free()


func _drop_meat() -> void:
	var scene := load("res://scenes/Pickup.tscn") as PackedScene
	if scene == null:
		return
	# Sin ":=" : instantiate() devuelve Node y le seteamos item/amount/position.
	var drop = scene.instantiate()
	drop.item = "carne"
	drop.amount = meat_drop

	# Lo colgamos del padre (no de este nodo, que se está por borrar). Dejamos la
	# posición ya resuelta en el espacio del padre, así no hace falta tocar el
	# drop después de agregarlo — este animal para entonces ya no existe.
	# Sin tipar: get_parent() devuelve Node y le pedimos to_local(), que es de Node2D.
	var host = get_parent()
	if host == null:
		return
	drop.position = host.to_local(global_position) if host is Node2D else global_position
	host.add_child.call_deferred(drop)
