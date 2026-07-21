extends CharacterBody2D
## Zombie con IA básica: deambula, detecta al jugador por visión (cono al frente,
## con línea de vista) o por oído (si estás dentro de tu radio de ruido), lo
## persigue hasta su última posición conocida, y ataca cuerpo a cuerpo.

enum State { WANDER, CHASE, ATTACK }

@export var wander_speed := 30.0
@export var chase_speed := 110.0
@export var vision_range := 220.0
@export var vision_half_angle_deg := 45.0
@export var attack_range := 20.0
@export var attack_damage := 8.0
@export var attack_cooldown := 1.0
## Segundos sin detectar al jugador antes de dejar de perseguir.
@export var lose_interest_time := 4.0

var state: State = State.WANDER
var facing := Vector2.DOWN
var last_known_position := Vector2.ZERO

var _wander_target := Vector2.ZERO
var _wander_timer := 0.0
var _time_since_seen := 999.0
var _attack_timer := 0.0

@onready var _vision_ray: RayCast2D = $VisionRay


func _ready() -> void:
	add_to_group("zombie")
	_pick_wander_target()


func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_time_since_seen += delta

	var player := _detect_player()
	if player != null:
		last_known_position = player.global_position
		_time_since_seen = 0.0

	match state:
		State.WANDER:
			_do_wander(delta)
			if player != null:
				state = State.CHASE
		State.CHASE:
			_do_chase(delta, player)
		State.ATTACK:
			_do_attack(delta, player)


## Devuelve el jugador si lo detecta por visión o por oído, si no null.
func _detect_player() -> Node2D:
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		var to_player: Vector2 = p.global_position - global_position
		var dist := to_player.length()

		# Oído: entra dentro del radio de ruido del jugador (ignora paredes).
		var noise := 0.0
		if p.has_method("get_noise_radius"):
			noise = p.get_noise_radius()
		if noise > 0.0 and dist <= noise:
			return p

		# Visión: dentro del rango, dentro del cono al frente y con línea de vista.
		if dist <= vision_range:
			var angle := absf(rad_to_deg(facing.angle_to(to_player)))
			if angle <= vision_half_angle_deg and _has_line_of_sight(p):
				return p
	return null


func _has_line_of_sight(target: Node2D) -> bool:
	_vision_ray.target_position = _vision_ray.to_local(target.global_position)
	_vision_ray.force_raycast_update()
	# La máscara del ray solo incluye paredes: si choca, hay algo tapando.
	return not _vision_ray.is_colliding()


func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 8.0:
		_pick_wander_target()
	var dir := _wander_target - global_position
	if dir.length() > 4.0:
		dir = dir.normalized()
		facing = dir
		velocity = dir * wander_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(40.0, 140.0)
	_wander_target = global_position + Vector2.RIGHT.rotated(angle) * radius
	_wander_timer = randf_range(2.0, 4.0)


func _do_chase(delta: float, player: Node2D) -> void:
	if _time_since_seen >= lose_interest_time:
		state = State.WANDER
		_pick_wander_target()
		return
	var to_target := last_known_position - global_position
	var dist := to_target.length()
	if player != null and player.global_position.distance_to(global_position) <= attack_range:
		state = State.ATTACK
		return
	if dist > 2.0:
		var dir := to_target.normalized()
		facing = dir
		velocity = dir * chase_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _do_attack(_delta: float, player: Node2D) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	if player == null:
		state = State.CHASE
		return
	var dist := global_position.distance_to(player.global_position)
	if dist > attack_range * 1.4:
		state = State.CHASE
		return
	facing = (player.global_position - global_position).normalized()
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		if player.has_method("apply_damage"):
			player.apply_damage(attack_damage)
