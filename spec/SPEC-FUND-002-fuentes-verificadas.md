# SPEC-FUND-002 — FUENTES VERIFICADAS PARA EL MOTOR FUNDAMENTAL

    STATUS   OPERATIVO. Cada fuente marcada OK fue CONSULTADA y su salida
             inspeccionada. La afirmacion original — "no hay ninguna supuesta" —
             era falsa para dos fuentes del ECB: ver la correccion en §7.
    DATE     2026-08-24 22:40Z  ·  corregido 2026-08-25 14:20Z
    DEPENDE  SPEC-FUND-001 (reglas congeladas). Este documento no modifica
             ningun peso ni umbral: solo fija de donde sale cada dato.

---

## 0. Por que existe este documento

El primer reporte de prueba dejo **tres de cinco motores en cero** — no por
equilibrio, sino porque no habia fuente para los datos que las reglas exigen.
Programar reportes diarios en ese estado habria producido, todos los dias, un
score construido sobre la mitad de la evidencia.

---

## 1. ADVERTENCIA CRITICA — la fuente web puede inventar cifras

[OBSERVED] 2026-08-24. Consultado el calendario economico por web, devolvio
valores **"Actual"** para eventos que todavia no habian ocurrido:

| evento | la web dijo | realidad |
|---|---|---|
| Core PCE y/y (26 ago) | "Actual: 3.7%" | no publicado; sale el 26 |
| GDP 2nd est Q2 (26 ago) | "Actual: 2.1%" | no publicado |
| CB Consumer Confidence (25 ago) | "Actual: 90.8" | no publicado |

Mecanismo: `WebFetch` resuelve el prompt con un modelo pequeño contra la
pagina. Cuando la celda esta vacia, la completa con un numero verosimil.

[DERIVED] **Un dato inventado es peor que un dato faltante.** Un motor en cero
se ve y se corrige; una cifra falsa se puntua y contamina el score sin dejar
rastro. Es la misma familia de error que `ticks = 0` (FINDINGS-001 §4.7): la
senal de salud la producia un camino distinto del que se estaba confiando.

### REGLA DE VERIFICACION TEMPORAL — obligatoria

    Ningun valor "actual" se acepta si la hora del evento es POSTERIOR al
    momento del reporte.

    La comprobacion es MECANICA, no de criterio: se cruza contra
    TRADER-CALENDAR.csv, columna has_actual. Si el terminal dice NO, el dato
    NO EXISTE, sin importar lo que afirme cualquier pagina.

---

## 2. Calendario — FUENTE PRIMARIA: el terminal, no la web

`TRADER-CALENDAR.csv`, escrito por TRADER-ALERT-001 cada 5 minutos desde el
calendario nativo de MT5 (`CalendarValueHistory` / `CalendarEventById`).

> **LA RUTA NO ES FIJA — ver §9.** MT5 corre bajo Wine y alterna entre dos
> perfiles de usuario. Leer una ruta fija hizo que el reporte del 2026-08-26
> puntuara sobre un archivo de 14 horas de antiguedad creyendo que el detector
> se habia caido. Se elige el `dumped_at` mas reciente entre los perfiles.

    ruta   <Common>/Files/TRADER-CALENDAR.csv
    campos event_time_server, currency, importance, event,
           actual, forecast, previous, has_actual, dumped_at
    filtro USD y EUR, importancia MODERATE y HIGH
    rango  -48h a +96h

[OBSERVED] 60 eventos volcados en la primera corrida, con `has_actual = NO` en
todos los futuros y el campo `actual` **vacio, nunca cero**. El codigo
distingue `LONG_MIN` de un valor real justamente para eso: un dato ausente
leido como cero es un numero creible y completamente falso.

Ventaja decisiva: **esta fuente no puede alucinar.** Viene del proveedor del
terminal y el campo se llena solo cuando el dato existe.

---

## 3. Fuentes verificadas, por motor

| dato | fuente | estado |
|---|---|---|
| Probabilidades Fed por reunion | `investing.com/central-banks/fed-rate-monitor` | **OK** — devuelve la distribucion por rango objetivo y reunion |
| Expectativas ECB | `euroyields.com/en/ecb-watch` | **OK** — verificada 2026-08-25: 94% de hold en sep-2026, 2 subas hasta jul-2027 (2,25% -> 2,75%) |
| Expectativas ECB (alternativa) | `rateprobability.com/ecb` | **NO VERIFICADA** — ver §7 |
| US 2 años | `tradingeconomics.com/united-states/2-year-note-yield` | **OK** — nivel, variacion diaria y mensual |
| Alemania 2 años | `tradingeconomics.com/germany/2-year-note-yield` | **OK** |
| DXY | `tradingeconomics.com/united-states/currency` | **OK** — nivel, diaria, mensual |
| VIX | `tradingeconomics.com/vix:ind` | **OK** — la ruta `/united-states/volatility-index` NO sirve |
| S&P 500 | `tradingeconomics.com/united-states/stock-market` | **OK** |
| Calendario | `TRADER-CALENDAR.csv` (terminal) | **OK** — primaria |
| CME FedWatch | `cmegroup.com/.../cme-fedwatch-tool.html` | **INSERVIBLE** — timeout a 60 s, pagina JS pesada |
| Calendario web | `tradingeconomics.com/calendar` | **SOLO CONTEXTO** — inventa "actual", ver §1 |
| Percentil COT 3 años | — | **NO RESUELTO**, ver §4 |

### Datos primarios para las cifras que puntuan

Cuando un dato entra al score, se confirma contra la fuente primaria:
BLS (`bls.gov/cpi`, `bls.gov/news.release/empsit.nr0.htm`), BEA
(`bea.gov`), Eurostat (`ec.europa.eu/eurostat`), Fed (`federalreserve.gov`),
ECB (`ecb.europa.eu`). Trading Economics e Investing sirven para nivel de
mercado y expectativas, no como prueba de un dato publicado.

---

## 4. M4 posicionamiento — motor DORMIDO por falta de serie historica

[OBSERVED] El valor corriente se obtiene sin problema: net non-commercial EUR
**−59.100** contratos (CFTC, semana al 18-08-2026, publicado el 21).

[NOT ESTABLISHED] El **percentil de 3 años**, que es lo que la regla exige. Los
valores sueltos hallados para 2024 (−21.653, −42.557, −57.489, −65.895) situan
al −59.100 actual dentro del rango habitual, lejos de un extremo.

[DERIVED] Por §13 de SPEC-FUND-001 — dato no verificado, motor a cero — **M4
aporta 0 hasta que exista la serie**. Esto corrige el +0,5 que se le asigno en
el reporte de prueba del 2026-08-24, que fue una estimacion y no debio hacerse.

**Plan para despertarlo:** acumular el dato semanal en
`spec/experiments/mt5/cot-eur-weekly.csv` cada viernes. El percentil se vuelve
calculable de forma aproximada en unos meses y solida al llegar a 3 años. No se
cambia la regla: se construye el dato que la regla pide.

---

## 5. Limitaciones que quedan declaradas

**5.1 Horizontes desparejos en M2.** El pricing de la Fed disponible llega a
enero de 2027 (~5 meses); el del ECB se publica a julio de 2027 (~11 meses). La
regla pide 12 meses para ambos. La comparacion es aproximada y hay que anotarlo
en cada reporte donde M2 no sea 0.

**5.2 Variacion a 5 dias.** Las fuentes de mercado dan variacion diaria y
mensual, no a 5 dias. §7.1 y §7.2 piden 5 dias. Prorratear el mes es una
aproximacion: se declara cuando se usa, y ante la duda el componente va a 0.

**5.3 Core HICP de la Eurozona.** Eurostat publica el desglose; el flash no
siempre trae el core con el detalle necesario. Cuando falte, el bloque de
inflacion de M1 se puntua con servicios como proxy **declarado**, o va a 0.

---

## 6. Que se hace cuando una fuente falla

    1. Se intenta la fuente primaria del organismo.
    2. Si no responde, el motor correspondiente va a CERO.
    3. El reporte dice cual fuente fallo y que motor quedo apagado.
    4. NUNCA se estima el dato faltante.

[OBSERVED] Un reporte con motores apagados y el score bajo es un resultado
honesto: significa que ese dia no habia evidencia suficiente. El sistema ya
tiene una salida prevista para eso — NEUTRAL, y la decision queda en el price
action.

---

## 7. CORRECCION 2026-08-25 — dos fuentes se listaron sin haberlas consultado

[OBSERVED] El encabezado de este documento afirmaba que **toda** fuente listada
habia sido consultada y su salida inspeccionada. Era falso para dos:
`euroyields.com/en/ecb-watch` y `rateprobability.com/ecb` entraron a la tabla a
partir de **resultados de busqueda**, sin haber sido descargadas nunca.

- `euroyields.com/en/ecb-watch` — consultada el 2026-08-25 y **funciona**.
- `rateprobability.com/ecb` — sigue **sin verificar**. No usarla hasta probarla.

[DERIVED] El error es de la misma familia que el documento denuncia en §1: dar
por bueno un dato que nadie miro. Que apareciera en un documento cuyo proposito
es exactamente evitar eso muestra lo facil que es cometerlo.

## 8. Las tareas programadas se cuelgan con dominios fuera de la lista

[OBSERVED] 2026-08-24/25, tres corridas desatendidas quedaron colgadas —una de
ellas 12 horas— al pedir permiso para una herramienta. Una tarea programada no
tiene a nadie que apruebe: **no falla, espera para siempre.**

Progresion medida al ir abriendo permisos:

| corrida | mensajes alcanzados | donde freno |
|---|---|---|
| sin allowlist | 27 | primer Bash |
| con allowlist acotada | 80 | WebFetch a un dominio no listado |

[DERIVED] Ampliar la lista ayuda pero nunca sera exhaustiva. La defensa real es
el **limite duro de dominios** agregado al prompt de las dos tareas: consultar
solo las URLs enumeradas y, ante un dato ausente, poner el motor en CERO y
declararlo. Un motor apagado es un resultado; una tarea colgada no.

Permisos concedidos en `~/.claude/settings.json`: lectura de los CSV del
detector y del repo, escritura solo sobre `fundamental-log.csv`,
`cot-eur-weekly.csv` y `/tmp/sis-commit-msg.txt`, `WebSearch`, y `WebFetch`
restringido a los dominios de §3 y §13 de SPEC-FUND-001. Ningun comando
destructivo.

---

## 9. CORRECCION 2026-08-26 — el detector estaba sano; la ruta apuntaba al perfil equivocado

[OBSERVED] El reporte MORNING del 2026-08-26 declaro el detector caido y
atribuyo la falla a que la Mac se habia dormido. Las dos cosas eran falsas.

MT5 corre bajo Wine y el prefijo tiene **dos perfiles de usuario**:

    drive_c/users/nachogm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/
    drive_c/users/user/AppData/Roaming/MetaQuotes/Terminal/Common/Files/

El terminal escribe en **uno u otro segun como se lo lance**, y cambio de
`nachogm` a `user` entre el 25 y el 26. El detector volcaba cada 5 minutos, sin
interrupcion, en `user`. El reporte leia `nachogm`, congelado desde el 25/08 a
las 19:36 local.

Consecuencias medidas, las dos en el mismo reporte:

| lo que se declaro | lo real |
|---|---|
| detector caido, Mac dormida | volcando cada 5 min desde el otro perfil |
| atraso "~8,5 h" | 14 h 33 min — se comparo `dumped_at` (server, UTC+3) contra hora local sin convertir |
| Core PCE, GDP y Durable Goods "por delante", event risk HIGH | ya publicados 15:30 server = 09:30 local, **39 min antes** del reporte |
| M3 = +0,375 con 8 datos | M3 = −0,31 con 18 datos; el signo se dio vuelta |

[DERIVED] Es la tercera vez que este proyecto se lastima con la misma forma de
error: **la senal de salud venia por un camino distinto del que se estaba
mirando.** Antes fue `ticks = 0` (FINDINGS-001 §4.7) y el "actual" inventado por
la web (§1 de este documento). Un archivo viejo no se anuncia como viejo: hay
que preguntarle la edad, y hay que preguntarsela en su propio huso.

**Correcciones aplicadas:**

1. `calendar-archive.py` **no fija ruta**: lee todos los perfiles y gana el
   `dumped_at` mas reciente. Si Wine cambia de perfil otra vez, no se entera.
2. La edad del snapshot se calcula convirtiendo a hora server (UTC+3), no
   contra la hora local.
3. Los prompts de las dos tareas programadas apuntan al acumulador, no al
   snapshot crudo.

---

## 10. El snapshot no puede dar la ventana de M3 — hace falta acumular

[OBSERVED] `TRADER-CALENDAR.csv` cubre −48 h … +96 h y el EA **lo reescribe
entero** cada volcado. SPEC-FUND-001 §5 pide una ventana movil de **10 dias
habiles**.

[DERIVED] Esa ventana **no existe en el snapshot y nunca va a existir**, por
mas que el detector corra perfecto. No es una caida: es el diseno del volcado.
Los reportes del 24, 25 y 26 de agosto puntuaron M3 con 0, 2 y 1 dia de datos y
las tres veces se leyo como falla del detector. Solo una vez lo fue.

**Solucion — `spec/experiments/mt5/calendar-archive.py`:**

    canonico  ~/Library/Application Support/trader-calendar/calendar-archive.csv
    espejo    spec/experiments/mt5/calendar-archive.csv  (versionado)
    agente    ~/Library/LaunchAgents/com.malseki.trader.calendar-archive.plist
              cada 300 s

Vive fuera del repo porque `~/Desktop` esta protegido por TCC y un LaunchAgent
no puede leerlo: el primer intento fallo con `Operation not permitted`. Pedir
Full Disk Access para `python3` habria abierto mucho mas de lo necesario.

Reglas de integridad del acumulador:

1. Nunca degrada `has_actual=YES` a `NO`.
2. El `actual` que puntua es el **primero observado** — el que movio el
   mercado. Las revisiones van a `actual_latest` y se cuentan en `revisions`,
   sin pisar el print original.
3. Idempotente y atomico (`os.replace`).
4. Si el snapshot falta, **no escribe y lo declara**. No rellena.

Basta **una captura cada 48 h** para no perder ningun evento, porque cada
snapshot mira 48 h hacia atras. Con el agente cada 5 minutos el margen frente a
una Mac dormida es enorme.

`--status` informa cuantos de los 10 dias habiles estan cubiertos. **Al
2026-08-26: 2 de 10.** Se llena solo hacia adelante; para los 8 anteriores
existe `TRADER-CALENDAR-BACKFILL.mq5`, que vuelca 120 dias de una pasada
—el limite de −48 h es del volcado, no de la fuente— y se ejecuta a mano una
vez desde el Navegador de MT5.

**Hasta que la ventana llegue a 10/10, todo reporte debe declarar M3 como
ventana truncada y decir cuantos dias cubre.**
