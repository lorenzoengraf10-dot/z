extends Node2D
## Escena principal. Se encarga de lo que no es de ningún sistema en particular:
## por ahora, arrancar la música ambiente.
##
## Cada pantalla (mapa, inventario, resumen de partida) maneja su propia tecla,
## así el que la abre es también el que decide si pausa el juego.


func _ready() -> void:
	# Si todavía no hay archivo de música, AudioManager avisa y sigue de largo.
	AudioManager.play_music("ambiente")
