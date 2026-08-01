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


# Municion: cualquier id que una firearm apunte con "municion". Se calcula
# antes de recorrer el loot porque el tope de abajo lo necesita.
ammo_ids = {idef.get("municion") for idef in items.values() if idef.get("fuego")}

# Tope de municion por entrada de tabla de loot. La trampa exacta que paso:
# balas_9mm llego a salir 3-8 por tirada, hasta 24 de una sola caja militar
# (3 tiradas x 8) — el testeo lo marco como demasiado. Bajo a 1-3 y quedo
# este tope para que nadie lo vuelva a subir sin querer.
MAX_AMMO_PER_ENTRY = 5

for table_id, table in loot.items():
    if table_id.startswith("_"):
        continue
    for entry in table.get("botin", []):
        if entry["item"] not in known:
            errors.append(f"loot_tables[{table_id}]: item inexistente '{entry['item']}'")
        if entry.get("min", 1) > entry.get("max", 1):
            errors.append(f"loot_tables[{table_id}]: {entry['item']} tiene min > max")
        if entry["item"] in ammo_ids and entry.get("max", 1) > MAX_AMMO_PER_ENTRY:
            errors.append(f"loot_tables[{table_id}]: {entry['item']} da hasta {entry['max']} de una "
                          f"sola vez (tope {MAX_AMMO_PER_ENTRY}) — sobran balas")
    lo, hi = table.get("tiradas", [1, 1])
    if lo > hi:
        errors.append(f"loot_tables[{table_id}]: tiradas min > max")

for rec in recipes:
    for section in ("cuesta", "produce"):
        for item in rec.get(section, {}):
            if item not in known:
                errors.append(f"recipes[{rec['id']}].{section}: item inexistente '{item}'")

    # Ninguna receta saca de la nada algo que sacie sed: si produce algo con
    # "sed", tiene que gastar algo que YA tenga "sed" (agua sucia, pescado...).
    # Es la trampa exacta que tenia "hervir agua": 1 madera (sed 0) -> agua
    # hervida (sed 45), fabricando hidratacion de la nada.
    produce_sed = any(items.get(item, {}).get("sed", 0) > 0 for item in rec.get("produce", {}))
    cuesta_sed = any(items.get(item, {}).get("sed", 0) > 0 for item in rec.get("cuesta", {}))
    if produce_sed and not cuesta_sed:
        errors.append(f"recipes[{rec['id']}]: produce algo que sacia sed pero no gasta nada "
                      "que ya la sacie (fabrica agua de la nada)")

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
