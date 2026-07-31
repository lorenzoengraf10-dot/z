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
    # nodos de la escena
    nodes = re.findall(r'^\[node name="([^"]+)"(?:[^\]]*?)(?:parent="([^"]*)")?', text, re.M)
    node_paths = set()
    for name, parent in nodes:
        if parent in (None, ""):
            node_paths.add(name)  # raiz
        elif parent == ".":
            node_paths.add(name)
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

# --- 7. autoloads existen ---
proj = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
for name, path in re.findall(r'^(\w+)="\*(res://[^"]+)"', proj, re.M):
    if not os.path.exists(res_to_fs(path)):
        errors.append(f"project.godot: autoload {name} apunta a {path} que no existe")

print("=== ERRORES ===")
print("\n".join(errors) if errors else "(ninguno)")
print("\n=== AVISOS ===")
print("\n".join(warns) if warns else "(ninguno)")
sys.exit(1 if errors else 0)
