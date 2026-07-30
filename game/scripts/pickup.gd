extends Area2D
## Objeto recolectable. Al tocarlo el jugador, suma al inventario y desaparece.

@export var item := "comida"
@export var amount := 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


# El parámetro va sin tipo porque llamamos collect(), que es del jugador y no
# existe en Node (GDScript valida los tipos estáticos al compilar).
func _on_body_entered(body) -> void:
	if body.is_in_group("player") and body.has_method("collect"):
		body.collect(item, amount)
		queue_free()
