extends Node
## Autoload. Registra las acciones de input por código para no depender de
## editar el mapa de teclas a mano en project.godot. Se ejecuta al arrancar,
## antes que la escena principal.

func _ready() -> void:
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("run", [KEY_SHIFT])
	_add_action("crouch", [KEY_C])
	_add_action("interact", [KEY_E])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
