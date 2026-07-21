extends CanvasLayer
## HUD: barras de salud y hambre + contador de comida. Se conecta a las señales
## del jugador para actualizarse solo.

@onready var health_bar: ProgressBar = $Panel/HealthBar
@onready var hunger_bar: ProgressBar = $Panel/HungerBar
@onready var food_label: Label = $Panel/FoodLabel


func _ready() -> void:
	# Esperamos un frame para asegurarnos de que el jugador ya esté en el árbol.
	await get_tree().process_frame

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]

	var needs: NeedsComponent = player.get_node("NeedsComponent")
	needs.health_changed.connect(_on_health_changed)
	needs.hunger_changed.connect(_on_hunger_changed)
	_on_health_changed(needs.health, needs.max_health)
	_on_hunger_changed(needs.hunger, needs.max_hunger)

	if player.has_signal("inventory_changed"):
		player.inventory_changed.connect(_on_inventory_changed)
		_on_inventory_changed(player.inventory)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_hunger_changed(current: float, maximum: float) -> void:
	hunger_bar.max_value = maximum
	hunger_bar.value = current


func _on_inventory_changed(inventory: Dictionary) -> void:
	food_label.text = "Comida: %d" % int(inventory.get("comida", 0))
