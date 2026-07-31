extends StaticBody2D
## Mesa de trabajo. Sin una de estas cerca no se puede craftear nada: es lo
## primero que conviene armar cuando juntás algo de madera.
##
## Se construye con el modo construcción (tecla B), igual que las barricadas y
## las fogatas.

## Radio en el que sirve para craftear.
@export var use_radius := 110.0


func _ready() -> void:
	add_to_group("workbench")


## ¿Alcanza para craftear desde esta posición?
func can_craft_from(world_position: Vector2) -> bool:
	return global_position.distance_to(world_position) <= use_radius
