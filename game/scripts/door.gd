extends Structure
## Puerta. Se abre y se cierra con E.
##
## Cerrada: la colisión está activa en la capa 1, así que **frena a los zombies
## y les corta la línea de vista** (su raycast apunta a esa capa). Abierta:
## se desactiva y se puede pasar.
##
## **Se puede romper.** Hereda de Structure, así que un zombi trabado del otro
## lado le va a pegar hasta tirarla. Es a propósito: mientras las puertas eran
## indestructibles, meterse en cualquiera de las 24 casas del mapa ganaba la
## partida solo. Ahora una casa es el punto de partida de tu refugio, no la
## respuesta a todo.
##
## Al romperse **no desaparece el nodo**: queda abierta para siempre y no se
## puede volver a cerrar. Si se borrara, el marco quedaría como un hueco raro y
## door_system.gd perdería la referencia que usa para guardar y cargar.

signal state_changed(open: bool)

@export var start_open := false

var is_open := false

@onready var _shape: CollisionShape2D = $CollisionShape2D
# Cuelga de Visual (y no de la raíz) porque Structure usa ese nodo como el que
# parpadea al recibir un golpe: así el destello agarra la hoja y la manija juntas.
@onready var _panel: Polygon2D = $Visual/Panel


func _ready() -> void:
	# super() primero: es lo que registra el grupo "structure" y pone la vida al
	# máximo. Sin esto la puerta tendría vida 0 y nacería rota.
	super()
	add_to_group("door")
	is_open = start_open
	_apply()


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	# Una puerta rota no se puede cerrar: ya no queda nada que cerrar.
	if is_broken() and not value:
		return
	if is_open == value:
		return
	is_open = value
	_apply()
	state_changed.emit(is_open)
	AudioManager.play("puerta")


## Al quedarse sin vida se abre y se queda así. Pisa el _on_broken() de
## Structure, que por defecto borra el nodo.
func _on_broken() -> void:
	if not is_open:
		is_open = true
		state_changed.emit(true)
	_apply()


## Arreglarla la saca del estado "rota": vuelve a dibujarse como una puerta
## abierta normal y se puede volver a cerrar con E.
func _on_repaired() -> void:
	_apply()


func _apply() -> void:
	# disabled se toca diferido: cambiar una colisión en pleno paso de física
	# tira error en Godot.
	_shape.set_deferred("disabled", is_open)
	if is_broken():
		# Rota: astillas contra el marco, más oscura que una simplemente abierta,
		# para que se note de un vistazo que esa casa ya no cierra.
		_panel.scale = Vector2(1.0, 0.12)
		_panel.color = Color(0.28, 0.20, 0.13)
		return
	if is_open:
		# Abierta: se dibuja finita contra el marco.
		_panel.scale = Vector2(1.0, 0.18)
		_panel.color = Color(0.45, 0.32, 0.19)
	else:
		_panel.scale = Vector2.ONE
		_panel.color = Color(0.60, 0.43, 0.25)


func status_text() -> String:
	if is_broken():
		return "rota"
	return "abierta" if is_open else "cerrada"


# --- Guardado ---

func to_dict() -> Dictionary:
	# merge() con lo que guarda Structure (la vida), para no repetir la clave acá
	# y que quede desincronizada si cambia allá.
	var data := super()
	data["abierta"] = is_open
	return data


func from_dict(data: Dictionary) -> void:
	super(data)
	set_open(bool(data.get("abierta", false)))
	# Si venía rota, hay que reaplicar el estado roto: set_open() no lo hace.
	if is_broken():
		_on_broken()
