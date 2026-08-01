extends Area2D
## Objeto recolectable. Al tocarlo el jugador, suma al inventario.
##
## ⚠ Si la mochila está llena, el pickup NO desaparece: player.collect()
## devuelve cuánto entró de verdad, y si sobró algo se queda tirado en el
## suelo con la cantidad que falta. Antes desaparecía igual y lo que no
## entraba se perdía para siempre — justo lo que más se quejó el testeo.

@export var item := "comida"
@export var amount := 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


# El parámetro va sin tipo porque llamamos collect(), que es del jugador y no
# existe en Node (GDScript valida los tipos estáticos al compilar).
func _on_body_entered(body) -> void:
	if not (body.is_in_group("player") and body.has_method("collect")):
		return
	var taken: int = body.collect(item, amount)
	if taken <= 0:
		return
	amount -= taken
	if amount <= 0:
		queue_free()
