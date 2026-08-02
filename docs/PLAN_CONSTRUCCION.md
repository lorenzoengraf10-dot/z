# Plan — Construcción de fortalezas

> **Estado: la Fase 1 está hecha, más el verbo *reparar* de la Fase 2.**
> Lo que ya anda: muros de madera/piedra/metal con vida, puertas rompibles
> (también las de las casas del mapa), zombies que atacan lo que los frena,
> reparar con **B** + clic, y la regla de no construir dentro de las casas.
>
> Lo que **sigue pendiente**: puerta construible y reforzar puertas (resto de
> la Fase 2), la cama, y las Fases 3 y 4 completas.
>
> Se implementó *reparar* junto con la Fase 1 y no después, porque la Fase 1
> sola dejaba el juego peor que antes: se te rompía la puerta del refugio y no
> había ninguna forma de recuperarla.

## Por qué

Hoy se pueden poner barricadas, fogatas, mesas y cofres en cualquier lado, pero
construir no es una mecánica: es decoración. Hay dos motivos concretos, los dos
verificables en el código:

1. **Las barricadas son indestructibles.** `Barricade.tscn` es un `StaticBody2D`
   sin script y sin vida. Nada en el juego puede romperlas.
2. **Los zombies no saben que existen.** `zombie.gd::_do_attack()` solo le pega
   al jugador. Frente a un muro se quedan empujando para siempre.

El resultado es que encerrarse gana la partida sola, sin costo ni tensión — algo
que el README ya marcaba como pendiente de revisar. La propuesta es convertir eso
en la decisión interesante que debería ser: **una fortaleza pobre no te salva y
una buena sí**.

### El norte de diseño

Una base tiene que tener una razón de existir. La razón natural, con los sistemas
que ya andan, es **la noche**: baja la temperatura (hace falta fuego), y las
hordas ya reaccionan al ruido acumulado. Llegar al anochecer con un refugio en
pie pasa a ser un objetivo real de la partida.

### Regla nueva: las casas del mapa no se equipan

Falta una pieza para que "construir tu propio refugio" tenga un motivo real:
hoy cualquiera se mete en una casa del mapa y la equipa entera —cofre, mesa,
fogata— sin haber construido nada. La regla: **ninguna construcción nueva se
puede plantar sobre el piso de una casa prediseñada del mapa.** Ni muro, ni
puerta, ni mesa, ni fogata, ni cofre, ni la cama de más abajo.

Lo que **no** cambia: un armario ya saqueado adentro de una casa se sigue
pudiendo reutilizar para guardar cosas (esa mecánica no pasa por el sistema de
construcción, así que la regla no la toca). Las casas del mapa no dejan de
servir para nada — siguen siendo un refugio de emergencia real, y se les puede
reforzar la puerta (Fase 2) — pero dejan de poder equiparse desde cero. Para
tener mesa, fogata, cofre y cama hace falta un refugio propio.

**Detalle técnico** — `world.gd` ya expone `char_at_cell(cell)` y la constante
`FLOOR := ","`, el mismo tile que usa `roof_system.gd` para reconocer el
interior de un edificio. Es el chequeo que se agrega a
`build_system.gd::_can_build()`.

> **Ojo con esto cuando se implemente la Fase 3:** esa fase agrega un tile de
> piso que el jugador puede colocar en su propio refugio, con el mismo `FLOOR`
> del mapa. Si la regla nueva no distingue *piso del mapa* de *piso que puso el
> jugador*, el jugador queda trabado sin poder seguir construyendo dentro de su
> propia casa apenas le pone el piso. Hace falta un tile distinguible (mismo
> aspecto, distinto índice interno) — se resuelve al implementar la Fase 3, no
> antes.

---

## Fase 1 — Muros con vida y materiales

La base de todo lo demás. Sin esto, el resto no tiene sentido.

**Qué cambia**

- Los muros pasan a tener `vida`, y se ven dañados a medida que se los golpea
  (mismo patrón de feedback que ya usan zombies y lobos: parpadeo y barra).
- Tres materiales en vez de uno solo:

  | Muro | Cuesta | Vida | Golpes (normal) | Golpes (resistente) |
  |---|---|---|---|---|
  | Madera | 2 madera | 120 | 15 | 8 |
  | **Piedra** | 3 piedra | **240** | **30** | **15** |
  | Metal | 2 metal + 1 tabla | 400 | 50 | 25 |
  | **Puerta** | — | **160** | **20** | **10** |
  | Puerta reforzada | 2 tabla + 1 metal | 320 | 40 | 20 |
  | Cama | 2 piel de animal + 5 madera | — | — | — |

  Los números en negrita son los que fijó el equipo; el resto sale de escalarlos.
  La cama no tiene vida propia: es mobiliario, no defensa.

### La cama: dos cosas nuevas, no solo reutilización

- **La "piel" es un ítem que no existe hoy.** `data/items.json` no la tiene, y
  `animal.gd::_drop_meat()` solo suelta `"carne"`. Hace falta agregar el ítem
  y sumarlo como drop de caza (mismo patrón que la carne, otra tirada de loot al
  cazar un animal). Es poco trabajo, pero es trabajo nuevo — no alcanza con
  reutilizar algo que ya está, como sí pasa con la puerta o el guardado.
- **Qué hace dormir:** restaura la energía y además salta el reloj hasta la
  mañana. Es la opción más completa que se decidió, y también la única pieza de
  todo este agregado que no es puro reciclaje de sistemas existentes —
  `day_night.gd::hour` hoy solo avanza en tiempo real, no tiene forma de
  adelantarlo de una vez.
- **La cama depende de la Fase 3.** `roof_system.gd` es lo que distingue "estar
  en una casa" de "estar parado entre cuatro muros a cielo abierto": sin piso
  propio, un refugio armado por el jugador nunca es una habitación de verdad
  para ese sistema, y la cama quedaría siempre a la intemperie. Dos caminos, a
  decidir cuando se implemente (no ahora): que la cama solo funcione si
  `roof_system` reconoce esa celda como interior (consistente, pero espera a la
  Fase 3 completa), o que funcione en cualquier lado como excepción provisoria
  y se ate a la Fase 3 más adelante (la cama llega antes, pero es una excepción
  a destejer después).

### De dónde salen esos números

En el código, un zombi normal pega **8** de daño y el resistente **15**, los dos
**una vez por segundo**. O sea que la columna de golpes es directamente
**segundos**: un muro de piedra aguanta medio minuto contra un zombi solo, y una
puerta veinte segundos.

Para que el resistente caiga justo en la mitad de golpes que el normal, hay que
subirle el daño de **15 a 16**. Es un cambio de una línea y en combate contra el
jugador no se nota (un punto sobre 15), pero hace que toda la tabla cierre
redonda. Si no, el resistente da 16 y 11 golpes en vez de 15 y 10.

El **corredor** pega 6, así que contra las defensas es casi inofensivo: 40 golpes
para un muro de piedra. Está bien que sea así — es el rápido y débil, no el que
rompe puertas.

> **Ojo con esto en el playtest:** los números de arriba son contra **un** zombi.
> Una horda son 2 a 4, y si tres llegan a pegarle a la misma puerta, los 20
> segundos se convierten en 7. El número que importa medir no es el de un zombi
> solo, es el de la horda.

- **Los zombies atacan lo que los frena.** Cuando uno queda trabado contra una
  estructura, le pega en vez de empujar. Se detecta con las colisiones que el
  cuerpo ya reporta al moverse; es el mismo mecanismo que `animal.gd` usa para
  esquivar obstáculos.
- **Las puertas también se rompen** — incluidas las de las casas del mapa. Una
  puerta cerrada pasa a ser un muro más: aguanta un rato y cede. Al romperse
  queda abierta para siempre.

### Qué implica que las puertas se rompan

Es el cambio de mayor peso de todo el plan, así que conviene tenerlo claro:
**se terminan los refugios gratis**. Hoy cualquiera de las 24 casas del mapa es
un búnker perfecto sin costo. Con puertas rompibles, meterse en una casa deja de
ser la respuesta a todo y pasa a ser el *punto de partida*.

El efecto secundario es bueno y vale la pena buscarlo a propósito: la forma
natural de jugar deja de ser "levantar una fortaleza en un campo vacío" y pasa a
ser **agarrar una casa y reforzarla**. Es más intuitivo, aprovecha los edificios
que ya están dibujados, y le da un uso concreto al material que juntás.

Para que no quede injusto, dos recaudos de balance:

- Una puerta tiene que aguantar bastante más que un muro de madera. Que ceda es
  cuestión de tiempo y de cuántos zombies haya, no de dos mordiscos.
- Romperla tiene que hacer **ruido**, para que se note desde adentro que se están
  metiendo y dé tiempo a reaccionar.

**Detalle técnico** — el guardado de puertas ya delega en la puerta misma
(`to_dict()` devuelve si está abierta), así que sumarle la vida al guardado no
requiere tocar el sistema de guardado.

**Detalle técnico** — hoy el costo de construir es un solo número y un solo
material (`COST_ITEM := "madera"` en `build_system.gd`). Pasa a ser un
diccionario `{"piedra": 3}`, igual que las recetas de `recipes.json`. Queda más
consistente con el crafteo, que ya funciona así.

## Fase 2 — Puerta propia y reparar

Con los muros rompibles, aparecen los dos verbos que faltan.

- **Puerta construible.** Hoy solo existen las puertas de las casas del mapa
  prediseñado. `door.gd` ya está entero (abre y cierra con E, cerrada frena a los
  zombies y les corta la visión): alcanza con agregarla a la lista de cosas
  construibles. Sin esto, "hacer una casa" es levantar un anillo de paredes sin
  entrada.
- **Reparar con E.** Pararse al lado de un muro o una puerta dañada con material
  en la mochila y arreglarla. Sin esto, la única forma de arreglar algo es
  desarmarlo y volver a construirlo, que es tedioso y encima devuelve la mitad
  del material.
- **Reforzar puertas.** Gastar material en una puerta que encontraste para
  subirle la vida. Es lo que convierte una casa cualquiera en *tu* base, y le da
  sentido a quedarse en un lugar en vez de andar dando vueltas.

## Fase 3 — Que sea una casa de verdad

En este punto una fortaleza es funcional, pero visualmente sigue siendo un montón
de bloques sueltos. Esta fase también es la que le da sentido real a la cama de
la Fase 1 — ver "La cama depende de la Fase 3", arriba.

- **Piso colocable.** `roof_system.gd` ya sabe convertir piso + paredes + puerta
  en un edificio con techo, interior y todo. Pero solo lee el mapa prediseñado.
  Si el jugador puede colocar el tile de piso, su fortaleza se convierte en un
  edificio real: techo desde afuera, interior al entrar, y aparece en el mapa.
- El mapa ya guarda los tiles modificados (es lo que hace que un árbol talado
  siga talado después de cargar), así que la persistencia sale gratis.

## Fase 4 — Calidad de vida (opcional)

- **Plano de refugio.** Colocar un cuartito de 3×3 con sus paredes y su puerta en
  un solo clic, si tenés el material. Poner 12 bloques a mano es tedioso.
- **Trampas.** Pinches que dañen al zombi que se pega al muro.

Estas dos son mejoras, no requisitos. Si hay que recortar, se recortan.

---

## Lo que hay que decidir entre todos

1. **¿Vale la pena construir si igual perdés todo al morir?** Hoy la base dura lo
   que dura la partida. Alternativa a discutir: que algo quede entre partidas.
2. **¿El jugador puede romper muros y puertas a golpes?** Hoy solo puede desarmar
   lo que construyó él. Si además pudiera romper a golpes, entrar a una casa
   cerrada sería una opción más (ruidosa y lenta) en vez de depender de la
   puerta. No es urgente, pero sale casi gratis una vez que todo tiene vida.

> **Ya decidido:** las puertas se rompen, también las de las casas del mapa, y
> los números de vida ya están fijados (ver la tabla de la Fase 1).

## Riesgo a tener en cuenta

La barra de construcción de abajo hoy es una fila de botones con las teclas 1 a 4.
Con ocho o nueve cosas construibles queda incómoda y va a necesitar categorías.
Es trabajo de interfaz que no está contemplado arriba.

## Orden sugerido

Fase 1 sola, y jugarlo. Es el cambio que más modifica la sensación del juego y es
la base que las Fases 2 y 3 necesitan. Si con muros rompibles el juego no gana
nada, no tiene sentido seguir con el resto.
