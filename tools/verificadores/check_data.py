#!/usr/bin/env python3
"""Verifica que loot_tables.json y recipes.json solo nombren items que existen
en items.json, y que los perks tengan requisitos validos."""
import json, sys
import os

# Raiz del proyecto: dos carpetas mas arriba que este archivo (tools/verificadores/).
GAME = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "game")

D = os.path.join(GAME, "data") + os.sep
items = json.load(open(D + "items.json"))
loot = json.load(open(D + "loot_tables.json"))
recipes = json.load(open(D + "recipes.json"))
perks = json.load(open(D + "perks.json"))

errors = []
known = set(items.keys())

for table_id, table in loot.items():
    if table_id.startswith("_"):
        continue
    for entry in table.get("botin", []):
        if entry["item"] not in known:
            errors.append(f"loot_tables[{table_id}]: item inexistente '{entry['item']}'")
        if entry.get("min", 1) > entry.get("max", 1):
            errors.append(f"loot_tables[{table_id}]: {entry['item']} tiene min > max")
    lo, hi = table.get("tiradas", [1, 1])
    if lo > hi:
        errors.append(f"loot_tables[{table_id}]: tiradas min > max")

for rec in recipes:
    for section in ("cuesta", "produce"):
        for item in rec.get(section, {}):
            if item not in known:
                errors.append(f"recipes[{rec['id']}].{section}: item inexistente '{item}'")

VALID_REQ = {"dias", "zombies", "contenedores"}
seen_ids = set()
for p in perks:
    if p["id"] in seen_ids:
        errors.append(f"perks: id repetido '{p['id']}'")
    seen_ids.add(p["id"])
    if p.get("requisito", {}).get("tipo") not in VALID_REQ:
        errors.append(f"perks[{p['id']}]: requisito desconocido {p.get('requisito')}")

# Campos que ya no lee nadie: si alguien los vuelve a poner (copiando y pegando
# un item viejo) no van a hacer nada y se va a volver loco buscando por que.
RETIRADOS = {
    "infeccion": "la necesidad de infeccion se saco; usar 'dano_salud'",
    "cura_infeccion": "la necesidad de infeccion se saco; usar 'cura'",
}
for iid, idef in items.items():
    for campo, motivo in RETIRADOS.items():
        if campo in idef:
            errors.append(f"items[{iid}]: campo '{campo}' ya no se usa ({motivo})")
    if "dano_salud" in idef and not idef.get("comestible"):
        errors.append(f"items[{iid}]: tiene 'dano_salud' pero no es comestible, no se va a aplicar nunca")

# las armas de fuego tienen que apuntar a una municion que exista
for iid, idef in items.items():
    if idef.get("fuego"):
        ammo = idef.get("municion", "")
        if ammo not in known:
            errors.append(f"items[{iid}]: municion inexistente '{ammo}'")
    if idef.get("arma") and "dano" not in idef:
        errors.append(f"items[{iid}]: es arma pero no tiene 'dano'")

print("=== DATOS ===")
print(f"items: {len(items)} · tablas de loot: {len([k for k in loot if not k.startswith('_')])} · recetas: {len(recipes)} · perks: {len(perks)}")
print("\n".join(errors) if errors else "(sin errores)")
sys.exit(1 if errors else 0)
