extends Camera2D
## Cámara que sigue al jugador (es hija suya) y se **sacude** cuando te pegan.
##
## La sacudida es corta a propósito: lo justo para que el golpe se sienta, sin
## marear ni tapar lo que está pasando alrededor.

## Cuánto se desplaza como máximo, en píxeles.
@export var max_offset := 6.0
## Cuánto tarda en apagarse una sacudida, en segundos.
@export var decay := 0.55

var _strength := 0.0


func _ready() -> void:
	add_to_group("game_camera")


func _process(delta: float) -> void:
	if _strength <= 0.0:
		return
	_strength = maxf(0.0, _strength - delta / maxf(decay, 0.01))
	# Al cuadrado: arranca fuerte y se apaga rápido, que es como se siente un golpe.
	var amount := max_offset * _strength * _strength
	offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	if _strength <= 0.0:
		offset = Vector2.ZERO


## Sacude la cámara. `amount` va de 0 a 1; se queda con la más fuerte de las que
## haya en curso para que dos golpes seguidos no se anulen.
func shake(amount: float) -> void:
	_strength = maxf(_strength, clampf(amount, 0.0, 1.0))
