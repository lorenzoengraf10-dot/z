# Diseño del mapa mundial

## Referencia

El usuario compartió una imagen de referencia ("The Wasteland of New Haven"): un mapa ilustrado estilo pixel art/isométrico con:

- Una **ciudad central fortificada** (edificios altos, murallas) como hub del mapa.
- **Rutas/caminos que irradian** desde el hub hacia puntos de interés (POI) periféricos.
- POIs temáticos y nombrados: un puesto militar al norte, un campamento maderero, zonas de cultivo, un asentamiento de chatarreros, ruinas/cementerio de alto riesgo, un campamento ferroviario.
- Terreno variado: bosque denso, montañas/rocas, ríos y una costa/lago.
- Brújula, leyenda y título como elementos de UI del mapa.

Adoptamos esta misma estructura para **Cuarentena**, con nombres propios (de ejemplo, reemplazables).

## Estructura adoptada

- **Refugio Central** (hub): el asentamiento fortificado principal, punto de partida sugerido. Análogo a "New Haven" en la referencia.
- **6 POIs periféricos**, conectados por caminos que salen del hub, cada uno con un rol de gameplay distinto:

| Nombre (ejemplo) | Tipo | Rol de gameplay | Análogo en la referencia |
|---|---|---|---|
| Refugio Central | hub | Base "segura" de partida, comercio/NPCs a futuro | New Haven |
| Puesto Norte 7 | outpost | Botín militar (armas, munición), más vigilado | Outpost 7 |
| Campamento Los Pinos | camp (recursos) | Fuente de madera | Redwood Camp |
| Las Chacras | resource | Semillas, cultivo, comida | The Farms |
| Chatarrópolis | camp (recursos) | Piezas mecánicas, crafteo de armas improvisadas | Junktown |
| El Osario | danger | Alto riesgo / alto botín, zona muy infestada | The Boneyard |
| Campamento Ferroviario | camp | Ruta de exploración hacia otras zonas del mapa | Railroad Encampment |

Estos nombres son placeholders — la idea es mantener la **estructura** (hub central + POIs con roles claros conectados por caminos) aunque cambien los nombres definitivos.

## Dónde vive esto en el proyecto

- Los datos están en `game/data/world_map.json` (nombre, tipo, posición normalizada, descripción de cada lugar).
- `game/scripts/map_screen.gd` lee ese JSON y dibuja los lugares como etiquetas sobre la pantalla de mapa (`M` para abrir/cerrar en el prototipo).
- Por ahora es texto sobre fondo vacío — sin arte. Para agregar o mover lugares alcanza con editar el JSON, no hace falta tocar código (ver `game/README.md`).

## Dos necesidades de arte distintas (no confundir)

1. **Arte de gameplay** (tiles, personajes, zombies): pixel art simple top-down, se necesita en volumen, prioridad alta desde la Fase 1-2 del roadmap.
2. **Arte de la pantalla de mapa mundial**: una sola ilustración estilo la referencia (vista más "pintada"/isométrica, con mucho detalle). Es un asset único, no urgente para que el prototipo sea jugable — tiene sentido priorizarlo más adelante (Fase 3-4), y además sirve como pieza de marketing (capsule de Steam, key art) además de UI in-game.

## Próximos pasos relacionados al mapa

- Definir los nombres y la ambientación final (reemplazar los de ejemplo).
- Decidir si el mapa mundial es un único mapa fijo (como la referencia) o se genera/expande con el tiempo.
- Cuando haya un amigo dedicado a arte, encargar la ilustración del mapa mundial tomando esta estructura como brief.
