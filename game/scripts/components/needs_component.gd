class_name NeedsComponent
extends Node
## Necesidades del personaje. Por ahora salud y hambre; en la Fase 2 se suman
## sed, cansancio, temperatura e infección (ver docs/ROADMAP.md).
## Se diseña como componente reutilizable para poder colgarlo también de NPCs.

signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal died

@export var max_health := 100.0
@export var max_hunger := 100.0
## Cuánta hambre se pierde por segundo.
@export var hunger_decay_per_second := 1.0
## Daño por segundo cuando el hambre llega a 0.
@export var starving_damage_per_second := 2.0

var health := 0.0
var hunger := 0.0
var _dead := false


func _ready() -> void:
	health = max_health
	hunger = max_hunger


func _process(delta: float) -> void:
	if _dead:
		return
	set_hunger(hunger - hunger_decay_per_second * delta)
	if hunger <= 0.0:
		set_health(health - starving_damage_per_second * delta)


func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0 and not _dead:
		_dead = true
		died.emit()


func set_hunger(value: float) -> void:
	hunger = clampf(value, 0.0, max_hunger)
	hunger_changed.emit(hunger, max_hunger)


func damage(amount: float) -> void:
	set_health(health - amount)


func heal(amount: float) -> void:
	set_health(health + amount)


func eat(amount: float) -> void:
	set_hunger(hunger + amount)
