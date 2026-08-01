class_name ArmsComponent
extends Node
## Los 3 casilleros de "lo que tenés en la mano": arma cuerpo a cuerpo, arma de
## fuego, y la munición de esa arma de fuego. NINGUNO de los tres ocupa lugar
## en la mochila — es lo que pidió el testeo: equipar te devuelve el lugar.
##
## Cualquier arma o munición que NO esté acá (otra arma que encontraste,
## munición de un arma distinta a la que llevás) sigue yendo a la mochila
## normal y ocupando espacio ahí, como siempre.
##
## Se puede tener las dos armas equipadas a la vez (una en cada mano, en los
## hechos) y elegir cuál pega de verdad con la tecla **F**. Eso deja que
## alternes cuchillo/pistola sin tener que abrir el inventario cada vez.

signal changed

const MELEE := "melee"
const FIREARM := "firearm"

var melee := ""
var firearm := ""
var ammo := 0
## Cuál de las dos "pega" de verdad ahora. Se cambia con F (switch_hand()).
var active := MELEE

@onready var _inventory: InventoryComponent = get_parent().get_node("InventoryComponent")


## Id del arma que de verdad ataca ahora ("" = manos, si el casillero activo
## está vacío).
func current_weapon() -> String:
	return firearm if active == FIREARM else melee


## Cambia cuál mano pega. No hace nada si no tenés nada en la otra.
func switch_hand() -> void:
	var other := FIREARM if active == MELEE else MELEE
	if (other == FIREARM and firearm == "") or (other == MELEE and melee == ""):
		return
	active = other
	changed.emit()


## Alterna: si `id` ya está equipada la guarda, si no la equipa. Sirve para
## un solo clic en el inventario sin que la pantalla tenga que decidir en cuál
## de los dos casilleros va.
func toggle(id: String) -> void:
	if ItemDB.is_firearm(id):
		if firearm == id:
			unequip_firearm()
		else:
			equip(id)
	elif ItemDB.is_weapon(id):
		if melee == id:
			unequip_melee()
		else:
			equip(id)


## Saca `id` de la mochila y la pone en el casillero que corresponda. Devuelve
## false si no es un arma o no la tenés.
func equip(id: String) -> bool:
	if id == "" or not ItemDB.is_weapon(id) or not _inventory.has(id):
		return false
	if ItemDB.is_firearm(id):
		_swap_firearm(id)
	else:
		_swap_melee(id)
	changed.emit()
	return true


func unequip_melee() -> void:
	if melee == "":
		return
	_return_to_inventory(melee, 1)
	melee = ""
	if active == MELEE and firearm != "":
		active = FIREARM
	changed.emit()


func unequip_firearm() -> void:
	if firearm == "":
		return
	_return_ammo_and_clear()
	_return_to_inventory(firearm, 1)
	firearm = ""
	if active == FIREARM and melee != "":
		active = MELEE
	changed.emit()


## Si `ammo_id` es la munición del arma de fuego equipada, la suma ACÁ (no
## ocupa mochila) y devuelve cuánto entró. Si no coincide devuelve 0, y quien
## llama la manda a la mochila normal (ver player.collect()).
func add_ammo(ammo_id: String, amount: int) -> int:
	if firearm == "" or amount <= 0 or ItemDB.ammo_of(firearm) != ammo_id:
		return 0
	ammo += amount
	changed.emit()
	return amount


func consume_ammo(amount: int = 1) -> bool:
	if ammo < amount:
		return false
	ammo -= amount
	changed.emit()
	return true


func _swap_melee(id: String) -> void:
	if melee == id:
		return
	if melee != "":
		_return_to_inventory(melee, 1)
	_inventory.remove(id, 1)
	melee = id
	if firearm == "":
		active = MELEE


func _swap_firearm(id: String) -> void:
	if firearm == id:
		return
	if firearm != "":
		_return_ammo_and_clear()
		_return_to_inventory(firearm, 1)
	_inventory.remove(id, 1)
	firearm = id
	active = FIREARM


## Devuelve la munición que quede a la mochila (o al piso si no entra) y
## limpia el casillero. Se llama SIEMPRE antes de sacar un arma de fuego del
## casillero — si no, esas balas quedarían huérfanas de un arma que ya no
## está, y no hay forma de mostrarlas en ningún lado.
func _return_ammo_and_clear() -> void:
	if ammo <= 0:
		return
	var ammo_id := ItemDB.ammo_of(firearm)
	if ammo_id != "":
		_return_to_inventory(ammo_id, ammo)
	ammo = 0


## Devuelve `id` a la mochila; lo que no entre se tira al piso con el mismo
## patrón que player.drop() — nunca desaparece nada.
func _return_to_inventory(id: String, amount: int) -> void:
	var taken := _inventory.add(id, amount)
	if taken < amount:
		var player = get_parent()
		if player.has_method("_spawn_pickup"):
			player._spawn_pickup(id, amount - taken)


func to_dict() -> Dictionary:
	return {"cuerpo_a_cuerpo": melee, "fuego": firearm, "municion": ammo, "activa": active}


func from_dict(data: Dictionary) -> void:
	melee = str(data.get("cuerpo_a_cuerpo", ""))
	firearm = str(data.get("fuego", ""))
	ammo = int(data.get("municion", 0))
	active = str(data.get("activa", MELEE))
	changed.emit()
