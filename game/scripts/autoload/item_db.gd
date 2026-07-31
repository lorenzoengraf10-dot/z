extends Node
## Autoload. Carga las definiciones de ítems desde data/items.json una sola vez
## y las deja disponibles para todo el juego (inventario, crafteo, HUD).
##
## Agregar un ítem nuevo = editar el JSON, sin tocar código.

const ITEMS_PATH := "res://data/items.json"

var items: Dictionary = {}


func _ready() -> void:
	items = _load_items()


func _load_items() -> Dictionary:
	if not FileAccess.file_exists(ITEMS_PATH):
		push_warning("ItemDB: no se encontró " + ITEMS_PATH)
		return {}
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null:
		push_warning("ItemDB: no se pudo abrir " + ITEMS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ItemDB: items.json no tiene el formato esperado (debe ser un objeto).")
		return {}
	return parsed


func definition(id: String) -> Dictionary:
	var def: Variant = items.get(id, {})
	return def if typeof(def) == TYPE_DICTIONARY else {}


func display_name(id: String) -> String:
	return str(definition(id).get("nombre", id))


func is_edible(id: String) -> bool:
	return bool(definition(id).get("comestible", false))


func is_weapon(id: String) -> bool:
	return bool(definition(id).get("arma", false))


func is_firearm(id: String) -> bool:
	return bool(definition(id).get("fuego", false))


## Qué munición usa un arma de fuego ("" si no es de fuego).
func ammo_of(id: String) -> String:
	return str(definition(id).get("municion", ""))


func describe(id: String) -> String:
	return str(definition(id).get("descripcion", ""))


## Para qué sirve como herramienta: "tala", "mineria" o "" si no es herramienta.
func tool_kind(id: String) -> String:
	return str(definition(id).get("herramienta", ""))


func value_of(id: String, key: String) -> float:
	return float(definition(id).get(key, 0.0))
