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

## No es una tabla de loot real (no está en loot_tables.json): un cofre
## arranca directo con looted=true, así nunca sortea botín — solo sirve para
## guardar (ver Chest.tscn).
const CHEST_TYPE := "cofre"

@export var container_type := "armario"
## Cuánto tarda en revisarse.
@export var search_seconds := 2.2
## Ruido mientras revolvés.
@export var search_noise := 110.0

var looted := false

## Lo que quedó adentro: lo que no entró en la mochila al saquear (ver
## add_leftover(), lo llama interactor.gd), o lo que alguien haya guardado a
## propósito una vez que el mueble ya está vacío (ver ui/storage_screen.gd).
## Es lo mismo que hace que un armario ya revisado sirva como almacenamiento.
var stored: Dictionary = {}

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
	if container_type == CHEST_TYPE:
		return "Cofre"
	return LootDB.table_name(container_type)


## Lo que no entró en la mochila al saquear se queda ACÁ en vez de perderse.
## Antes take_loot() ya marcaba el mueble como revisado y lo sobrante
## desaparecía para siempre — era la queja más fuerte del testeo.
func add_leftover(id: String, amount: int) -> void:
	if amount <= 0:
		return
	stored[id] = int(stored.get(id, 0)) + amount
	refresh_visuals()


## Repinta el mueble según cómo esté ahora. La llama ui/storage_screen.gd cada
## vez que movés algo, para que se note de afuera si quedó algo adentro sin
## tener que volver a abrirlo.
func refresh_visuals() -> void:
	if _body == null or _lid == null:
		return   # todavía no pasó por _ready(): ya se va a pintar solo ahí
	_apply_visuals()


func _apply_visuals() -> void:
	if container_type == CHEST_TYPE:
		# El cofre no se "apaga" nunca: aunque looted quede en true desde que
		# se construye, tiene que seguir viéndose como un mueble útil, no como
		# un armario ya revisado.
		_body.color = Color(0.42, 0.30, 0.16)
		_lid.color = Color(0.30, 0.20, 0.10)
		_lid.position = Vector2.ZERO
		return

	if looted:
		# Vacío pero NO muerto: se ve abierto (ya lo saqueaste) y algo apagado,
		# pero sigue teniendo color de mueble usable, porque ahora sirve de
		# guardado. El gris de antes era la señal universal de "no vuelvas acá",
		# y justo estos 93 muebles son los que queremos que se vuelvan a usar.
		# Si ADEMÁS tiene algo guardado adentro, se ve casi como uno sin saquear.
		if stored.is_empty():
			_body.color = Color(0.40, 0.33, 0.24)
			_lid.color = Color(0.31, 0.25, 0.18)
		else:
			_body.color = Color(0.50, 0.40, 0.26)
			_lid.color = Color(0.39, 0.31, 0.20)
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
	return {"tipo": container_type, "vacio": looted, "guardado": stored.duplicate()}


func from_dict(data: Dictionary) -> void:
	container_type = str(data.get("tipo", container_type))
	looted = bool(data.get("vacio", false))
	stored.clear()
	for key in data.get("guardado", {}).keys():
		var amount := int(data["guardado"][key])
		if amount > 0:
			stored[str(key)] = amount
	_apply_visuals()
