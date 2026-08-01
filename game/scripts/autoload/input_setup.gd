extends Node
## Autoload. Registra las acciones de input por código para no depender de
## editar el mapa de teclas a mano en project.godot. Se ejecuta al arrancar,
## antes que la escena principal.
##
## El juego es **para PC**: se mueve con el teclado y se apunta con el mouse.
##
## Controles:
##   WASD / flechas  mover
##   Mouse           apuntar (mirás siempre hacia el cursor)
##   Clic izq / Espacio  atacar
##   Shift           correr (gasta energía, hace mucho ruido)
##   Ctrl            agacharse (lento y silencioso)
##   E               interactuar (puerta / contenedor / talar / pescar / picar)
##   T               tomar agua del lago (o llenar el recipiente, si tenés uno)
##   Q               comer o beber lo que tengas
##   R               vendarte
##   F               cambiar de mano (cuerpo a cuerpo <-> arma de fuego)
##   B               modo construcción
##   C               crafteo
##   I / Tab         inventario
##   M               mapa
##   H / F1          ayuda con todos los controles
##   F5 / F9         guardar / cargar

const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"crouch": [KEY_CTRL],
	"interact": [KEY_E],
	"drink_water": [KEY_T],
	"eat": [KEY_Q],
	"bandage": [KEY_R],
	"switch_weapon": [KEY_F],
	"attack": [KEY_SPACE],
	"build_mode": [KEY_B],
	"crafting": [KEY_C],
	"inventory": [KEY_I, KEY_TAB],
	"toggle_map": [KEY_M],
	"help": [KEY_H, KEY_F1],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
}

## Botones del mouse, aparte porque son otro tipo de evento.
const MOUSE_ACTIONS := {
	"attack": [MOUSE_BUTTON_LEFT],
}


func _ready() -> void:
	for action in ACTIONS.keys():
		_add_action(str(action), ACTIONS[action])
	for action in MOUSE_ACTIONS.keys():
		_add_mouse_action(str(action), MOUSE_ACTIONS[action])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _add_mouse_action(action: String, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for button in buttons:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)
