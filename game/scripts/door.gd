extends StaticBody2D
## Puerta. Se abre y se cierra con E.
##
## Cerrada: la colisión está activa en la capa 1, así que **frena a los zombies
## y les corta la línea de vista** (su raycast apunta a esa capa). Abierta:
## se desactiva y se puede pasar.
##
## O sea que encerrarte y cerrar la puerta es una defensa real.

signal state_changed(open: bool)

@export var start_open := false

var is_open := false

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _panel: Polygon2D = $Panel


func _ready() -> void:
	add_to_group("door")
	is_open = start_open
	_apply()


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	if is_open == value:
		return
	is_open = value
	_apply()
	state_changed.emit(is_open)
	AudioManager.play("puerta")


func _apply() -> void:
	# disabled se toca diferido: cambiar una colisión en pleno paso de física
	# tira error en Godot.
	_shape.set_deferred("disabled", is_open)
	if is_open:
		# Abierta: se dibuja finita contra el marco.
		_panel.scale = Vector2(1.0, 0.18)
		_panel.color = Color(0.45, 0.32, 0.19)
	else:
		_panel.scale = Vector2.ONE
		_panel.color = Color(0.60, 0.43, 0.25)


func status_text() -> String:
	return "abierta" if is_open else "cerrada"


# --- Guardado ---

func to_dict() -> Dictionary:
	return {"abierta": is_open}


func from_dict(data: Dictionary) -> void:
	set_open(bool(data.get("abierta", false)))
