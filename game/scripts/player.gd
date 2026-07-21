extends CharacterBody2D
## Jugador. Movimiento top-down con tres modos que afectan velocidad y ruido:
## agachado (lento, silencioso), caminar (normal) y correr (rápido, ruidoso).
## El "radio de ruido" es lo que los zombies usan para oírte aunque no te vean.

@export var walk_speed := 90.0
@export var run_speed := 170.0
@export var crouch_speed := 45.0

## Radio de ruido (en píxeles) según el modo de movimiento.
@export var walk_noise := 90.0
@export var run_noise := 190.0
@export var crouch_noise := 35.0

## Cuánta hambre restaura comer una unidad de comida.
@export var food_restore := 30.0

signal inventory_changed(inventory: Dictionary)

var facing := Vector2.DOWN
var noise_radius := 0.0
var inventory := {}

@onready var needs: NeedsComponent = $NeedsComponent


func _ready() -> void:
	add_to_group("player")
	needs.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := input_dir != Vector2.ZERO
	var running := Input.is_action_pressed("run")
	var crouching := Input.is_action_pressed("crouch")

	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif running:
		speed = run_speed

	velocity = input_dir * speed
	move_and_slide()

	if moving:
		facing = input_dir.normalized()
		if crouching:
			noise_radius = crouch_noise
		elif running:
			noise_radius = run_noise
		else:
			noise_radius = walk_noise
	else:
		noise_radius = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_eat()


## Lo consulta el zombie para saber a qué distancia te puede oír.
func get_noise_radius() -> float:
	return noise_radius


## Lo llama el zombie al atacar.
func apply_damage(amount: float) -> void:
	needs.damage(amount)


## Lo llaman los pickups al recogerlos.
func collect(item: String, amount: int) -> void:
	inventory[item] = inventory.get(item, 0) + amount
	inventory_changed.emit(inventory)


func _try_eat() -> void:
	if inventory.get("comida", 0) > 0:
		inventory["comida"] -= 1
		needs.eat(food_restore)
		inventory_changed.emit(inventory)


func _on_died() -> void:
	# Prototipo: la permadeath y la dificultad van a ser configurables (ver GDD).
	# Por ahora, al morir se reinicia la escena tras un momento.
	set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
