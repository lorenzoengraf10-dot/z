#!/usr/bin/env python3
"""Chequeo estatico del proyecto Godot: rutas res://, load_steps, nodos $ y JSON."""
import os, re, json, sys

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

ROOT = GAME
errors, warns = [], []

def res_to_fs(p):
    return os.path.join(ROOT, p[len("res://"):])

# --- 1. Todas las rutas res:// existen ---
all_files = []
for dirpath, _, names in os.walk(ROOT):
    for n in names:
        all_files.append(os.path.join(dirpath, n))

for f in all_files:
    if not f.endswith((".tscn", ".gd", ".godot")):
        continue
    try:
        text = open(f, encoding="utf-8").read()
    except Exception as e:
        errors.append(f"no se pudo leer {f}: {e}"); continue
    for m in re.finditer(r'res://[A-Za-z0-9_./-]+', text):
        path = m.group(0)
        if not os.path.exists(res_to_fs(path)):
            errors.append(f"{os.path.relpath(f,ROOT)}: ruta inexistente {path}")

# --- 2. load_steps == cantidad de recursos + 1 ---
for f in all_files:
    if not f.endswith(".tscn"):
        continue
    text = open(f, encoding="utf-8").read()
    m = re.search(r'load_steps=(\d+)', text)
    declared = int(m.group(1)) if m else None
    ext = len(re.findall(r'^\[ext_resource ', text, re.M))
    sub = len(re.findall(r'^\[sub_resource ', text, re.M))
    expected = ext + sub + 1
    rel = os.path.relpath(f, ROOT)
    if declared is None:
        if ext + sub > 0:
            errors.append(f"{rel}: falta load_steps (esperado {expected})")
    elif declared != expected:
        errors.append(f"{rel}: load_steps={declared} pero deberia ser {expected} (ext={ext}, sub={sub})")

# --- 3. ids de ExtResource usados existen ---
for f in all_files:
    if not f.endswith(".tscn"):
        continue
    text = open(f, encoding="utf-8").read()
    declared_ids = set(re.findall(r'^\[ext_resource[^\]]*id="([^"]+)"', text, re.M))
    used_ids = set(re.findall(r'ExtResource\("([^"]+)"\)', text))
    missing = used_ids - declared_ids
    if missing:
        errors.append(f"{os.path.relpath(f,ROOT)}: ExtResource sin declarar: {sorted(missing)}")
    declared_sub = set(re.findall(r'^\[sub_resource[^\]]*id="([^"]+)"', text, re.M))
    used_sub = set(re.findall(r'SubResource\("([^"]+)"\)', text))
    missing_sub = used_sub - declared_sub
    if missing_sub:
        errors.append(f"{os.path.relpath(f,ROOT)}: SubResource sin declarar: {sorted(missing_sub)}")

# --- 4. Nodos referenciados con $ existen en la escena que usa ese script ---
# mapa script -> escena
script_of_scene = {}
for f in all_files:
    if not f.endswith(".tscn"):
        continue
    text = open(f, encoding="utf-8").read()
    ids = dict(re.findall(r'^\[ext_resource type="Script" path="([^"]+)" id="([^"]+)"', text, re.M))
    # Nodos de la escena.
    #
    # Ojo con como se parsea: antes era un solo regex con `parent=` opcional
    # DESPUES de un comodin perezoso, y asi casi nunca capturaba el parent (el
    # motor prefiere el match mas corto y el grupo es opcional). Con nodos de un
    # solo nivel no se notaba —"Panel" y "./Panel" terminan dando la misma
    # entrada— pero cualquier ruta anidada tipo $Visual/Panel daba un falso
    # error de "ese nodo no esta en la escena". Se separa en dos busquedas para
    # que ademas no dependa del orden de los atributos.
    node_paths = set()
    for m in re.finditer(r'^\[node ([^\]]*)\]', text, re.M):
        attrs = m.group(1)
        name_m = re.search(r'name="([^"]+)"', attrs)
        if name_m is None:
            continue
        name = name_m.group(1)
        parent_m = re.search(r'parent="([^"]*)"', attrs)
        parent = parent_m.group(1) if parent_m else ""
        if parent in ("", "."):
            node_paths.add(name)      # raiz, o hijo directo de la raiz
        else:
            node_paths.add(f"{parent}/{name}")
    for path, _id in ids.items():
        script_of_scene.setdefault(path, []).append((os.path.relpath(f, ROOT), node_paths))

for script_res, entries in script_of_scene.items():
    fs = res_to_fs(script_res)
    if not os.path.exists(fs):
        continue
    src = open(fs, encoding="utf-8").read()
    dollars = set(re.findall(r'(?<![\w.])\$([A-Za-z_][A-Za-z0-9_/]*)', src))
    # Solo llamadas sobre uno mismo: `get_node("X")`, no `otro.get_node("X")`.
    getnodes = set(re.findall(r'(?<![\w.])get_node(?:_or_null)?\("([^"]+)"\)', src))
    wanted = {d for d in dollars} | {g for g in getnodes if not g.startswith("/")}
    for scene_rel, node_paths in entries:
        for w in wanted:
            if w not in node_paths:
                errors.append(f"{scene_rel}: el script {script_res} usa ${w} pero ese nodo no esta en la escena")

# --- 5. JSON valido ---
for f in all_files:
    if f.endswith(".json"):
        try:
            json.load(open(f, encoding="utf-8"))
        except Exception as e:
            errors.append(f"{os.path.relpath(f,ROOT)}: JSON invalido: {e}")

# --- 6. world.gd: add_source() ANTES de add_collision_polygon() ---
#
# La trampa exacta que dejo todo el mapa sin colisiones durante varios dias: el
# TileData copia las capas de fisica del TileSet recien cuando se entera de a
# que TileSet pertenece, y eso pasa adentro de add_source(). Si la colision se
# crea antes, add_collision_polygon(0) se va por un ERR_FAIL_INDEX y NO CREA
# NADA, sin romper el juego: abre igual y se atraviesan las paredes.
world_gd = os.path.join(ROOT, "scripts", "world.gd")
if os.path.exists(world_gd):
    raw = open(world_gd, encoding="utf-8").read()
    # Ojo: hay que sacar los comentarios primero. El comentario que explica este
    # mismo bug nombra las dos funciones, y sin limpiarlo el verificador se
    # miraba a si mismo y daba OK siempre.
    src = "\n".join(l.split("#")[0] for l in raw.split("\n"))
    add_source = src.find("add_source(")
    add_collision = src.find("add_collision_polygon(")
    if add_collision != -1:
        if add_source == -1:
            errors.append("world.gd: hay add_collision_polygon() pero ningun add_source(); "
                          "los tiles van a quedar sin colision")
        elif add_source > add_collision:
            linea = src[:add_collision].count("\n") + 1
            errors.append(f"world.gd:{linea}: add_collision_polygon() esta ANTES de "
                          "add_source(). El tile todavia no tiene capas de fisica, la "
                          "llamada falla en silencio y NINGUN tile del mapa colisiona. "
                          "Mover ts.add_source() arriba del for que crea los tiles.")

# --- 7. world.gd: todo lo que se pega con blit_rect() pasa por la conversion ---
#
# La otra trampa que fallo en silencio: Image.blit_rect() EXIGE que las dos
# imagenes tengan el mismo formato (ERR_FAIL_COND_MSG "Source image format is
# different"). Si no coinciden no copia nada, no tira excepcion, y el atlas
# entero queda transparente: el mapa se ve como un color plano y el juego abre
# igual. El atlas se crea FORMAT_RGBA8 y el placeholder venia RGB8.
#
# La regla: el primer argumento de cada blit_rect() tiene que ser una variable
# que haya salido de _listo_para_pegar(), la funcion que hace la conversion.
CONVERSOR = "_listo_para_pegar"
if os.path.exists(world_gd):
    # Mismo cuidado que en la regla 6: sin sacar los comentarios, el comentario
    # que explica este bug nombra blit_rect() y ensucia la busqueda.
    if CONVERSOR not in src:
        errors.append(f"world.gd: no existe {CONVERSOR}(); es la funcion que pasa las "
                      "imagenes a FORMAT_RGBA8 antes de pegarlas en el atlas")
    elif "FORMAT_RGBA8" not in src[src.find(f"func {CONVERSOR}"):]:
        errors.append(f"world.gd: {CONVERSOR}() ya no convierte a FORMAT_RGBA8. Sin esa "
                      "conversion blit_rect() no copia nada y el mapa entero queda "
                      "transparente (se ve un color plano).")

    # Sirven tanto "var x := _listo_para_pegar(...)" como "x = _listo_para_pegar(...)"
    # sobre una variable ya declarada arriba.
    convertidas = set(re.findall(rf"^\s*(?:var\s+)?(\w+)[^=\n]*=\s*{CONVERSOR}\(", src, re.M))
    for m in re.finditer(r"\.blit_rect\(\s*([A-Za-z_]\w*)", src):
        origen = m.group(1)
        if origen not in convertidas:
            linea = src[:m.start()].count("\n") + 1
            errors.append(f"world.gd:{linea}: blit_rect() pega '{origen}', que no salio de "
                          f"{CONVERSOR}(). Si el formato no coincide con el del atlas, la "
                          "copia falla EN SILENCIO y el tile queda transparente.")

# --- 8. Zombie.tscn: el VisionRay sigue mirando la capa de los arboles ---
#
# world.gd le da al arbol su propia capa de fisica (bit 16): no frena el paso,
# pero sigue tapando la vista. Si alguien le saca el 16 a la mask del
# VisionRay (por ejemplo, "limpiando" el numero porque no entiende de donde
# sale), el zombie te ve a traves de los arboles y el sigilo se rompe SIN que
# se note jugando: el arbol se sigue dibujando igual, y hay que meterse atras
# de uno para descubrir que no te esconde.
zombie_tscn = os.path.join(ROOT, "scenes", "Zombie.tscn")
if os.path.exists(zombie_tscn):
    src = open(zombie_tscn, encoding="utf-8").read()
    bloque = re.search(r'\[node name="VisionRay".*?(?=\n\[node|\Z)', src, re.S)
    if bloque is None:
        errors.append("Zombie.tscn: no encontre el nodo VisionRay")
    else:
        m = re.search(r'collision_mask\s*=\s*(\d+)', bloque.group(0))
        mask = int(m.group(1)) if m else 1  # sin la linea, Godot usa 1 por default
        if not (mask & 16):
            errors.append(f"Zombie.tscn: VisionRay.collision_mask={mask} no incluye la capa "
                          "16 (arboles) — el zombie va a ver a traves de los arboles. "
                          "Tiene que ser un numero con el bit 16 prendido (ej. 17 = 1|16).")

# --- 9. todo lo que camina por el mapa respeta speed_at() ---
#
# world.gd tiene una tabla SPEED que frena por tile (agua 0.45, arbol 0.55),
# pero frenar es cosa de cada script que se mueve: hay que multiplicar por
# world.speed_at() a mano. Durante un tiempo lo hacia SOLO player.gd, y eso
# daba vuelta el diseño sin que se note leyendo el codigo: vos cruzabas el
# monte al 55% y el zombie que te perseguia iba al 100%, asi que meterse entre
# los arboles escapando (que es PARA LO QUE ESTAN) era suicidio. Lo mismo con
# el agua. No se ve en pantalla, no lo marca ningun otro verificador, y solo
# aparece si alguien lo cronometra jugando.
CAMINANTES = ["player.gd", "zombie.gd", "wolf.gd", "animal.gd"]
for nombre in CAMINANTES:
    ruta = os.path.join(ROOT, "scripts", nombre)
    if not os.path.exists(ruta):
        errors.append(f"check_project: no encontre scripts/{nombre} (se renombro?); "
                      "esta en la lista de los que tienen que frenar por terreno")
        continue
    src = open(ruta, encoding="utf-8").read()
    # Sin comentarios: este mismo bloque nombra speed_at() y no queremos que un
    # comentario alcance para dar OK (misma trampa que las reglas 6 y 7).
    src = "\n".join(l.split("#")[0] for l in src.split("\n"))
    if "speed_at(" not in src:
        errors.append(f"scripts/{nombre}: no llama a speed_at(), asi que el terreno no lo "
                      "frena. Si solo el jugador frena en el agua/monte, escaparse por ahi "
                      "pasa a ser peor que no hacerlo. Multiplicar la velocidad por "
                      "world.speed_at(global_position) antes de move_and_slide().")

# --- 10. ningun Control del HUD se come el clic del ataque ---
#
# Tercer intento de este mismo bug en el proyecto. Se apunta con el mouse y se
# ataca con clic izquierdo, y el ataque se resuelve en player.gd::
# _unhandled_input(). Cualquier Control del HUD que reciba el mouse hace que el
# viewport marque el evento como atendido, y el clic NUNCA llega hasta ahi: con
# el cursor sobre el HUD te quedas sin poder pegar.
#
# La trampa fina: MOUSE_FILTER_PASS parece seguro por el nombre, pero NO lo es.
# Al buscar quien recibe el mouse Godot saltea solo los IGNORE; uno con PASS
# igual queda como gui.mouse_focus. PASS deja pasar el evento a los Control de
# arriba, no al juego. La ultima vez entro por querer habilitar tooltips (que
# no andan con IGNORE, justamente porque el Control no recibe el mouse).
#
# Los Button son la excepcion: estan para clickearlos.
hud_gd = os.path.join(ROOT, "scripts", "hud.gd")
if os.path.exists(hud_gd):
    raw = open(hud_gd, encoding="utf-8").read()
    # Sin comentarios: este archivo explica el bug nombrando las constantes, y
    # sin limpiarlos el verificador se mira a si mismo (misma trampa que 6 y 7).
    src = "\n".join(l.split("#")[0] for l in raw.split("\n"))
    for m in re.finditer(r'MOUSE_FILTER_(PASS|STOP)', src):
        linea = src[:m.start()].count("\n") + 1
        errors.append(f"hud.gd:{linea}: MOUSE_FILTER_{m.group(1)} en el HUD se come el clic "
                      "izquierdo y te deja sin atacar mientras el cursor este encima. "
                      "Va MOUSE_FILTER_IGNORE (usar _passthrough()). PASS tampoco sirve: "
                      "Godot solo saltea los IGNORE al repartir el mouse.")
    # tooltip_text es la puerta de entrada: no hace nada con IGNORE, asi que
    # quien lo pone termina cambiando el filtro para que "funcione".
    for m in re.finditer(r'\.tooltip_text\s*=', src):
        linea = src[:m.start()].count("\n") + 1
        errors.append(f"hud.gd:{linea}: tooltip_text no anda con MOUSE_FILTER_IGNORE, y "
                      "cambiar el filtro para que ande rompe el ataque. Si hace falta un "
                      "tooltip, dibujarlo a mano con un hit-test en _process().")

# --- 11. las escenas construibles con vida tienen su script ---
#
# Un muro sin script sigue siendo un StaticBody2D perfectamente valido: frena
# igual, se ve igual, el juego abre igual. Lo unico que NO hace es tener vida,
# asi que queda indestructible — que es justo el bug que este sistema vino a
# arreglar (antes Barricade.tscn era exactamente eso). No hay forma de darse
# cuenta jugando salvo pegarle a una pared un minuto entero y ver que no pasa
# nada.
#
# La lista sale de BUILDABLES: se comprueba que cada escena de un muro tenga
# structure.gd (o un script que herede de el, como door.gd).
ESTRUCTURAS_CON_VIDA = ["Barricade.tscn", "WallStone.tscn", "WallMetal.tscn", "Door.tscn"]
for nombre in ESTRUCTURAS_CON_VIDA:
    ruta = os.path.join(ROOT, "scenes", nombre)
    if not os.path.exists(ruta):
        errors.append(f"scenes/{nombre}: no existe (se renombro?); esta en la lista de "
                      "estructuras que tienen que poder romperse")
        continue
    src = open(ruta, encoding="utf-8").read()
    if not re.search(r'\[ext_resource type="Script"[^\]]*path="res://scripts/(structure|door)\.gd"', src):
        errors.append(f"scenes/{nombre}: no tiene structure.gd (ni un script que lo herede). "
                      "Sin script no tiene vida: queda INDESTRUCTIBLE y los zombies no la "
                      "pueden romper, sin ningun error visible.")
    elif "max_health" not in src:
        errors.append(f"scenes/{nombre}: tiene el script pero no setea max_health, "
                      "asi que usa el default en vez de su propia resistencia.")

# --- 12. nadie muerde a traves de una pared ---
#
# El ataque de zombies y lobos NO chequea linea de vista: solo mide distancia
# (ver zombie.gd::_do_chase, que pasa a ATTACK con distance_to <= attack_range).
# Que hoy no puedan morderte a traves de una puerta cerrada es pura geometria:
#
#   pared/puerta 16 de ancho -> 8 del centro al borde
#   + medio zombie (colision 12x12)  -> 6
#   + medio jugador (colision 12x12) -> 6
#   = 20 de cada lado, 28 entre los dos centros con la pared en el medio
#
# Con attack_range = 20 quedan 8 de margen. Si alguien lo sube a 28 o mas, los
# zombies empiezan a morderte a traves de las paredes y **toda la defensa del
# juego deja de existir**, sin un solo error en pantalla: la puerta se sigue
# viendo cerrada. Es exactamente el tipo de cosa que hay que atrapar aca.
MARGEN_PARED = 28  # 16 (pared) / 2 + 6 (medio zombie) + 6 (medio jugador) + 8
for nombre in ["zombie.gd", "wolf.gd"]:
    ruta = os.path.join(ROOT, "scripts", nombre)
    if not os.path.exists(ruta):
        continue
    src = "\n".join(l.split("#")[0] for l in open(ruta, encoding="utf-8").read().split("\n"))
    m = re.search(r'@export var attack_range\s*:=\s*([\d.]+)', src)
    if m is None:
        errors.append(f"scripts/{nombre}: no encontre attack_range; es el numero que decide "
                      "si pueden morderte atravesando una pared")
        continue
    alcance = float(m.group(1))
    if alcance >= MARGEN_PARED:
        errors.append(f"scripts/{nombre}: attack_range={alcance:g} llega a {MARGEN_PARED} o mas, "
                      "asi que puede morder al jugador A TRAVES de una pared o una puerta cerrada "
                      "(el ataque solo mide distancia, no chequea linea de vista). Bajarlo, o "
                      "agregarle un chequeo de linea de vista al ataque.")

# --- 13. nadie detecta al jugador atravesando paredes ---
#
# El lobo se escribio copiando al zombi pero SIN el chequeo de linea de vista,
# y durante mucho tiempo fue el unico bicho que te veia a traves de las paredes.
# Jugando no se distingue de "me olio": parece que la IA es buena, no que esta
# rota. Lo mismo con el oido, que hasta este lote ignoraba las paredes en los
# dos.
#
# La regla: todo script que detecte al jugador tiene que nombrar
# _has_line_of_sight (para la vista) y muffle_through_walls (para el oido).
CAZADORES = ["zombie.gd", "wolf.gd"]
for nombre in CAZADORES:
    ruta = os.path.join(ROOT, "scripts", nombre)
    if not os.path.exists(ruta):
        errors.append(f"scripts/{nombre}: no existe (se renombro?); esta en la lista de "
                      "los que detectan al jugador")
        continue
    src = "\n".join(l.split("#")[0] for l in open(ruta, encoding="utf-8").read().split("\n"))
    if "_detect_player" not in src:
        continue
    if "_has_line_of_sight" not in src:
        errors.append(f"scripts/{nombre}: detecta al jugador pero no usa _has_line_of_sight(), "
                      "asi que TE VE A TRAVES DE LAS PAREDES. Jugando parece que te olfateo, "
                      "no que esta roto: meterse en una casa deja de servir.")
    if "muffle_through_walls" not in src:
        errors.append(f"scripts/{nombre}: no aplica muffle_through_walls al oido, asi que "
                      "TE ESCUCHA A TRAVES DE LAS PAREDES y esconderse en una casa no sirve.")

# --- 14. autoloads existen ---
proj = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
for name, path in re.findall(r'^(\w+)="\*(res://[^"]+)"', proj, re.M):
    if not os.path.exists(res_to_fs(path)):
        errors.append(f"project.godot: autoload {name} apunta a {path} que no existe")

print("=== ERRORES ===")
print("\n".join(errors) if errors else "(ninguno)")
print("\n=== AVISOS ===")
print("\n".join(warns) if warns else "(ninguno)")
sys.exit(1 if errors else 0)
