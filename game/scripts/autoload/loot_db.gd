extends Node
## Autoload. Carga data/loot_tables.json y sortea el botín de los contenedores.
##
## El sorteo es por **peso**: un ítem con peso 30 sale el triple de seguido que
## uno con peso 10. Cada contenedor hace entre `tiradas[0]` y `tiradas[1]`
## sorteos, así que puede salir más de una cosa.

const TABLES_PATH := "res://data/loot_tables.json"

var tables: Dictionary = {}


func _ready() -> void:
	tables = _load()


func _load() -> Dictionary:
	if not FileAccess.file_exists(TABLES_PATH):
		push_warning("LootDB: no se encontró " + TABLES_PATH)
		return {}
	var file := FileAccess.open(TABLES_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LootDB: loot_tables.json no tiene el formato esperado.")
		return {}

	var out := {}
	for key in parsed.keys():
		# Las claves que arrancan con "_" son comentarios del archivo.
		if not str(key).begins_with("_"):
			out[str(key)] = parsed[key]
	return out


func table_ids() -> Array:
	return tables.keys()


func table_name(table_id: String) -> String:
	var table: Variant = tables.get(table_id, {})
	if typeof(table) != TYPE_DICTIONARY:
		return table_id
	return str(table.get("nombre", table_id))


## Sortea el botín de un contenedor. Devuelve {item: cantidad}.
func roll(table_id: String) -> Dictionary:
	var table: Variant = tables.get(table_id, {})
	if typeof(table) != TYPE_DICTIONARY:
		return {}

	var entries: Array = table.get("botin", [])
	if entries.is_empty():
		return {}

	var range_values: Array = table.get("tiradas", [1, 1])
	var low := int(range_values[0]) if range_values.size() > 0 else 1
	var high := int(range_values[1]) if range_values.size() > 1 else low
	var draws := randi_range(mini(low, high), maxi(low, high))

	var total_weight := 0
	for entry in entries:
		total_weight += int(entry.get("peso", 1))
	if total_weight <= 0:
		return {}

	var loot := {}
	for i in range(draws):
		var pick := randi_range(1, total_weight)
		var running := 0
		for entry in entries:
			running += int(entry.get("peso", 1))
			if pick <= running:
				var item := str(entry.get("item", ""))
				var amount := randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
				if item != "" and amount > 0:
					loot[item] = int(loot.get(item, 0)) + amount
				break
	return loot
