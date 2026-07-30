extends CharacterBody2D
## Jugador. Movimiento top-down con tres modos que afectan velocidad y ruido:
## agachado (lento, silencioso), caminar (normal) y correr (rápido, ruidoso).
## El "radio de ruido" es lo que los zombies usan para oírte aunque no te vean.
##
## El ruido sale de tres fuentes y siempre gana la más fuerte:
##   - moverse (según el modo)
##   - una acción sostenida, como talar un árbol (la setea el Interactor)
##   - un golpe puntual, como atacar (dura un ratito y se apaga)

signal message(text: String)

@export var walk_speed := 90.0
@export var run_speed := 170.0
@export var crouch_speed := 45.0

## Radio de ruido (en píxeles) según el modo de movimiento.
@export var walk_noise := 90.0
@export var run_noise := 190.0
@export var crouch_noise := 35.0

@export var attack_damage := 18.0
@export var attack_range := 26.0
@export var attack_arc_deg := 65.0
@export var attack_cooldown := 0.45
@export var attack_noise := 130.0
@export var attack_noise_time := 0.35

var facing := Vector2.DOWN
## Ruido sostenido de una acción (ej. talar). Lo setea el Interactor.
var action_noise := 0.0

var _move_noise := 0.0
var _burst_noise := 0.0
var _burst_timer := 0.0
var _attack_timer := 0.0

@onready var needs: NeedsComponent = $NeedsComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var interactor: Interactor = $Interactor


func _ready() -> void:
	add_to_group("player")
	needs.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	if _burst_timer > 0.0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_noise = 0.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := input_dir != Vector2.ZERO
	var crouching := Input.is_action_pressed("crouch")
	# Correr necesita energía; agachado nunca se corre.
	var running := Input.is_action_pressed("run") and moving and not crouching and needs.can_run()

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif running:
		speed = run_speed

	velocity = input_dir * speed
	move_and_slide()

	needs.exertion = 1.0 if running else 0.0

	if moving:
		facing = input_dir.normalized()
		if crouching:
			_move_noise = crouch_noise
		elif running:
			_move_noise = run_noise
		else:
			_move_noise = walk_noise
	else:
		_move_noise = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if needs.is_dead():
		return
	if event.is_action_pressed("interact"):
		interactor.try_interact()
	elif event.is_action_pressed("eat"):
		_try_eat()
	elif event.is_action_pressed("attack"):
		_try_attack()


## Lo consulta el zombie (y los animales) para saber a qué distancia te oyen.
func get_noise_radius() -> float:
	return maxf(_move_noise, maxf(action_noise, _burst_noise))


# --- Acciones ---

func _try_eat() -> void:
	var id := inventory.first_edible()
	if id == "":
		message.emit("No tenés nada para comer")
		return
	if inventory.remove(id, 1):
		needs.consume_item(id)
		message.emit("Consumiste %s" % ItemDB.display_name(id))


func _try_attack() -> void:
	if _attack_timer > 0.0:
		return
	_attack_timer = attack_cooldown
	_burst_noise = attack_noise
	_burst_timer = attack_noise_time
	interactor.cancel()

	var hits := 0
	for target in get_tree().get_nodes_in_group("damageable"):
		if not (target is Node2D):
			continue
		var to_target: Vector2 = (target as Node2D).global_position - global_position
		var dist := to_target.length()
		if dist < 0.01 or dist > attack_range:
			continue
		if absf(rad_to_deg(facing.angle_to(to_target))) > attack_arc_deg:
			continue
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
			hits += 1

	if hits == 0:
		message.emit("Golpeaste al aire")


# --- Lo llaman otros nodos ---

func apply_damage(amount: float) -> void:
	needs.damage(amount)


func apply_infection(amount: float) -> void:
	needs.infect(amount)


## La llaman los pickups al recogerlos.
func collect(item: String, amount: int) -> void:
	inventory.add(item, amount)
	message.emit("+%d %s" % [amount, ItemDB.display_name(item)])


func _on_died() -> void:
	# Prototipo: la permadeath y la dificultad van a ser configurables (ver GDD).
	# Por ahora, al morir se reinicia la escena tras un momento.
	set_physics_process(false)
	message.emit("Moriste — reiniciando...")
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
