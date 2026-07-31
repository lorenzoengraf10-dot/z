extends Node2D
## Lo que se ve sobre un enemigo: **barra de vida** y **estado de alerta**.
##
## Es hijo del zombi y del lobo, y no sabe nada de sus IAs: les pregunta por
## `alert_level()` y `health_ratio()`. Así el dibujo vive en un solo archivo y
## agregar un enemigo nuevo es implementar esos dos métodos.
##
## El ícono de alerta es lo que hace que el sigilo se pueda jugar:
##   (nada)  tranquilo, no sabe que existís
##   ?       te escuchó, va hacia tu última posición
##   !       te está viendo
##
## Sin esto no tenías forma de saber si te habían detectado hasta tenerlo
## encima, y todo el sistema de ruido era invisible.

## Alto al que flota, en píxeles sobre el centro del enemigo.
@export var height := 13.0
@export var bar_width := 16.0
@export var bar_height := 2.5

const HEARD := Color(1.0, 0.82, 0.25)
const SEEN := Color(1.0, 0.28, 0.24)

var _label: Label
var _hunter = null


func _ready() -> void:
	# Sobre el techo de los edificios: si no, un zombi adentro de una casa te
	# marcaría con un "!" que no se ve.
	z_index = 25

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size = Vector2(20, 16)
	_label.position = Vector2(-10, -height - 18)
	_label.visible = false
	add_child(_label)

	_hunter = get_parent()


func _process(_delta: float) -> void:
	if _hunter == null or not is_instance_valid(_hunter):
		return

	var level := int(_hunter.alert_level())
	if level >= 2:
		_label.text = "!"
		_label.modulate = SEEN
		_label.visible = true
	elif level == 1:
		_label.text = "?"
		_label.modulate = HEARD
		_label.visible = true
	else:
		_label.visible = false

	queue_redraw()


func _draw() -> void:
	if _hunter == null or not is_instance_valid(_hunter):
		return
	# La barra solo aparece un rato después de pegarle: si estuviera siempre, el
	# mapa se llenaría de barritas.
	if not bool(_hunter.show_health_bar()):
		return

	var ratio := clampf(float(_hunter.health_ratio()), 0.0, 1.0)
	var top_left := Vector2(-bar_width * 0.5, -height)
	draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(bar_width + 2, bar_height + 2)),
			Color(0, 0, 0, 0.65))
	draw_rect(Rect2(top_left, Vector2(bar_width * ratio, bar_height)),
			Color(0.9, 0.25, 0.22).lerp(Color(0.35, 0.85, 0.35), ratio))
