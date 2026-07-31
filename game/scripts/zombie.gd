extends CharacterBody2D
## Zombie con IA básica: deambula, detecta al jugador por visión (cono al frente,
## con línea de vista) o por oído (si estás dentro de tu radio de ruido), lo
## persigue hasta su última posición conocida, y ataca cuerpo a cuerpo.
##
## Las estadísticas están todas como @export para poder tener variantes sin
## duplicar código: el spawner de hordas (horde_spawner.gd) crea zombies
## normales, corredores (rápidos y débiles) y resistentes (lentos y duros).

enum State { WANDER, CHASE, ATTACK }

@export var zombie_type := "normal"
@export var wander_speed := 30.0
@export var chase_speed := 110.0
@export var vision_range := 220.0
@export var vision_half_angle_deg := 45.0
@export var attack_range := 20.0
@export var attack_damage := 8.0
@export var attack_cooldown := 1.0
@export var infection_per_bite := 7.0
@export var bleed_chance := 0.45
@export var bleed_per_bite := 18.0
@export var max_health := 45.0
## Segundos sin detectar al jugador antes de dejar de perseguir.
@export var lose_interest_time := 4.0

var state: State = State.WANDER
var facing := Vector2.DOWN
var last_known_position := Vector2.ZERO
var health := 0.0

var _wander_target := Vector2.ZERO
var _wander_timer := 0.0
var _time_since_seen := 999.0
var _attack_timer := 0.0

@onready var _vision_ray: RayCast2D = $VisionRay


func _ready() -> void:
	add_to_group("zombie")
	add_to_group("damageable")
	health = max_health
	_pick_wander_target()


func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_time_since_seen += delta

	var player = _detect_player()
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
			_do_attack(player)


## Devuelve el jugador si lo detecta por visión o por oído, si no null.
## Sin tipo de retorno a propósito: le pedimos métodos (get_noise_radius,
## apply_damage) que no existen en Node2D y GDScript valida tipos al compilar.
# Ojo: quien la llame debe usar `var x = ...`, NUNCA `:=` (no se puede inferir).
func _detect_player():
	# get_nodes_in_group() devuelve Array[Node], así que el elemento del for
	# queda tipado como Node. Lo pasamos a una variable sin tipo para poder
	# pedirle global_position y get_noise_radius(), que no existen en Node.
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node2D):
			continue
		var p = node
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
	# La máscara del ray solo incluye paredes/estructuras: si choca, algo tapa.
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


func _do_chase(_delta: float, player) -> void:
	if _time_since_seen >= lose_interest_time:
		state = State.WANDER
		_pick_wander_target()
		return
	if player != null and player.global_position.distance_to(global_position) <= attack_range:
		state = State.ATTACK
		return
	var to_target := last_known_position - global_position
	if to_target.length() > 2.0:
		var dir := to_target.normalized()
		facing = dir
		velocity = dir * chase_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _do_attack(player) -> void:
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
		if player.has_method("apply_infection"):
			player.apply_infection(infection_per_bite)
		# La mordida abre una herida a veces: sangrar es lo que más rápido mata.
		if randf() < bleed_chance and player.has_method("apply_bleed"):
			player.apply_bleed(bleed_per_bite)


## La llama el ataque del jugador.
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		# Le avisamos al run_manager para el resumen de la partida.
		var run = get_tree().get_first_node_in_group("run_manager")
		if run != null:
			run.count_kill("zombie")
		queue_free()
		return
	# Que le peguen lo alerta aunque no te hubiera visto.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		last_known_position = (players[0] as Node2D).global_position
		_time_since_seen = 0.0
		state = State.CHASE
