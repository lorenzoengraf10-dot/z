#!/usr/bin/env python3
"""Busca accesos a miembros propios del proyecto sobre variables tipadas como
Node/Node2D/etc. En GDScript eso es error de compilacion, y no lo podemos ver
sin abrir Godot."""
import os, re, sys

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

ROOT = os.path.join(GAME, "scripts")

# 1. Miembros "propios" definidos en nuestros scripts (no built-ins de Godot).
custom = set()
files = []
for dp, _, names in os.walk(ROOT):
    for n in names:
        if n.endswith(".gd"):
            files.append(os.path.join(dp, n))

for f in files:
    src = open(f, encoding="utf-8").read()
    for m in re.finditer(r'^\s*func\s+([a-zA-Z_]\w*)\s*\(', src, re.M):
        name = m.group(1)
        if not name.startswith("_"):
            custom.add(name)
    for m in re.finditer(r'^\s*(?:@export\s+)?var\s+([a-zA-Z_]\w*)', src, re.M):
        name = m.group(1)
        if not name.startswith("_"):
            custom.add(name)

# Sacamos nombres que tambien existen en Godot para no dar falsos positivos.
GODOT_BUILTINS = {
    "add", "remove", "position", "visible", "color", "items", "state", "health",
    "layer", "size", "text", "value", "polygon", "max_value", "velocity",
}
custom -= GODOT_BUILTINS

# Miembros que existen en Node2D pero NO en Node. Pedirlos sobre algo tipado
# como Node (lo que devuelven get_parent/get_children/get_nodes_in_group) es
# error; sobre un Node2D son validos. Por eso van aparte de `custom`.
NODE2D_ONLY = {
    "to_local", "to_global", "look_at", "global_position", "global_rotation",
    "global_scale", "rotation", "transform", "global_transform",
    "move_local_x", "move_local_y", "translate",
}

# 2. Variables tipadas como nodo. Distinguimos dos grupos, porque un Node2D SI
#    tiene global_position y un Node pelado no:
#      plain_vars -> tipadas Node/Control/CanvasLayer (o vienen de get_parent()
#                    y amigos): les faltan tanto los miembros propios como los
#                    de Node2D.
#      spatial_vars -> tipadas Node2D y derivados: solo les faltan los propios.
PLAIN = r'(?:Node|CanvasLayer|Control)'
SPATIAL = r'(?:Node2D|CharacterBody2D|Area2D|StaticBody2D|RayCast2D|Polygon2D)'
errors = []

for f in files:
    src = open(f, encoding="utf-8").read()
    rel = os.path.relpath(f, ROOT)

    plain_vars = set()
    spatial_vars = set()

    # Declaraciones explicitas: `var x: Tipo` o `param: Tipo`
    for m in re.finditer(r'\b([a-zA-Z_]\w*)\s*:\s*' + SPATIAL + r'\b', src):
        spatial_vars.add(m.group(1))
    for m in re.finditer(r'\b([a-zA-Z_]\w*)\s*:\s*' + PLAIN + r'\b(?!2D)', src):
        plain_vars.add(m.group(1))

    # Vars que heredan el tipo con `:=` de una funcion que declara el retorno
    for group, pattern in ((plain_vars, PLAIN + r'\b(?!2D)'), (spatial_vars, SPATIAL)):
        fns = set(re.findall(r'^\s*func\s+([a-zA-Z_]\w*)\s*\([^)]*\)\s*->\s*' + pattern, src, re.M))
        for fn in fns:
            for m in re.finditer(r'\bvar\s+([a-zA-Z_]\w*)\s*:=\s*' + re.escape(fn) + r'\s*\(', src):
                group.add(m.group(1))

    # get_parent / get_node / get_first_node_in_group devuelven Node pelado
    for m in re.finditer(r'\bvar\s+([a-zA-Z_]\w*)\s*:=\s*(?:get_tree\(\)\.)?get_(?:first_node_in_group|node|parent)\s*\(', src):
        plain_vars.add(m.group(1))

    spatial_vars -= plain_vars  # si aparece tipada de las dos formas, gana la estricta

    for var in sorted(plain_vars):
        for m in re.finditer(re.escape(var) + r'\.([a-zA-Z_]\w*)', src):
            member = m.group(1)
            if member in custom or member in NODE2D_ONLY:
                line = src[:m.start()].count("\n") + 1
                errors.append(f"{rel}:{line}: '{var}' esta tipado como Node y se usa .{member} "
                              f"(Node no lo tiene) -> dejarlo sin tipo")

    for var in sorted(spatial_vars):
        for m in re.finditer(re.escape(var) + r'\.([a-zA-Z_]\w*)', src):
            member = m.group(1)
            if member in custom:
                line = src[:m.start()].count("\n") + 1
                errors.append(f"{rel}:{line}: '{var}' esta tipado como Node2D y se usa .{member} "
                              f"(miembro propio del proyecto) -> dejarlo sin tipo")

# 3. `var X := f()` donde f() NO declara tipo de retorno -> no se puede inferir.
#    (Es el error "Cannot infer the type of X because the value doesn't have a
#    set type" que tira Godot.)
for f in files:
    src = open(f, encoding="utf-8").read()
    rel = os.path.relpath(f, ROOT)

    untyped_funcs = set()
    for m in re.finditer(r'^\s*func\s+([a-zA-Z_]\w*)\s*\([^)]*\)\s*:', src, re.M):
        untyped_funcs.add(m.group(1))   # sin "->" = devuelve Variant

    for fn in untyped_funcs:
        for m in re.finditer(r'\bvar\s+([a-zA-Z_]\w*)\s*:=\s*' + re.escape(fn) + r'\s*\(', src):
            line = src[:m.start()].count("\n") + 1
            errors.append(f"{rel}:{line}: 'var {m.group(1)} := {fn}()' no puede inferir tipo "
                          f"({fn}() no declara tipo de retorno) -> usar '='")

# 4. `var X := algo.instantiate()` infiere Node; si despues se accede a un
#    miembro propio del proyecto, es error de miembro inexistente.
for f in files:
    src = open(f, encoding="utf-8").read()
    rel = os.path.relpath(f, ROOT)
    for m in re.finditer(r'\bvar\s+([a-zA-Z_]\w*)\s*:=\s*[\w.]*instantiate\s*\(', src):
        var = m.group(1)
        line = src[:m.start()].count("\n") + 1
        for m2 in re.finditer(re.escape(var) + r'\.([a-zA-Z_]\w*)', src):
            member = m2.group(1)
            if member in custom or member in ("global_position", "position"):
                errors.append(f"{rel}:{line}: 'var {var} := ...instantiate()' infiere Node "
                              f"pero despues se usa {var}.{member} -> usar '='")
                break

# 5. Arrays constantes sin tipar usados en un `for` cuyo cuerpo hace `var x := ...`
for f in files:
    src = open(f, encoding="utf-8").read()
    rel = os.path.relpath(f, ROOT)
    untyped_consts = set(re.findall(r'^const\s+([A-Z_]+)\s*:=\s*\[', src, re.M))
    for c in untyped_consts:
        for m in re.finditer(r'for\s+([a-zA-Z_]\w*)\s+in\s+' + re.escape(c) + r'\s*:', src):
            loop_var = m.group(1)
            rest = src[m.end():]
            block = rest.split("\nfunc ")[0]
            if re.search(r'\bvar\s+\w+\s*:=[^\n]*\b' + re.escape(loop_var) + r'\b', block):
                line = src[:m.start()].count("\n") + 1
                errors.append(f"{rel}:{line}: 'for {loop_var} in {c}' con {c} sin tipar -> "
                              f"{loop_var} es Variant y rompe la inferencia; tipar el const")

# 6. `for X in get_nodes_in_group(...)` / `get_children()` -> X queda tipado como
#    Node (son Array[Node]). Pedirle un miembro propio del proyecto es error.
for f in files:
    src = open(f, encoding="utf-8").read()
    rel = os.path.relpath(f, ROOT)
    lines_src = src.split("\n")
    for i, line in enumerate(lines_src):
        m = re.search(r'\bfor\s+([a-zA-Z_]\w*)\s+in\s+.*(get_nodes_in_group|get_children)\s*\(', line)
        if not m:
            continue
        var = m.group(1)
        indent = len(line) - len(line.lstrip())
        # cuerpo del for: lineas siguientes mas indentadas
        for line2 in lines_src[i + 1:]:
            if line2.strip() and (len(line2) - len(line2.lstrip())) <= indent:
                break
            for m2 in re.finditer(re.escape(var) + r'\.([a-zA-Z_]\w*)', line2):
                member = m2.group(1)
                if member in custom or member in ("global_position", "position"):
                    errors.append(f"{rel}:{i+1}: 'for {var} in ...{m.group(2)}()' -> {var} es Node "
                                  f"y se usa {var}.{member} (miembro que Node no tiene) -> pasarlo "
                                  f"a una variable sin tipo")

# 7. append() sobre Array[T] tipado con el resultado de load() (devuelve Resource).
for f in files:
    src = open(f, encoding="utf-8").read()
    rel = os.path.relpath(f, ROOT)
    typed_arrays = set(re.findall(r'\bvar\s+([a-zA-Z_]\w*)\s*:\s*Array\[\w+\]', src))
    for arr in typed_arrays:
        for m in re.finditer(re.escape(arr) + r'\.append\(\s*load\(', src):
            snippet = src[m.start():m.start() + 200]
            if " as " not in snippet.split("\n")[0]:
                line = src[:m.start()].count("\n") + 1
                errors.append(f"{rel}:{line}: '{arr}.append(load(...))' mete un Resource en un "
                              f"Array tipado -> falta el cast 'as <Tipo>'")

print("=== POSIBLES ERRORES DE TIPADO ===")
print("\n".join(errors) if errors else "(ninguno)")
sys.exit(1 if errors else 0)
