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
## Lo prenden las pantallas modales (minijuego de fuego): te frena sin pausar el
## juego, así los zombies te siguen viniendo encima mientras forcejeás.
var input_blocked := false
## Arma equipada ("" = a mano pelada). La cambia el inventario.
var equipped_weapon := ""
## Lo baja el perk "Pisada liviana" (1.0 = normal, 0.75 = hacés menos ruido).
var noise_multiplier := 1.0

var _move_noise := 0.0
var _burst_noise := 0.0
var _burst_timer := 0.0
var _attack_timer := 0.0
var _world_cache = null

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

	# Con una pantalla modal abierta te quedás quieto, pero el mundo sigue.
	if input_blocked:
		velocity = Vector2.ZERO
		move_and_slide()
		_move_noise = 0.0
		needs.exertion = 0.0
		return

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

	# El terreno frena: el agua te deja a menos de la mitad.
	speed *= terrain_speed_multiplier()

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


## Cuánto te frena el suelo que estás pisando (1.0 normal, menos en el agua).
func terrain_speed_multiplier() -> float:
	if _world_cache == null or not is_instance_valid(_world_cache):
		_world_cache = get_tree().get_first_node_in_group("world")
	if _world_cache == null:
		return 1.0
	return _world_cache.speed_at(global_position)


func _unhandled_input(event: InputEvent) -> void:
	if needs.is_dead() or input_blocked:
		return
	if event.is_action_pressed("interact"):
		interactor.try_interact()
	elif event.is_action_pressed("eat"):
		_try_eat()
	elif event.is_action_pressed("bandage"):
		_try_bandage()
	elif event.is_action_pressed("attack"):
		_try_attack()


## Lo consulta el zombie (y los animales) para saber a qué distancia te oyen.
func get_noise_radius() -> float:
	return maxf(_move_noise, maxf(action_noise, _burst_noise)) * noise_multiplier


# --- Acciones ---

func _try_eat() -> void:
	var id := inventory.first_edible()
	if id == "":
		message.emit("No tenés nada para comer")
		return
	if inventory.remove(id, 1):
		needs.consume_item(id)
		message.emit("Consumiste %s" % ItemDB.display_name(id))


## Estadísticas del golpe actual: salen del arma equipada, o de los @export si
## vas a mano pelada.
func weapon_stats() -> Dictionary:
	if equipped_weapon == "" or not inventory.has(equipped_weapon):
		return {
			"nombre": "Manos",
			"dano": attack_damage,
			"alcance": attack_range,
			"ruido": attack_noise,
			"espera": attack_cooldown,
			"fuego": false,
			"municion": "",
		}
	return {
		"nombre": ItemDB.display_name(equipped_weapon),
		"dano": ItemDB.value_of(equipped_weapon, "dano"),
		"alcance": ItemDB.value_of(equipped_weapon, "alcance"),
		"ruido": ItemDB.value_of(equipped_weapon, "ruido"),
		"espera": ItemDB.value_of(equipped_weapon, "espera"),
		"fuego": ItemDB.is_firearm(equipped_weapon),
		"municion": ItemDB.ammo_of(equipped_weapon),
	}


## La usa el inventario al equipar.
func equip(item_id: String) -> void:
	if item_id != "" and not ItemDB.is_weapon(item_id):
		return
	equipped_weapon = item_id
	if item_id == "":
		message.emit("Guardaste el arma")
	else:
		message.emit("Equipaste %s" % ItemDB.display_name(item_id))


## Vendarse (tecla R). Usa el mejor corta-sangrado que tengas: el vendaje corta
## del todo, el trapo solo una parte.
func _try_bandage() -> void:
	if not needs.is_bleeding():
		message.emit("No estás sangrando")
		return
	var id := inventory.first_bandage()
	if id == "":
		message.emit("No tenés con qué vendarte")
		return
	if inventory.remove(id, 1):
		needs.consume_item(id)
		message.emit("Te vendaste con %s" % ItemDB.display_name(id))


func _try_attack() -> void:
	if _attack_timer > 0.0:
		return

	var weapon := weapon_stats()
	var damage := float(weapon["dano"])
	var reach := float(weapon["alcance"])

	# Las armas de fuego gastan munición. Sin balas, no dispara.
	if bool(weapon["fuego"]):
		var ammo := str(weapon["municion"])
		if not inventory.remove(ammo, 1):
			message.emit("Sin %s" % ItemDB.display_name(ammo))
			_attack_timer = 0.35
			return
		AudioManager.play("disparo")

	_attack_timer = maxf(0.15, float(weapon["espera"]))
	_burst_noise = float(weapon["ruido"])
	_burst_timer = attack_noise_time
	interactor.cancel()

	# Un disparo es un cono finito y largo; un golpe es un arco corto y ancho.
	var arc := 12.0 if bool(weapon["fuego"]) else attack_arc_deg

	var hits := 0
	# get_nodes_in_group() devuelve Array[Node]: pasamos cada uno a una variable
	# sin tipo para poder llamarle take_damage(), que no existe en Node.
	for node in get_tree().get_nodes_in_group("damageable"):
		if not (node is Node2D):
			continue
		var target = node
		var to_target: Vector2 = target.global_position - global_position
		var dist := to_target.length()
		if dist < 0.01 or dist > reach:
			continue
		if absf(rad_to_deg(facing.angle_to(to_target))) > arc:
			continue
		if target.has_method("take_damage"):
			target.take_damage(damage)
			hits += 1

	if hits == 0:
		message.emit("Erraste el tiro" if bool(weapon["fuego"]) else "Golpeaste al aire")


# --- Lo llaman otros nodos ---

func apply_damage(amount: float) -> void:
	needs.damage(amount)


## La llaman los zombies y los lobos al morderte.
func apply_bleed(amount: float) -> void:
	needs.bleed(amount)


## La llaman los pickups y los contenedores. Avisa si no entró todo.
func collect(item: String, amount: int) -> int:
	var taken := inventory.add(item, amount)
	if taken <= 0:
		message.emit("Mochila llena: no te entra %s" % ItemDB.display_name(item))
	elif taken < amount:
		message.emit("+%d %s (no entró el resto)" % [taken, ItemDB.display_name(item)])
	else:
		message.emit("+%d %s" % [taken, ItemDB.display_name(item)])
	return taken


func _on_died() -> void:
	# La partida termina acá. Quien muestra el resumen y arranca la siguiente es
	# run_manager.gd, que también escucha esta misma señal de NeedsComponent.
	set_physics_process(false)
	input_blocked = true
	message.emit("Moriste")
