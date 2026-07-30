extends StaticBody2D
## Fogata. Se construye con madera y arranca **apagada**: hay que prenderla con
## el minijuego de fricción (ver ui/fire_minigame.gd).
##
## Prendida: ilumina de noche, te abriga (sube la temperatura si estás cerca) y
## habilita las recetas de cocina. Consume combustible con el tiempo; se le echa
## más madera con E para que no se apague.

signal lit_changed(lit: bool)
signal fuel_changed(fuel: float)

## Cuántos segundos de fuego da cada madera.
@export var seconds_per_wood := 45.0
@export var max_fuel := 300.0
## Radio (px) en el que la fogata te abriga y sirve para cocinar.
@export var heat_radius := 110.0
## Temperatura corporal objetivo si estás justo al lado del fuego.
@export var heat_temperature := 90.0
@export var light_energy := 1.4
@export var light_scale := 1.6

var lit := false
var fuel := 0.0

var _flicker := 0.0

@onready var _flame: Polygon2D = $Flame
@onready var _light: PointLight2D = $Light


func _ready() -> void:
	add_to_group("campfire")
	add_to_group("heat_source")
	_light.texture = _make_light_texture()
	_light.texture_scale = light_scale
	_light.color = Color(1.0, 0.72, 0.38)
	_apply_lit_visuals()


func _process(delta: float) -> void:
	if not lit:
		return

	fuel = maxf(0.0, fuel - delta)
	fuel_changed.emit(fuel)
	if fuel <= 0.0:
		extinguish()
		return

	# Parpadeo suave de la llama y la luz, para que no se vea estática.
	_flicker += delta * 9.0
	var wobble := 1.0 + sin(_flicker) * 0.08 + sin(_flicker * 2.3) * 0.04
	_flame.scale = Vector2(wobble, wobble)
	_light.energy = light_energy * wobble


## La llama el minijuego cuando lográs prender el fuego.
func light_fire(initial_wood: int = 1) -> void:
	fuel = minf(max_fuel, fuel + seconds_per_wood * maxi(initial_wood, 1))
	lit = true
	_apply_lit_visuals()
	lit_changed.emit(true)
	fuel_changed.emit(fuel)
	AudioManager.play("fuego_prender")


func extinguish() -> void:
	if not lit:
		return
	lit = false
	fuel = 0.0
	_apply_lit_visuals()
	lit_changed.emit(false)


func add_fuel(wood: int) -> void:
	fuel = minf(max_fuel, fuel + seconds_per_wood * wood)
	fuel_changed.emit(fuel)


func is_lit() -> bool:
	return lit


func fuel_ratio() -> float:
	return clampf(fuel / max_fuel, 0.0, 1.0)


## Temperatura que aporta en una posición dada (0 si estás lejos o está apagada).
## La usa day_night.gd para calcular la temperatura ambiente del jugador.
func heat_at(world_position: Vector2) -> float:
	if not lit:
		return 0.0
	var dist := global_position.distance_to(world_position)
	if dist > heat_radius:
		return 0.0
	return lerpf(heat_temperature, 0.0, dist / heat_radius)


## ¿Sirve para cocinar desde esta posición?
func can_cook_from(world_position: Vector2) -> bool:
	return lit and global_position.distance_to(world_position) <= heat_radius


func _apply_lit_visuals() -> void:
	_flame.visible = lit
	_light.enabled = lit
	if not lit:
		_flame.scale = Vector2.ONE
		_light.energy = 0.0


## Textura radial generada por código, así no dependemos de ningún asset.
func _make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


# --- Guardado ---

func to_dict() -> Dictionary:
	return {"lit": lit, "fuel": fuel}


func from_dict(data: Dictionary) -> void:
	fuel = float(data.get("fuel", 0.0))
	lit = bool(data.get("lit", false)) and fuel > 0.0
	_apply_lit_visuals()
	lit_changed.emit(lit)
	fuel_changed.emit(fuel)
