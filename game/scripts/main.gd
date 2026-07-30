extends Node2D
## Escena principal. Se encarga de lo que no es de ningún sistema en particular:
## abrir/cerrar el mapa y arrancar la música ambiente.

@onready var map_screen: CanvasLayer = $MapScreen


func _ready() -> void:
	map_screen.visible = false
	# Si todavía no hay archivo de música, AudioManager avisa y sigue de largo.
	AudioManager.play_music("ambiente")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		map_screen.visible = not map_screen.visible
		get_viewport().set_input_as_handled()
