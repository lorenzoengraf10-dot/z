class_name Structure
extends StaticBody2D
## Base de todo lo construido que se puede romper: muros, barricadas y puertas.
##
## Antes las barricadas eran un StaticBody2D pelado, sin vida y sin script:
## nada en el juego las podía romper, y los zombies ni siquiera sabían que
## existían. El resultado era que encerrarse ganaba la partida solo, sin costo.
## Acá vive lo que convierte eso en una decisión: la vida, el daño y el arreglo.
##
## **Reusa hunter_display.gd tal cual está.** Ese nodo (el mismo que les pone la
## barra de vida a zombies y lobos) solo pide tres métodos: alert_level(),
## health_ratio() y show_health_bar(). Implementándolos acá, colgarle el nodo a
## un muro le da la barra sin escribir una línea de dibujo. alert_level()
## devuelve siempre 0 para que no aparezca el ?/! de los enemigos, que no tiene
## sentido en una pared.
##
## ⚠ Las estructuras **no** van al grupo "damageable". Ese es el grupo que barre
## el ataque del jugador (player.gd::_try_attack), así que meterlas ahí haría
## que pelear adentro de tu propia base te tire los muros abajo sin querer. Si
## algún día se decide que el jugador pueda romper a golpes, se agrega ahí y se
## piensa aparte cómo evitar el fuego amigo.

signal destroyed

## Vida máxima. La setea cada escena (Barricade.tscn, Door.tscn, los muros).
@export var max_health := 120.0
## Cuánto dura la barra en pantalla después de que le peguen.
@export var health_bar_seconds := 3.0
## Qué material cuesta repararla. Se usa para cobrar el arreglo en modo
## construcción (ver build_system.gd::_try_repair).
@export var repair_item := "madera"
## Cuánta vida devuelve una unidad de ese material.
@export var repair_per_item := 40.0

var health := 0.0

var _hit_flash := 0.0
var _health_bar_timer := 0.0

## El Polygon2D que parpadea al recibir el golpe. Cada escena puede tener el
## suyo con otro nombre, así que se busca y si no está no pasa nada.
@onready var _flash_target: Node = get_node_or_null("Visual")


func _ready() -> void:
	add_to_group("structure")
	health = max_health


func _process(delta: float) -> void:
	_health_bar_timer = maxf(0.0, _health_bar_timer - delta)
	if _hit_flash <= 0.0:
		return
	_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
	if _flash_target is CanvasItem:
		var visual := _flash_target as CanvasItem
		visual.modulate = Color.WHITE.lerp(Color(3.0, 3.0, 3.0), _hit_flash)


## La llaman los zombies cuando quedan trabados contra esto (ver zombie.gd).
func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_broken():
		return
	health = maxf(0.0, health - amount)
	_hit_flash = 1.0
	_health_bar_timer = health_bar_seconds

	var textos = get_tree().get_first_node_in_group("floating_text")
	if textos != null:
		textos.damage(global_position, amount, false)
	AudioManager.play("golpe")

	if health <= 0.0:
		_on_broken()
		destroyed.emit()


## Devuelve cuánta vida se recuperó de verdad (0 si ya estaba entera). La usa
## build_system.gd para no cobrar material de más.
func repair(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var antes := health
	health = minf(max_health, health + amount)
	var curado := health - antes
	if curado > 0.0:
		_health_bar_timer = health_bar_seconds
	return curado


func is_broken() -> bool:
	return health <= 0.0


func is_damaged() -> bool:
	return health < max_health


## Qué pasa al llegar a cero. Por defecto la estructura desaparece; door.gd lo
## pisa para quedarse abierta en vez de borrarse (el marco tiene que seguir ahí).
func _on_broken() -> void:
	queue_free()


# --- Lo que le pide hunter_display.gd ---
#
# Los tres juntos son el contrato de "cosa con barra de vida". Implementándolos,
# un muro puede usar el mismo nodo que ya usan el zombi y el lobo.

## Siempre 0: una pared no persigue a nadie, así que nunca muestra el ?/!.
func alert_level() -> int:
	return 0


func health_ratio() -> float:
	return 0.0 if max_health <= 0.0 else health / max_health


func show_health_bar() -> bool:
	return _health_bar_timer > 0.0


# --- Guardado ---
#
# No hace falta tocar el sistema de guardado: build_system.gd::placed_cells()
# ya llama a to_dict() en todo lo que lo tenga, y door_system.gd hace lo mismo
# con las puertas.

func to_dict() -> Dictionary:
	return {"vida": health}


func from_dict(data: Dictionary) -> void:
	# Ojo con el valor por defecto: las partidas guardadas ANTES de este lote no
	# tienen "vida". Si el default fuera 0, cargar una partida vieja te dejaría
	# todos los muros rotos. Por eso arranca en max_health.
	health = clampf(float(data.get("vida", max_health)), 0.0, max_health)
