class_name NeedIcon
extends Control
## Íconos de las necesidades del HUD, dibujados por código.
##
## Son placeholders, igual que los tiles: la idea es reemplazarlos por sprites
## de pixel art más adelante. Están todos acá, en un solo archivo, justo para
## que ese reemplazo sea cambiar una cosa sola y no revolver el HUD entero.
##
## Cada ícono se define como una lista de polígonos en una grilla de 0 a 1, así
## se dibuja igual en cualquier tamaño.

const SIZE := 16

## Forma de cada necesidad. Coordenadas de 0.0 a 1.0 dentro del cuadrado.
const SHAPES := {
	"salud": [                                    # corazón
		[[0.5, 0.28], [0.30, 0.10], [0.10, 0.24], [0.10, 0.45],
		 [0.5, 0.90], [0.90, 0.45], [0.90, 0.24], [0.70, 0.10]],
	],
	"hambre": [                                   # muslo de pollo
		[[0.62, 0.10], [0.88, 0.24], [0.88, 0.48], [0.62, 0.60], [0.44, 0.44], [0.44, 0.22]],
		[[0.10, 0.90], [0.20, 0.94], [0.62, 0.52], [0.52, 0.42]],
	],
	"sed": [                                      # gota
		[[0.5, 0.06], [0.82, 0.52], [0.82, 0.70], [0.5, 0.94],
		 [0.18, 0.70], [0.18, 0.52]],
	],
	"energia": [                                  # rayo
		[[0.60, 0.05], [0.22, 0.55], [0.46, 0.55], [0.36, 0.95], [0.78, 0.42], [0.52, 0.42]],
	],
	"temperatura": [                              # termómetro
		[[0.38, 0.06], [0.62, 0.06], [0.62, 0.58], [0.38, 0.58]],
		[[0.28, 0.62], [0.72, 0.62], [0.72, 0.94], [0.28, 0.94]],
	],
	"sangrado": [                                 # gota partida
		[[0.5, 0.06], [0.80, 0.50], [0.80, 0.68], [0.5, 0.92],
		 [0.20, 0.68], [0.20, 0.50]],
		[[0.5, 0.30], [0.66, 0.62], [0.5, 0.74], [0.34, 0.62]],
	],
}

## Qué necesidad dibuja. Se setea antes de meterlo en el árbol.
var need_id := "salud"
var tint := Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	# Un ícono nunca se come un clic: si no, con el apuntado con mouse el HUD
	# te bloquea los disparos.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(id: String, color: Color) -> NeedIcon:
	need_id = id
	tint = color
	queue_redraw()
	return self


func set_tint(color: Color) -> void:
	if tint == color:
		return
	tint = color
	queue_redraw()


func _draw() -> void:
	var shape: Variant = SHAPES.get(need_id, [])
	if typeof(shape) != TYPE_ARRAY:
		return
	var scale_to := size if size.x > 0.0 else Vector2(SIZE, SIZE)
	# El segundo polígono de cada ícono es el detalle: va más oscuro.
	var i := 0
	for polygon in shape:
		var points := PackedVector2Array()
		for point in polygon:
			points.append(Vector2(float(point[0]), float(point[1])) * scale_to)
		draw_colored_polygon(points, tint if i == 0 else tint.darkened(0.45))
		i += 1
