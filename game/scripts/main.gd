extends Node2D

@onready var map_screen: CanvasLayer = $MapScreen

func _ready() -> void:
	map_screen.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		map_screen.visible = not map_screen.visible
