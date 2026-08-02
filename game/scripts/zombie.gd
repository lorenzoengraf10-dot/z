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
## Sin infección, la mordida del zombie pesa por lo que sangra: se subieron
## los dos números para que morder siga teniendo consecuencia a largo plazo.
@export var bleed_chance := 0.6
@export var bleed_per_bite := 22.0
@export var max_health := 45.0
## Segundos sin detectar al jugador antes de dejar de perseguir.
@export var lose_interest_time := 4.0

var state: State = State.WANDER
var facing := Vector2.DOWN
var last_known_position := Vector2.ZERO
var health := 0.0

## True si esta variante ya tiene su propio dibujo puesto (lo decide
## horde_spawner.gd al spawnear, mirando SPRITE_OVERRIDE). Si es true,
## set_tint() no la tiñe: ya se distingue sola y tintarla la ensuciaría.
var uses_dedicated_art := false

## Cuánto dura la barra de vida en pantalla después de que le pegues.
@export var health_bar_seconds := 3.0
## Fuerza del retroceso cuando lo golpean.
@export var knockback_force := 90.0

var _hit_flash := 0.0
var _health_bar_timer := 0.0
var _knockback := Vector2.ZERO

var _wander_target := Vector2.ZERO
var _wander_timer := 0.0
var _time_since_seen := 999.0
var _attack_timer := 0.0
var _world_cache = null

@onready var _vision_ray: RayCast2D = $VisionRay
@onready var _visual: Node2D = $Visual
@onready var _art: SpriteDirectional = $SpriteDirectional


func _ready() -> void:
	add_to_group("zombie")
	add_to_group("damageable")
	add_to_group("hunter")
	health = max_health
	_pick_wander_target()


func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_time_since_seen += delta
	_update_feedback(delta)

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
	_move_with_knockback()


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
	_move_with_knockback()
	_attack_blocking_structure()


## Si quedó trabado contra un muro, una barricada o una puerta yendo hacia vos,
## le pega en vez de quedarse empujando para siempre.
##
## Va solo en CHASE **a propósito**: si también pegara mientras deambula, los
## zombies irían demoliendo el mapa de fondo sin que nadie los provoque. Solo
## rompe lo que se interpone entre él y vos.
##
## Los lobos NO hacen esto: son animales, no tiene sentido que tiren paredes
## abajo, y además les abriría cualquier refugio.
func _attack_blocking_structure() -> void:
	if _attack_timer > 0.0:
		return
	for i in range(get_slide_collision_count()):
		# get_collider() devuelve Object: sin tipar para poder pedirle
		# take_damage(), que no existe en Object.
		var hit = get_slide_collision(i).get_collider()
		if hit == null or not (hit is Node):
			continue
		var node := hit as Node
		if not node.is_in_group("structure") or not node.has_method("take_damage"):
			continue
		_attack_timer = attack_cooldown
		node.take_damage(attack_damage)
		return


func _do_attack(player) -> void:
	velocity = Vector2.ZERO
	_move_with_knockback()
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
		# La mordida abre una herida a veces: sangrar es lo que más rápido mata.
		if randf() < bleed_chance and player.has_method("apply_bleed"):
			player.apply_bleed(bleed_per_bite)


## La llama el ataque del jugador.
func take_damage(amount: float) -> void:
	health -= amount
	_hit_flash = 1.0
	_health_bar_timer = health_bar_seconds

	var textos = get_tree().get_first_node_in_group("floating_text")
	if textos != null:
		textos.damage(global_position, amount, false)

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


# --- Lo que le pide hunter_display.gd (y el HUD, y el minimapa) ---
#
# Estos tres métodos son el contrato de "enemigo que te caza". Un enemigo nuevo
# que los implemente y se meta en el grupo "hunter" ya aparece con barra de
# vida, ícono de alerta y punto en el minimapa, sin tocar nada más.

## Pinta al zombi según la variante. La llama horde_spawner.gd al crearlo.
##
## Con pixel art no se repinta el sprite (quedaría un manchón): se le da un tinte
## suave, lo justo para distinguir al corredor del resistente sin arruinar el
## dibujo. El zombi normal queda con sus colores tal cual.
func set_tint(color: Color) -> void:
	if _art.has_art():
		if zombie_type != "normal" and not uses_dedicated_art:
			_art.modulate = Color.WHITE.lerp(color, 0.35)
		return

	var body := _visual.get_node_or_null("Body") as Polygon2D
	if body != null:
		body.color = color
	for part in ["ArmL", "ArmR"]:
		var limb := _visual.get_node_or_null(part) as Polygon2D
		if limb != null:
			limb.color = color.darkened(0.25)


## 0 = tranquilo · 1 = te escuchó y va para allá · 2 = te está viendo.
func alert_level() -> int:
	if state == State.WANDER:
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


## move_and_slide() sumándole el empujón del último golpe recibido, y frenando
## por el terreno igual que al jugador.
##
## Lo del terreno importa desde que el árbol dejó de ser sólido. Si solo el
## jugador se frenara en el monte (0.55) y el zombie siguiera a full, meterse
## entre los árboles escapando pasaría de escondite a suicidio. Lo mismo vale
## para el agua (0.45), que arrastraba esta asimetría desde antes: hasta ahora
## nadar para escapar no servía de nada.
##
## El empujón del golpe NO se frena: es un impulso, no una caminata.
func _move_with_knockback() -> void:
	velocity = velocity * _terrain_speed() + _knockback
	move_and_slide()


## Cuánto lo frena el suelo que está pisando (1.0 normal, menos en agua/monte).
## Mismo patrón de caché que player.gd::terrain_speed_multiplier().
# Sin tipar el caché: usamos speed_at(), que es propio de world.gd.
func _terrain_speed() -> float:
	if _world_cache == null or not is_instance_valid(_world_cache):
		_world_cache = get_tree().get_first_node_in_group("world")
	if _world_cache == null:
		return 1.0
	return _world_cache.speed_at(global_position)
