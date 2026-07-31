class_name InventoryComponent
extends Node
## Inventario con **espacio limitado**: id de ítem -> cantidad.
##
## Como en Mini DAYZ, arrancás pudiendo cargar muy poco y las mochilas que
## encontrás saqueando te suben la capacidad. Eso obliga a elegir qué te llevás
## y qué dejás, que es media gracia del juego.
##
## Cada **unidad** ocupa un lugar (3 maderas = 3 lugares). Es simple de entender
## y de mostrar en pantalla.

signal changed(items: Dictionary)
signal full(item: String)

## Lugares con los que arrancás, sin ninguna mochila.
@export var base_capacity := 8

var items: Dictionary = {}
## Lo suma el perk "Espalda ancha".
var bonus_capacity := 0


## Capacidad total = base + perk + lo que aporten las mochilas que llevás.
func capacity() -> int:
	var total := base_capacity + bonus_capacity
	for key in items.keys():
		var extra := int(ItemDB.value_of(str(key), "capacidad"))
		if extra > 0:
			total += extra * int(items[key])
	return total


func used() -> int:
	var total := 0
	for key in items.keys():
		total += int(items[key])
	return total


func free_space() -> int:
	return maxi(0, capacity() - used())


func is_full() -> bool:
	return free_space() <= 0


## Agrega lo que entre y devuelve **cuánto entró realmente**. Si no entra todo,
## avisa por la señal `full` para que el HUD lo diga.
func add(id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var room := free_space()
	if room <= 0:
		full.emit(id)
		return 0
	var taken := mini(amount, room)
	items[id] = count(id) + taken
	changed.emit(items)
	if taken < amount:
		full.emit(id)
	return taken


## Devuelve false (sin tocar nada) si no alcanza la cantidad pedida.
func remove(id: String, amount: int = 1) -> bool:
	if amount <= 0 or not has(id, amount):
		return false
	var left := count(id) - amount
	if left > 0:
		items[id] = left
	else:
		items.erase(id)
	changed.emit(items)
	return true


func count(id: String) -> int:
	return int(items.get(id, 0))


func has(id: String, amount: int = 1) -> bool:
	return count(id) >= amount


## Primer ítem comestible que haya, o "" si no hay ninguno.
func first_edible() -> String:
	for id in items.keys():
		if ItemDB.is_edible(str(id)):
			return str(id)
	return ""


## Primer ítem que corte el sangrado (vendaje o trapo), o "".
func first_bandage() -> String:
	var best := ""
	var best_value := 0.0
	for id in items.keys():
		var value := ItemDB.value_of(str(id), "corta_sangrado")
		if value > best_value:
			best_value = value
			best = str(id)
	return best


func clear() -> void:
	items.clear()
	changed.emit(items)


func to_dict() -> Dictionary:
	return items.duplicate()


func from_dict(data: Dictionary) -> void:
	items.clear()
	for key in data.keys():
		var amount := int(data[key])
		if amount > 0:
			items[str(key)] = amount
	changed.emit(items)
