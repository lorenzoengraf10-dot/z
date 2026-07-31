extends CharacterBody2D
## Lobo. A diferencia de los zombies, es **rápido** y **caza en manada**: cuando
## uno te encuentra, avisa a los que tenga cerca y te vienen todos juntos.
##
## Muerde fuerte y te hace **sangrar**, que es lo que más rápido te mata. La
## defensa es la misma que contra los zombies: no hacer ruido, o pelear con algo
## que llegue lejos.
##
## También cazan a los animales de presa, así el bosque no es solo decorado.

enum State { ROAM, CHASE, ATTACK }

@export var roam_speed := 42.0
@export var chase_speed := 150.0     ## más rápido que vos corriendo
@export var vision_range := 190.0
@export var vision_half_angle_deg := 70.0   ## ven mejor que los zombies
@export var attack_range := 20.0
@export var attack_damage := 14.0
@export var attack_cooldown := 1.1
@export var bleed_chance := 0.7      ## muerden feo: casi siempre te abren
@export var bleed_per_bite := 22.0
@export var max_health := 40.0
@export var lose_interest_time := 6.0
## Radio en el que le avisa al resto de la manada.
@export var pack_call_radius := 260.0

var state: State = State.ROAM
var facing := Vector2.RIGHT
var last_known_position := Vector2.ZERO
var health := 0.0

## Cuánto dura la barra de vida en pantalla después de que le pegues.
@export var health_bar_seconds := 3.0
## Fuerza del retroceso cuando lo golpean.
@export var knockback_force := 90.0

var _hit_flash := 0.0
var _health_bar_timer := 0.0
var _knockback := Vector2.ZERO

var _roam_target := Vector2.ZERO
var _roam_timer := 0.0
var _time_since_seen := 999.0
var _attack_timer := 0.0

@onready var _visual: Node2D = $Visual
@onready var _art: SpriteDirectional = $SpriteDirectional


func _ready() -> void:
	add_to_group("wolf")
	add_to_group("damageable")
	add_to_group("hunter")
	health = max_health
	_pick_roam_target()


func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_time_since_seen += delta
	_update_feedback(delta)

	var prey = _detect_player()
	if prey != null:
		last_known_position = prey.global_position
		if _time_since_seen > 1.0:
			_call_pack()          # recién lo encuentra: avisa a la manada
		_time_since_seen = 0.0

	match state:
		State.ROAM:
			_do_roam(delta)
			if prey != null:
				state = State.CHASE
		State.CHASE:
			_do_chase(prey)
		State.ATTACK:
			_do_attack(prey)


func _detect_player():
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node2D):
			continue
		var p = node
		var to_player: Vector2 = p.global_position - global_position
		var dist := to_player.length()

		var noise := 0.0
		if p.has_method("get_noise_radius"):
			noise = p.get_noise_radius()
		# Oyen mejor que los zombies: les alcanza con la mitad de tu ruido.
		if noise > 0.0 and dist <= noise * 1.4:
			return p
		if dist <= vision_range:
			var angle := absf(rad_to_deg(facing.angle_to(to_player)))
			if angle <= vision_half_angle_deg:
				return p
	return null


## Le avisa a los lobos cercanos dónde estás: por eso vienen en manada.
func _call_pack() -> void:
	for node in get_tree().get_nodes_in_group("wolf"):
		if node == self or not (node is Node2D):
			continue
		var other = node
		if other.global_position.distance_to(global_position) <= pack_call_radius:
			other.alert(last_known_position)


## La llama otro lobo de la manada.
func alert(position_global: Vector2) -> void:
	last_known_position = position_global
	_time_since_seen = 0.0
	if state == State.ROAM:
		state = State.CHASE


func _do_roam(delta: float) -> void:
	_roam_timer -= delta
	if _roam_timer <= 0.0 or global_position.distance_to(_roam_target) < 10.0:
		_pick_roam_target()
	var dir := _roam_target - global_position
	if dir.length() > 4.0:
		dir = dir.normalized()
		facing = dir
		velocity = dir * roam_speed
	else:
		velocity = Vector2.ZERO
	_move_with_knockback()


func _pick_roam_target() -> void:
	var angle := randf() * TAU
	_roam_target = global_position + Vector2.RIGHT.rotated(angle) * randf_range(60.0, 200.0)
	_roam_timer = randf_range(2.0, 4.5)


func _do_chase(prey) -> void:
	if _time_since_seen >= lose_interest_time:
		state = State.ROAM
		_pick_roam_target()
		return
	if prey != null and prey.global_position.distance_to(global_position) <= attack_range:
		state = State.ATTACK
		return
	var to_target := last_known_position - global_position
	if to_target.length() > 2.0:
		var dir := to_target.normalized()
		facing = dir
		velocity = dir * chase_speed
	else:
		velocity = Vector2.ZERO
	_move_with_knockback()


func _do_attack(prey) -> void:
	velocity = Vector2.ZERO
	_move_with_knockback()
	if prey == null:
		state = State.CHASE
		return
	var dist := global_position.distance_to(prey.global_position)
	if dist > attack_range * 1.4:
		state = State.CHASE
		return
	facing = (prey.global_position - global_position).normalized()
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		AudioManager.play("lobo")
		if prey.has_method("apply_damage"):
			prey.apply_damage(attack_damage)
		if randf() < bleed_chance and prey.has_method("apply_bleed"):
			prey.apply_bleed(bleed_per_bite)


func take_damage(amount: float) -> void:
	health -= amount
	_hit_flash = 1.0
	_health_bar_timer = health_bar_seconds

	var textos = get_tree().get_first_node_in_group("floating_text")
	if textos != null:
		textos.damage(global_position, amount, false)

	if health <= 0.0:
		var run = get_tree().get_first_node_in_group("run_manager")
		if run != null:
			run.count_kill("wolf")
		queue_free()
		return
	# Que le peguen lo enfurece y alerta a la manada.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		last_known_position = (players[0] as Node2D).global_position
		_time_since_seen = 0.0
		state = State.CHASE
		_call_pack()


# --- Lo que le pide hunter_display.gd (y el HUD, y el minimapa) ---
#
# Estos tres métodos son el contrato de "enemigo que te caza". Un enemigo nuevo
# que los implemente y se meta en el grupo "hunter" ya aparece con barra de
# vida, ícono de alerta y punto en el minimapa, sin tocar nada más.

## 0 = tranquilo · 1 = te escuchó y va para allá · 2 = te está viendo.
func alert_level() -> int:
	if state == State.ROAM:
		return 0
	return 2 if _time_since_seen < 0.6 else 1


func health_ratio() -> float:
	return 0.0 if max_health <= 0.0 else health / max_health


func show_health_bar() -> bool:
	return _health_bar_timer > 0.0


## Empujón corto al recibir un golpe: es lo que hace que pegar se sienta.
func knockback(direction: Vector2) -> void:
	_knockback = direction.normalized() * knockback_force


## Apaga el parpadeo blanco y el retroceso. La llama _physics_process().
func _update_feedback(delta: float) -> void:
	_health_bar_timer = maxf(0.0, _health_bar_timer - delta)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
		var target := _art.flash_target()
		target.modulate = Color.WHITE.lerp(Color(3.0, 3.0, 3.0), _hit_flash)
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_force * 4.0 * delta)

	# Con pixel art se elige el cuadro (arriba/abajo/lado); sin arte, se rota la
	# silueta. Un sprite de pixel art NO se rota: se ve borroso y tiembla.
	if _art.has_art():
		_art.set_facing(facing)
	else:
		_visual.rotation = facing.angle()


## move_and_slide() sumándole el empujón del último golpe recibido.
func _move_with_knockback() -> void:
	velocity += _knockback
	move_and_slide()
