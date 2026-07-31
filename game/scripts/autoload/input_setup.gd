extends Node
## Autoload. Registra las acciones de input por código para no depender de
## editar el mapa de teclas a mano en project.godot. Se ejecuta al arrancar,
## antes que la escena principal.
##
## Controles:
##   WASD / flechas  mover
##   Shift           correr (gasta energía, hace mucho ruido)
##   Ctrl            agacharse (lento y silencioso)
##   E               interactuar (talar árbol / pescar)
##   Q               comer o beber lo que tengas
##   Espacio         atacar
##   B               modo construcción
##   C               crafteo
##   M               mapa
##   F5 / F9         guardar / cargar

const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"crouch": [KEY_CTRL],
	"interact": [KEY_E],
	"eat": [KEY_Q],
	"attack": [KEY_SPACE],
	"build_mode": [KEY_B],
	"crafting": [KEY_C],
	"inventory": [KEY_I, KEY_TAB],
	"toggle_map": [KEY_M],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
}


func _ready() -> void:
	for action in ACTIONS.keys():
		_add_action(str(action), ACTIONS[action])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
