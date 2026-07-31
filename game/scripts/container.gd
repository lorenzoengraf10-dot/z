extends StaticBody2D
## Contenedor saqueable (armario, cajón, botiquín, caja militar).
##
## Es el corazón del loop: entrás a un edificio, lo revisás con **E**, sacás lo
## que puedas y te vas antes de que te escuchen. Revisarlo lleva tiempo, hace
## algo de ruido, y **cada contenedor se puede revisar una sola vez**.
##
## Lo que sale de cada tipo está en data/loot_tables.json: agregar loot nuevo es
## editar ese archivo, sin tocar código.

signal searched(container_type: String, loot: Dictionary)

@export var container_type := "armario"
## Cuánto tarda en revisarse.
@export var search_seconds := 2.2
## Ruido mientras revolvés.
@export var search_noise := 110.0

var looted := false

@onready var _body: Polygon2D = $Body
@onready var _lid: Polygon2D = $Lid


func _ready() -> void:
	add_to_group("container")
	_apply_visuals()


## Genera el botín según la tabla del tipo. Devuelve {item: cantidad}.
## Marca el contenedor como ya revisado.
func take_loot() -> Dictionary:
	if looted:
		return {}
	looted = true
	_apply_visuals()
	# Cuenta para el resumen de la partida (aunque no te entre nada: lo revisaste).
	var run = get_tree().get_first_node_in_group("run_manager")
	if run != null:
		run.count_container()
	var loot := LootDB.roll(container_type)
	searched.emit(container_type, loot)
	return loot


func display_name() -> String:
	return LootDB.table_name(container_type)


func _apply_visuals() -> void:
	if looted:
		# Vacío: se ve abierto y apagado, para no volver a caminar hasta él.
		_body.color = Color(0.28, 0.24, 0.20)
		_lid.color = Color(0.22, 0.19, 0.16)
		_lid.position = Vector2(0, -7)
		return

	match container_type:
		"botiquin":
			_body.color = Color(0.82, 0.82, 0.84)
			_lid.color = Color(0.78, 0.22, 0.22)
		"militar":
			_body.color = Color(0.32, 0.38, 0.28)
			_lid.color = Color(0.24, 0.30, 0.22)
		"cajon":
			_body.color = Color(0.48, 0.36, 0.22)
			_lid.color = Color(0.38, 0.28, 0.17)
		_:
			_body.color = Color(0.56, 0.42, 0.26)
			_lid.color = Color(0.44, 0.32, 0.20)
	_lid.position = Vector2.ZERO


# --- Guardado ---

func to_dict() -> Dictionary:
	return {"tipo": container_type, "vacio": looted}


func from_dict(data: Dictionary) -> void:
	container_type = str(data.get("tipo", container_type))
	looted = bool(data.get("vacio", false))
	_apply_visuals()
