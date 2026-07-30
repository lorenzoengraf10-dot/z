class_name InventoryComponent
extends Node
## Inventario simple: id de ítem -> cantidad.
## Es un componente para poder colgarlo del jugador y, más adelante, de cofres
## o NPCs sin repetir código.

signal changed(items: Dictionary)

var items: Dictionary = {}


func add(id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	items[id] = count(id) + amount
	changed.emit(items)


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


func to_dict() -> Dictionary:
	return items.duplicate()


func from_dict(data: Dictionary) -> void:
	items.clear()
	for key in data.keys():
		var amount := int(data[key])
		if amount > 0:
			items[str(key)] = amount
	changed.emit(items)
