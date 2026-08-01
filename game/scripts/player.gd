extends CharacterBody2D
## Jugador. **Se mueve con el teclado y apunta con el mouse** (el juego es para
## PC): mirás siempre hacia el cursor, sin importar para dónde camines. Eso es
## lo que hace que valga la pena tener armas de fuego con alcance.
##
## Movimiento top-down con tres modos que afectan velocidad y ruido: agachado
## (lento, silencioso), caminar (normal) y correr (rápido, ruidoso). El "radio
## de ruido" es lo que los zombies usan para oírte aunque no te vean, y se
## muestra como una **barra arriba de la cabeza** para que la mecánica se
## entienda sin tener que explicarla.
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
##
## La escala se mide **como porcentaje de correr**, que es el 100%. La barra que
## se dibuja sobre tu cabeza muestra ese mismo porcentaje, así lo que ves en
## pantalla y estos números son lo mismo.
##
##   agachado  25%      caminar  50%      talar  75%      correr  100%
##
## (talar y picar están en interactor.gd, que sigue la misma escala)
@export var run_noise := 190.0      ## 100%
@export var walk_noise := 95.0      ## 50%
@export var crouch_noise := 48.0    ## 25%

@export var attack_damage := 18.0
@export var attack_range := 26.0
@export var attack_arc_deg := 65.0
@export var attack_cooldown := 0.45
@export var attack_noise := 143.0   ## 75%, igual que talar
@export var attack_noise_time := 0.35

var facing := Vector2.DOWN
## Ruido sostenido de una acción (ej. talar). Lo setea el Interactor.
var action_noise := 0.0
## Lo prenden las pantallas modales (minijuego de fuego): te frena sin pausar el
## juego, así los zombies te siguen viniendo encima mientras forcejeás.
var input_blocked := false
## Lo baja el perk "Pisada liviana" (1.0 = normal, 0.75 = hacés menos ruido).
var noise_multiplier := 1.0

# --- Barra de ruido (la que se dibuja arriba de la cabeza) ---
@export var noise_bar_width := 20.0
@export var noise_bar_height := 3.0
## A qué altura flota, en píxeles sobre el centro del jugador.
@export var noise_bar_offset := 15.0

var _move_noise := 0.0
var _burst_noise := 0.0
var _burst_timer := 0.0
var _attack_timer := 0.0
var _hurt_flash := 0.0
var _world_cache = null
var _camera_cache = null

@onready var _visual: Polygon2D = $Visual
@onready var _facing_mark: Polygon2D = $Facing
@onready var _art: SpriteDirectional = $SpriteDirectional

@onready var needs: NeedsComponent = $NeedsComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var arms: ArmsComponent = $ArmsComponent
@onready var interactor: Interactor = $Interactor


func _ready() -> void:
	add_to_group("player")
	needs.died.connect(_on_died)
	# La barra de ruido se dibuja acá mismo (_draw), en coordenadas locales.
	z_index = 1


func _process(delta: float) -> void:
	# Apuntás siempre al cursor. Con una pantalla modal abierta se congela para
	# donde estabas mirando.
	if not input_blocked and not needs.is_dead():
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			facing = to_mouse.normalized()
			# El sprite elige el cuadro; el placeholder rota. Solo uno de los dos
			# está visible, según haya pixel art o no.
			_art.set_facing(facing)
			_facing_mark.rotation = facing.angle() - PI * 0.5

	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 3.0)
		var target := _art.flash_target()
		target.modulate = Color(1, 1, 1).lerp(Color(2.2, 0.5, 0.5), _hurt_flash)

	queue_redraw()


## Cuánto ruido estás haciendo, de 0 a 1, donde correr es 1.
##
## Un disparo puede pasarse de 1: una escopeta hace mucho más ruido que correr.
func noise_ratio() -> float:
	if run_noise <= 0.0:
		return 0.0
	return get_noise_radius() / run_noise


## Barra chiquita arriba de la cabeza con el ruido que estás haciendo.
##
## Antes esto era un círculo del radio exacto en el que te escuchaban. Era
## preciso pero tapaba media pantalla y quedaba feo, así que se cambió por una
## barra al estilo de la que tienen los enemigos (components/hunter_display.gd).
##
## Cuando no hacés ruido no se dibuja nada, para no ensuciar la pantalla.
func _draw() -> void:
	var ratio := noise_ratio()
	if ratio <= 0.01:
		return

	var lleno := minf(ratio, 1.0)
	# Verde callado -> amarillo -> rojo a todo volumen. Se lee de un vistazo sin
	# tener que medir cuánto ocupa la barra.
	var tint := Color(0.35, 0.85, 0.40)
	if lleno > 0.5:
		tint = Color(0.95, 0.80, 0.25).lerp(Color(1.0, 0.30, 0.25), (lleno - 0.5) * 2.0)
	else:
		tint = tint.lerp(Color(0.95, 0.80, 0.25), lleno * 2.0)

	# Más ruidoso que correr (un disparo): la barra queda llena y parpadea.
	if ratio > 1.0:
		tint = Color(1.0, 0.25, 0.20)
		tint.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 90.0))

	var esquina := Vector2(-noise_bar_width * 0.5, -noise_bar_offset)
	draw_rect(Rect2(esquina - Vector2.ONE, Vector2(noise_bar_width, noise_bar_height) + Vector2(2, 2)),
			Color(0, 0, 0, 0.55))
	draw_rect(Rect2(esquina, Vector2(noise_bar_width * lleno, noise_bar_height)), tint)


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

	# Ojo: `facing` NO sale de acá. Lo maneja _process() según dónde esté el
	# cursor, así podés caminar para un lado mirando para el otro.
	if moving:
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
	elif event.is_action_pressed("drink_water"):
		interactor.try_drink()
	elif event.is_action_pressed("eat"):
		_try_eat()
	elif event.is_action_pressed("bandage"):
		_try_bandage()
	elif event.is_action_pressed("switch_weapon"):
		arms.switch_hand()
		var id := arms.current_weapon()
		message.emit("Mano: %s" % (ItemDB.display_name(id) if id != "" else "Manos"))
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


## Estadísticas del golpe actual: salen de lo que tengas activo en ArmsComponent
## (arms.current_weapon()), o de los @export si vas a mano pelada.
func weapon_stats() -> Dictionary:
	var id := arms.current_weapon()
	if id == "":
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
		"nombre": ItemDB.display_name(id),
		"dano": ItemDB.value_of(id, "dano"),
		"alcance": ItemDB.value_of(id, "alcance"),
		"ruido": ItemDB.value_of(id, "ruido"),
		"espera": ItemDB.value_of(id, "espera"),
		"fuego": ItemDB.is_firearm(id),
		"municion": ItemDB.ammo_of(id),
	}


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

	# Las armas de fuego gastan munición del casillero de ArmsComponent (no de
	# la mochila: la munición del arma equipada vive ahí, sin ocupar lugar).
	if bool(weapon["fuego"]):
		if not arms.consume_ammo(1):
			message.emit("Sin %s" % ItemDB.display_name(str(weapon["municion"])))
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
			# Retroceso corto: se ve que el golpe llegó.
			if target.has_method("knockback"):
				target.knockback(to_target.normalized())
			hits += 1

	if hits == 0:
		message.emit("Erraste el tiro" if bool(weapon["fuego"]) else "Golpeaste al aire")


# --- Lo llaman otros nodos ---

func apply_damage(amount: float) -> void:
	needs.damage(amount)
	_hurt_flash = 1.0

	var textos = get_tree().get_first_node_in_group("floating_text")
	if textos != null:
		textos.damage(global_position, amount, true)

	if _camera_cache == null or not is_instance_valid(_camera_cache):
		_camera_cache = get_tree().get_first_node_in_group("game_camera")
	if _camera_cache != null:
		# Cuanto más fuerte el golpe, más se sacude (un mordisco de zombie es
		# ~8 de daño; uno de lobo, ~14).
		_camera_cache.shake(clampf(amount / 20.0, 0.25, 1.0))


## La llaman los zombies y los lobos al morderte.
func apply_bleed(amount: float) -> void:
	needs.bleed(amount)


## La llaman los pickups. Avisa si no entró todo.
func collect(item: String, amount: int) -> int:
	var taken := receive(item, amount)
	if taken <= 0:
		message.emit("Mochila llena: no te entra %s" % ItemDB.display_name(item))
	elif taken < amount:
		message.emit("+%d %s (no entró el resto)" % [taken, ItemDB.display_name(item)])
	else:
		message.emit("+%d %s" % [taken, ItemDB.display_name(item)])
	return taken


## El mismo reparto que collect(), pero sin el mensaje individual: lo usa
## _finish_container() en interactor.gd, que arma un solo mensaje con todo lo
## que salió del mueble en vez de uno por ítem.
##
## Si `item` es la munición del arma de fuego equipada, va directo al
## casillero de ArmsComponent y NO gasta lugar de mochila — es lo que pidió el
## testeo ("que las municiones sean de esa arma"). Cualquier otra cosa (o
## munición de un arma que no llevás) va a la mochila de siempre.
func receive(item: String, amount: int) -> int:
	var to_slot := arms.add_ammo(item, amount)
	var remaining := amount - to_slot
	var taken := to_slot
	if remaining > 0:
		taken += inventory.add(item, remaining)
	return taken


## Te da `amount` de `item` sin que se pierda NADA: lo que entra en la mochila
## va a la mochila, y lo que no entra queda tirado a tus pies.
##
## Es la forma segura de entregarle cosas al jugador desde sistemas que ya
## gastaron algo a cambio y no pueden "devolver el vuelto": lo que craftea
## (crafting.gd), lo que devuelve desarmar una construcción (build_system.gd) y
## lo que regala un perk al arrancar (run_manager.gd). Todos esos hacían
## `inventory.add()` a secas y, con la mochila llena, el objeto desaparecía en
## silencio después de haberte cobrado los materiales.
##
## Para lo que SÍ puede esperar (un árbol, una roca, un pickup del suelo) no se
## usa esto: ahí conviene no entregar nada y dejar la cosa donde estaba, así el
## jugador vuelve cuando hace lugar. Ver interactor.gd::_give_from_tile().
func give_or_drop(item: String, amount: int) -> void:
	if amount <= 0:
		return
	var taken := receive(item, amount)
	if taken < amount:
		drop_to_ground(item, amount - taken)


## Deja `amount` de `item` tirado a tus pies, sin pasar por la mochila ni por
## los casilleros de ArmsComponent. Es el escape de último recurso para que
## nunca se pierda nada; la usa give_or_drop() y también ArmsComponent al
## guardar un arma con la mochila llena.
func drop_to_ground(item: String, amount: int) -> void:
	_spawn_pickup(item, amount)


## Tira `amount` del ítem `id` al piso, en tu posición. La llama la pantalla de
## inventario (I). Devuelve true si había para tirar.
func drop(item: String, amount: int = 1) -> bool:
	if not inventory.remove(item, amount):
		return false
	_spawn_pickup(item, amount)
	message.emit("Tiraste %d %s" % [amount, ItemDB.display_name(item)])
	return true


## Instancia un Pickup con `item`/`amount` en tu posición. Lo usa drop() y
## también ArmsComponent cuando algo no entra de vuelta en la mochila (al
## desequipar un arma con la mochila llena, por ejemplo) — así nunca
## desaparece nada, mismo patrón que animal.gd al soltar carne al morir.
func _spawn_pickup(item: String, amount: int) -> void:
	if amount <= 0:
		return
	var scene := load("res://scenes/Pickup.tscn") as PackedScene
	if scene == null:
		return
	# Sin ":=" : instantiate() devuelve Node y le seteamos item/amount/position.
	var dropped = scene.instantiate()
	dropped.item = item
	dropped.amount = amount

	# Sin tipar: get_parent() devuelve Node y le pedimos to_local(), de Node2D.
	var host = get_parent()
	if host == null:
		return
	dropped.position = host.to_local(global_position) if host is Node2D else global_position
	host.add_child(dropped)


func _on_died() -> void:
	# La partida termina acá. Quien muestra el resumen y arranca la siguiente es
	# run_manager.gd, que también escucha esta misma señal de NeedsComponent.
	set_physics_process(false)
	input_blocked = true
	message.emit("Moriste")
