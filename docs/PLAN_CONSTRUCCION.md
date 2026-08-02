# Plan — Construcción de fortalezas

Propuesta para discutir en equipo. Todavía **no** está implementado.

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

---

## Fase 1 — Muros con vida y materiales

La base de todo lo demás. Sin esto, el resto no tiene sentido.

**Qué cambia**

- Los muros pasan a tener `vida`, y se ven dañados a medida que se los golpea
  (mismo patrón de feedback que ya usan zombies y lobos: parpadeo y barra).
- Tres materiales en vez de uno solo:

  | Muro | Cuesta | Aguanta | Para qué |
  |---|---|---|---|
  | Madera | 2 madera | Poco | Tapar un hueco rápido |
  | Piedra | 3 piedra | Medio | El muro estándar |
  | Metal | 2 metal + 1 tabla | Mucho | El anillo interno de la base |

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
de bloques sueltos.

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

1. **¿Cuánto tiene que aguantar cada cosa?** Es puro balance y solo se resuelve
   jugando. Los números de la tabla de arriba son un punto de partida, y lo que
   más va a costar calibrar es la puerta: muy blanda y no sirve de nada, muy dura
   y no cambió nada respecto de hoy.
2. **¿Vale la pena construir si igual perdés todo al morir?** Hoy la base dura lo
   que dura la partida. Alternativa a discutir: que algo quede entre partidas.

> **Ya decidido:** las puertas se rompen, también las de las casas del mapa.
> Ver "Qué implica que las puertas se rompan", arriba.

## Riesgo a tener en cuenta

La barra de construcción de abajo hoy es una fila de botones con las teclas 1 a 4.
Con ocho o nueve cosas construibles queda incómoda y va a necesitar categorías.
Es trabajo de interfaz que no está contemplado arriba.

## Orden sugerido

Fase 1 sola, y jugarlo. Es el cambio que más modifica la sensación del juego y es
la base que las Fases 2 y 3 necesitan. Si con muros rompibles el juego no gana
nada, no tiene sentido seguir con el resto.
