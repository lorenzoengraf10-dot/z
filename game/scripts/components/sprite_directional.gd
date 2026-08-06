class_name SpriteDirectional
extends Node2D
## El puente entre el pixel art y el juego.
##
## Se cuelga del jugador, el zombi, el lobo y el animal. Busca los PNG solo y,
## si están, los usa; si no, deja el `Polygon2D` de placeholder que ya existe.
##
## Eso último es lo importante: los tres van a ir dibujando de a poco, y el
## juego tiene que abrir igual con la mitad del arte sin hacer. Apenas alguien
## deja caer `assets/sprites/jugador/abajo.png`, el jugador deja de ser un
## cuadrado azul. Sin tocar código, sin abrir la escena, sin avisarle a nadie.
##
## Archivos que busca (ver docs/ARTE_SPEC.md):
##     assets/sprites/<nombre>/abajo.png     quieto
##     assets/sprites/<nombre>/abajo_1.png   animado (_1, _2, _3...)
##
## Un sprite quieto es una animación de un cuadro, así que los dos casos usan el
## mismo código: pasar de quieto a animado es agregar el `_2.png` y nada más.

const CARPETA := "res://assets/sprites/%s/%s"
## Cuántos cuadros como mucho busca por dirección (corta antes si falta uno).
const MAX_FRAMES := 24

## Nombre de la carpeta dentro de assets/sprites/.
@export var sprite_name := ""
## Si sprite_name no tiene ningún PNG todavía, prueba con esta carpeta antes
## de caer al placeholder de forma. La usan las variantes que van a tener su
## propio dibujo pero mientras tanto muestran el del personaje base (ver
## SPRITE_OVERRIDE en horde_spawner.gd). El día que aparezca el PNG propio,
## este campo deja de hacer efecto solo, sin tocar nada más.
@export var sprite_name_fallback := ""
## Cuadros por segundo de las animaciones.
@export var fps := 8.0
## El personaje se dibuja con los pies en la fila 28 de un cuadro de 32, y el
## juego apoya esa fila sobre la celda. Por eso el sprite va corrido 12 px para
## arriba: 28 (los pies) - 16 (el centro del cuadro) = 12.
##
## Era 8 (fila 24) hasta que llegó el primer dibujo de verdad: lo hicieron con
## los pies casi al borde de abajo. Como todavía no había ningún otro arte, se
## cambió la regla en vez del dibujo (ver docs/ARTE_SPEC.md).
@export var foot_offset := 12.0
## Los nodos que hacen de placeholder mientras no haya sprite. Son varios
## porque el jugador, por ejemplo, tiene el cuerpo y la flecha de dirección
## como dos Polygon2D separados.
@export var placeholder_paths: Array[NodePath] = [NodePath("../Visual")]

var _sprite: AnimatedSprite2D
var _placeholders: Array[Node2D] = []
var _has_art := false
var _current := ""
## Cuál de las dos carpetas terminó usando: sprite_name o sprite_name_fallback.
var _loaded_sprite_name := ""


func _ready() -> void:
	for path in placeholder_paths:
		var node := get_node_or_null(path) as Node2D
		if node != null:
			_placeholders.append(node)

	var frames := _load_frames()
	if frames == null:
		# Sin arte todavía: que siga el placeholder, como si este nodo no existiera.
		return

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.offset = Vector2(0, -foot_offset)
	# Pixel art: nítido, nunca suavizado.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_has_art = true
	for node in _placeholders:
		node.visible = false
	set_facing(Vector2.DOWN)


## True si este personaje ya tiene su pixel art puesto. Lo usan zombie.gd y
## wolf.gd para saber si todavía tienen que rotar el placeholder o no (un sprite
## de pixel art NO se rota: se ve borroso y tiembla).
func has_art() -> bool:
	return _has_art


## A qué nodo hay que pintarle el parpadeo de "me pegaron": al sprite si ya
## está el arte, o al placeholder mientras no esté. Así el feedback de golpes
## funciona igual antes y después de que entre el pixel art.
##
## Devuelve Node2D porque tanto este nodo como los placeholders lo son, así
## quien la llame puede usar `:=` sin problema.
func flash_target() -> Node2D:
	if _has_art:
		return self
	return _placeholders[0] if not _placeholders.is_empty() else self


## Cuál carpeta terminó usando: sprite_name (el dibujo propio) o
## sprite_name_fallback (el de respaldo, mientras no exista el propio). Vacío
## si no se pudo cargar nada. La usa zombie.gd para no tintar por encima de un
## dibujo que ya es propio y distinto.
func active_sprite_name() -> String:
	return _loaded_sprite_name


## Elige el cuadro según hacia dónde mira el personaje.
##
## Con 3 dibujos alcanza: la izquierda sale de espejar `lado`. Pero si además
## existe un `izquierda` dibujado aparte, se usa ese y no el espejo — el zombi
## chiquito tiene uno, y no es el espejo del derecho (difieren en un 15% de los
## píxeles), así que espejarlo tiraría ese trabajo a la basura.
##
## Quien tenga solo los 3 de siempre no se entera de este agregado.
func set_facing(direction: Vector2) -> void:
	if not _has_art or direction == Vector2.ZERO:
		return

	var wanted := ""
	var espejado := false
	# Gana el eje que más pesa: mirando en diagonal, manda el horizontal, que es
	# el que mejor se lee en un top-down.
	if absf(direction.x) >= absf(direction.y):
		if direction.x < 0.0 and _sprite.sprite_frames.has_animation("izquierda"):
			wanted = "izquierda"     # dibujo propio: no se espeja
		else:
			wanted = "lado"
			espejado = direction.x < 0.0
	elif direction.y < 0.0:
		wanted = "arriba"
	else:
		wanted = "abajo"

	# ⚠ El espejado se aplica DESPUÉS de comprobar que la animación exista.
	# Si no, un personaje al que todavía le falta "lado" seguía mostrando la
	# vista de frente pero espejada al caminar para la izquierda, y con brazos
	# asimétricos (el zombi pesado) eso se ve.
	if not _sprite.sprite_frames.has_animation(wanted):
		return
	_sprite.flip_h = espejado
	if wanted == _current:
		return
	_current = wanted
	_sprite.play(wanted)


# --- Carga de archivos ---

## Arma el SpriteFrames con lo que encuentre. Devuelve null si no hay nada.
## (Se puede tipar el retorno igual: un tipo de objeto admite null.)
##
## Ojo: se busca con ResourceLoader.exists(), NO listando la carpeta. Listar
## carpetas de res:// se comporta distinto en el juego exportado que en el
## editor (ahí aparecen los .import en vez de los .png), y este código tiene que
## andar en los dos lados.
func _load_frames() -> SpriteFrames:
	if sprite_name == "":
		return null

	var frames := _load_frames_from(sprite_name)
	if frames != null:
		_loaded_sprite_name = sprite_name
		return frames

	if sprite_name_fallback != "":
		frames = _load_frames_from(sprite_name_fallback)
		if frames != null:
			_loaded_sprite_name = sprite_name_fallback
			return frames

	return null


## Arma el SpriteFrames buscando en assets/sprites/<nombre>/. Devuelve null si
## esa carpeta no tiene nada, así _load_frames() puede probar con la siguiente.
func _load_frames_from(nombre: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	# SpriteFrames viene con una animación "default" que no usamos.
	frames.remove_animation("default")

	var found := false
	# "izquierda" es opcional: si no está, set_facing() espeja "lado" como siempre.
	for direction in ["abajo", "arriba", "lado", "izquierda"]:
		var textures := _load_direction(nombre, direction)
		if textures.is_empty():
			continue
		found = true
		frames.add_animation(direction)
		frames.set_animation_speed(direction, fps)
		frames.set_animation_loop(direction, true)
		for texture in textures:
			frames.add_frame(direction, texture)

	return frames if found else null


## Los cuadros de una dirección: primero busca los numerados (animación) y si no
## hay, el suelto (quieto).
func _load_direction(nombre: String, direction: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	# Animado: abajo_1.png, abajo_2.png... hasta que falte uno.
	for i in range(1, MAX_FRAMES + 1):
		var path := CARPETA % [nombre, "%s_%d.png" % [direction, i]]
		if not ResourceLoader.exists(path):
			break
		var texture := load(path) as Texture2D
		if texture == null:
			break
		textures.append(texture)

	if not textures.is_empty():
		return textures

	# Quieto: un solo archivo, que es una animación de un cuadro.
	var single := CARPETA % [nombre, direction + ".png"]
	if ResourceLoader.exists(single):
		var texture := load(single) as Texture2D
		if texture != null:
			textures.append(texture)

	return textures
