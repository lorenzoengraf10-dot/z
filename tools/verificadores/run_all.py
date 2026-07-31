#!/usr/bin/env python3
"""Corre todos los verificadores y devuelve error si alguno falla.

Uso:  python3 tools/verificadores/run_all.py
      python3 tools/verificadores/run_all.py -v     (muestra la salida completa)

Estos verificadores NO reemplazan abrir el proyecto en Godot: revisan lo que se
puede revisar leyendo los archivos (rutas rotas, tipos que Godot rechaza, mapas
mal armados). Sirven para no subir algo que ni siquiera va a abrir.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

CHECKS = [
    ("check_project.py", "rutas res://, load_steps de las escenas y JSON bien formados"),
    ("check_types.py", "tipado estatico de GDScript (el := que Godot no puede inferir)"),
    ("check_data.py", "items, recetas, tablas de loot y perks coherentes entre si"),
    ("check_rooms.py", "cada edificio del mapa tiene piso, paredes y puerta"),
    ("check_loot.py", "cada edificio recibe al menos un contenedor para saquear"),
    ("check_runspawn.py", "hay puntos de spawn aleatorio repartidos por todo el mapa"),
    ("check_spawns.py", "las entidades de Main.tscn caen sobre tiles caminables"),
]

verbose = "-v" in sys.argv
failed = []

for name, description in CHECKS:
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, name)],
        capture_output=True, text=True,
    )
    ok = result.returncode == 0
    print(f"[{'OK ' if ok else 'MAL'}] {name:20} {description}")
    if verbose or not ok:
        for line in (result.stdout + result.stderr).rstrip().split("\n"):
            print("       " + line)
    if not ok:
        failed.append(name)

print()
if failed:
    print("FALLARON:", ", ".join(failed))
    sys.exit(1)
print("Todo en verde.")
