# Legal y privacidad — Cuarentena

> **No soy abogado.** Esto es una guía práctica para orientarse, no asesoramiento
> legal. Para lo específico (sobre todo el acuerdo entre ustedes tres y el día
> que haya multijugador) conviene consultar a un profesional.

## 1. Resumen: hoy están casi sin exposición

La cantidad de obligaciones legales que tiene un videojuego **escala con lo que el
juego hace**, no con lo bueno que sea. Y hoy este proyecto está en el escalón más
bajo posible:

| Lo que hace el juego hoy | Consecuencia legal |
|---|---|
| Es **offline**, no se conecta a ningún servidor | No hay transferencia de datos |
| **No recolecta ningún dato personal** | Las leyes de privacidad prácticamente no aplican |
| El guardado es un **archivo local** (`user://savegame.json`) | Eso **no es** "recolectar datos": nunca sale de la máquina del jugador |
| Es **gratis y sin fines de lucro** | Casi no hay relación de consumo |
| No hay cuentas, ni login, ni chat, ni analytics | No hay nada que proteger ni que declarar |

**Traducción:** mientras el juego siga así, no necesitan política de privacidad ni
registrar nada en ningún lado. Lo que sí importa hoy es **de quién es el juego** y
**de dónde salen los assets** (secciones 5 y 6).

Lo pesado llega recién con el **cooperativo online** (Fase 3-4), que es cuando
empiezan a manejar datos de otras personas.

## 2. Argentina

### Datos personales — Ley 25.326
Es la ley que regula el tratamiento de datos personales. La aplica la **AAIP**
(Agencia de Acceso a la Información Pública). Históricamente, quien mantiene una
base de datos personales debía inscribirla ante la AAIP.

**Aplica si** tratan datos personales de otras personas. Hoy **no tratan
ninguno**, así que no aplica. Hay proyectos de ley para modernizarla y acercarla
al estándar europeo; si eso avanza, el criterio de fondo (recolectar lo mínimo)
los sigue protegiendo igual.

### Propiedad intelectual — Ley 11.723
El software y las obras artísticas (el arte, la música) están protegidos por
derecho de autor **desde que se crean**, sin necesidad de registrarlos.

El registro en la **DNDA** (Dirección Nacional del Derecho de Autor) es
**opcional**, pero sirve como prueba de autoría y de fecha. Para un proyecto de
tres personas es barato y evita discusiones si algún día alguien reclama algo.

### Coautoría entre ustedes tres — el punto más importante
Bajo la ley argentina, cuando varias personas crean una obra juntas, **son
coautoras** y en principio comparten los derechos. Sin un acuerdo escrito, esto
significa que:

- Si uno se va enojado, **sigue siendo dueño de su parte**.
- Podría oponerse a que publiquen, o pedir que saquen su aporte.
- Si algún día entra plata (donaciones en itch.io, por ejemplo), no está claro
  cómo se reparte.

**Es el riesgo más subestimado y el más fácil de evitar.** Un documento simple
firmado por los tres, antes de meterle horas, alcanza. Debería decir:
- que el proyecto es sin fines de lucro y de los tres (o el reparto que elijan);
- qué pasa si alguien deja el proyecto;
- que cada uno licencia su aporte al proyecto común;
- qué pasa si alguna vez entra dinero.

### Defensa del consumidor — Ley 24.240
Regula la relación entre proveedores y consumidores. Siendo **gratuito y sin
fines de lucro**, no hay verdadera relación de consumo, así que la exposición es
mínima. Igual conviene el "se entrega tal cual, sin garantías" de la sección 7:
ojo que en Argentina las cláusulas que limitan responsabilidad frente a
consumidores tienen límites, no son un escudo absoluto.

## 3. A nivel global

Estas leyes aplican **según dónde estén los jugadores**, no dónde estén ustedes.
Si un europeo se baja el juego de itch.io, en principio les alcanza el GDPR.

| Norma | ¿Aplica hoy? | ¿Qué la activaría? |
|---|---|---|
| **GDPR** (Unión Europea) | **No** — no tratan datos | Cuentas, analytics, telemetría, o guardar IPs en el coop |
| **UK GDPR** (Reino Unido) | No | Lo mismo que GDPR |
| **CCPA / CPRA** (California) | **No** | Además de recolectar datos, exige umbrales grandes (facturación millonaria, 100.000+ consumidores, o vivir de vender datos). Un proyecto hobby no llega ni cerca |
| **COPPA** (menores de 13, EE.UU.) | No | Recolectar datos de menores de 13. Un juego de zombies con violencia no es "dirigido a chicos", lo que ayuda, pero no es una excusa automática |
| **LGPD** (Brasil) | No | Igual que GDPR |

**El patrón es siempre el mismo:** todas se activan cuando **tratás datos
personales**. Por eso la mejor estrategia legal para un indie es también la más
simple: **no recolectar nada**, y si en algún momento hace falta, recolectar lo
mínimo y decirlo claro.

## 4. Qué cuenta como "dato personal" (más de lo que parece)

No es solo el nombre o el email. También cuentan:

- La **dirección IP** ← esto es lo que los va a agarrar con el cooperativo
- Un identificador de dispositivo o de instalación
- Datos de analytics asociables a una persona
- Reportes de crashes con información del equipo
- Lo que escriban los jugadores en un chat

## 5. Riesgos reales, ordenados por probabilidad

Estos son los que de verdad le pasan a proyectos como este:

1. **Licencias de assets (el más común y el que más hunde proyectos).**
   Todo lo que usen y no hayan hecho ustedes —música, tipografías, sprites,
   sonidos, librerías— necesita una licencia que lo permita. "Gratis" no es lo
   mismo que "puedo hacer lo que quiera": hay que leer si permite uso comercial,
   si exige crédito, si permite modificar.
   - Godot es MIT → tranquilos.
   - Nunca música, personajes ni marcas con copyright ajeno.
   - Assets generados con IA: zona gris, y algunas plataformas los restringen.
     Si usan, guarden registro de con qué herramienta y bajo qué términos.
   - **Lleven un `CREDITS.md`** con cada asset externo, su autor y su licencia.

2. **Choque de nombre.** Antes de casarse con un título, busquen si no hay otro
   juego o marca registrada con ese nombre, sobre todo en inglés. No hace falta
   registrar el suyo, pero sí evitar pisar el de otro y tener que renombrar todo
   más adelante.

3. **Disputa de coautoría** entre ustedes (ver sección 2). Se evita con un papel.

4. **Exposición de IPs en el cooperativo** (Fase 3-4). Si los jugadores se
   conectan directo entre sí (P2P, que es lo más fácil de programar), **se ven
   las IPs entre ellos**. Eso es un dato personal y además un vector de ataque
   (alguien podría tirarle la conexión a otro). Hay que avisarlo o meter un
   servidor en el medio.

5. **Moderación**, si algún día hay chat. Sin forma de reportar y moderar, el
   juego puede volverse un canal de acoso.

## 6. Seguridad (crece de golpe con el multijugador)

**Hoy (offline):** riesgo mínimo. Solo cuidar de dónde bajan librerías, y que
leer un archivo de guardado o un mod no pueda ejecutar código.

**Cuando llegue el coop:**
- **Nunca confiar en el cliente.** El jugador puede modificar su copia. La lógica
  importante (vida, daño, recursos) se valida del lado del servidor. Esto previene
  trampas *y* exploits.
- **Validar todo lo que llega por la red.** Datos mal formados no deberían
  crashear ni, peor, permitir ejecutar código en la máquina de otro.
- **Nunca guardar contraseñas en texto plano.** Mejor todavía: no manejar
  contraseñas propias y apoyarse en un login de terceros.
- **Cifrar en tránsito** (TLS) lo que sea sensible.

## 7. Documentos: cuáles necesitan y cuándo

| Documento | ¿Lo necesitan hoy? | Cuándo pasa a ser necesario |
|---|---|---|
| **Acuerdo entre los 3** | **Sí, ya** | Ahora, antes de meterle horas |
| **`CREDITS.md`** de licencias | **Sí, ya** | Desde el primer asset externo |
| **Términos / EULA** ("tal cual, sin garantías") | Recomendado | Al publicar, aunque sea gratis |
| **Política de privacidad** | **No** | Recién si recolectan cualquier dato (analytics, cuentas, coop online) |
| **Clasificación por edad** | Al publicar | itch.io lo declaran ustedes mismos; Steam tiene un cuestionario; las consolas exigen rating oficial pago |

Por el contenido (zombies, violencia), el juego va a caer en algo tipo **+16/+17**.
Eso, de paso, ayuda a que no se lo considere "dirigido a menores".

## 8. Checklist por fase

**🟢 Ahora (offline, sin datos)**
- [ ] Acuerdo simple firmado entre los tres
- [ ] Empezar el `CREDITS.md` desde el primer asset externo
- [ ] Chequear que el nombre no pise una marca existente

**🟡 Antes de publicar (aunque sea gratis)**
- [ ] `CREDITS.md` completo y revisado
- [ ] Un EULA básico "tal cual, sin garantías"
- [ ] Declarar la clasificación de contenido en itch.io

**🔴 Al agregar el cooperativo online**
- [ ] Política de privacidad (si se toca cualquier dato, incluida la IP)
- [ ] Decidir P2P vs. servidor, sabiendo que P2P expone las IPs entre jugadores
- [ ] Validar todo del lado del servidor; no confiar en el cliente
- [ ] Moderación y sistema de reportes si hay chat
