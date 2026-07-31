@tool
extends EditorScript
## Rescate para el arte que quedó en JPG.
##
## Se corre **desde el editor de Godot**: abrí este archivo y apretá
## **File → Run** (o Ctrl+Shift+X). Está escrito en GDScript y no en Python
## porque Godot ya sabe leer JPG y escribir PNG, así no hay que instalar nada.
##
## Vive dentro de `game/` a propósito: el editor de Godot solo puede correr
## scripts que estén adentro del proyecto.
##
## Qué hace con cada archivo de ORIGEN:
##   - lo convierte a PNG
##   - le saca el fondo a transparencia (el color que digas en COLOR_FONDO)
##   - avisa si la medida no es la que corresponde
##
## ⚠ ESTO NO RECUPERA LA CALIDAD PERDIDA. El JPG ya inventó colores y ensució
## los bordes; esto solo permite seguir trabajando. Lo correcto es re-exportar
## como PNG desde el `.aseprite` original: si el original existe, usá eso y no
## esta herramienta.
##
## Pasos:
##   1. Poner los archivos en `game/assets/importar/`.
##   2. Si no dibujaron sobre blanco, cambiar COLOR_FONDO.
##   3. File → Run. El resultado sale por el panel Salida.

## De dónde leer.
const ORIGEN := "res://assets/importar"
## A dónde escribir los PNG convertidos.
const DESTINO := "res://assets/importar/convertido"

## El color de fondo que hay que volver transparente. Si dibujaron sobre blanco,
## dejalo así; si usaron el clásico fucsia, poné Color(1, 0, 1).
const COLOR_FONDO := Color(1, 1, 1)
## Cuánta diferencia se le perdona al fondo. El JPG nunca deja el fondo en un
## color exacto (lo ensucia distinto en cada píxel, sobre todo contra los
## bordes), así que hace falta un margen. Si quedan restos, subilo de a poco.
const TOLERANCIA := 0.12

## Medidas válidas del proyecto (ver docs/ARTE_SPEC.md).
const MEDIDAS := [16, 32]

var _medidas_raras: Array[String] = []


func _run() -> void:
	print("--- importar_arte ---")
	print("⚠ El JPG ya perdió calidad y esto no la recupera. Es un rescate:")
	print("  cuando puedan, rehagan el sprite desde el .aseprite original.")
	print("")

	_medidas_raras.clear()

	var dir := DirAccess.open(ORIGEN)
	if dir == null:
		push_error("importar_arte: no existe %s — creá la carpeta y poné ahí los archivos" % ORIGEN)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))

	var convertidos := 0
	var fallados := 0

	dir.list_dir_begin()
	var nombre := dir.get_next()
	while nombre != "":
		if not dir.current_is_dir() and nombre.get_extension().to_lower() in ["jpg", "jpeg", "png", "bmp", "webp"]:
			if _convertir(ORIGEN.path_join(nombre)):
				convertidos += 1
			else:
				fallados += 1
		nombre = dir.get_next()
	dir.list_dir_end()

	print("")
	print("--- %d convertidos, %d que no se pudieron leer ---" % [convertidos, fallados])
	if not _medidas_raras.is_empty():
		print("Ojo, estos no miden 16x16 ni 32x32 y hay que redibujarlos o recortarlos:")
		for archivo in _medidas_raras:
			print("   · %s" % archivo)
	print("")
	print("Los PNG quedaron en %s" % DESTINO)
	print("Moverlos a assets/tiles/ o assets/sprites/<personaje>/ con el nombre que")
	print("pide docs/ARTE_SPEC.md, y después correr:")
	print("    python3 tools/verificadores/check_arte.py")


## Convierte un archivo. Devuelve true si se pudo leer y escribir.
func _convertir(path: String) -> bool:
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("importar_arte: no se pudo leer %s" % path)
		return false

	var ancho := image.get_width()
	var alto := image.get_height()

	image.convert(Image.FORMAT_RGBA8)
	var borrados := _fondo_a_transparente(image)

	var salida: String = DESTINO.path_join(path.get_file().get_basename() + ".png")
	if image.save_png(ProjectSettings.globalize_path(salida)) != OK:
		push_warning("importar_arte: no se pudo escribir %s" % salida)
		return false

	var aviso := ""
	if not (ancho in MEDIDAS and alto in MEDIDAS):
		aviso = "   ⚠ %dx%d" % [ancho, alto]
		_medidas_raras.append("%s (%dx%d)" % [path.get_file(), ancho, alto])

	print("%s  ->  %s   (%d px de fondo a transparente)%s"
			% [path.get_file(), salida.get_file(), borrados, aviso])
	return true


## Pinta de transparente todo lo que se parezca al color de fondo.
func _fondo_a_transparente(image: Image) -> int:
	var borrados := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var px := image.get_pixel(x, y)
			var distancia := absf(px.r - COLOR_FONDO.r) \
					+ absf(px.g - COLOR_FONDO.g) \
					+ absf(px.b - COLOR_FONDO.b)
			if distancia <= TOLERANCIA * 3.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				borrados += 1
	return borrados
