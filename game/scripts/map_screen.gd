extends CanvasLayer

const MAP_DATA_PATH := "res://data/world_map.json"

@onready var markers_container: Control = $Markers
@onready var title_label: Label = $Title

func _ready() -> void:
	add_to_group("map_screen")
	var data := _load_map_data()
	if data.is_empty():
		title_label.text = "Mapa — sin datos (revisar data/world_map.json)"
		return

	title_label.text = "Mapa — %s" % data.get("region_name", "Región sin nombre")

	if data.has("hub"):
		_spawn_marker(data["hub"], true)

	for poi in data.get("points_of_interest", []):
		_spawn_marker(poi, false)


func _load_map_data() -> Dictionary:
	if not FileAccess.file_exists(MAP_DATA_PATH):
		push_warning("No se encontró world_map.json en " + MAP_DATA_PATH)
		return {}

	var file := FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("world_map.json no tiene el formato esperado (debe ser un objeto JSON)")
		return {}

	return parsed


func _spawn_marker(poi: Dictionary, is_hub: bool) -> void:
	var label := Label.new()
	label.text = poi.get("name", "???")
	label.tooltip_text = poi.get("description", "")

	var pos: Array = poi.get("position", [0.5, 0.5])
	var viewport_size := get_viewport().get_visible_rect().size
	label.position = Vector2(pos[0] * viewport_size.x, pos[1] * viewport_size.y)

	if is_hub:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	markers_container.add_child(label)
