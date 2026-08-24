# SPEC-FUND-002 — FUENTES VERIFICADAS PARA EL MOTOR FUNDAMENTAL

    STATUS   OPERATIVO. Cada fuente de esta lista fue CONSULTADA y su salida
             inspeccionada el 2026-08-24. No hay ninguna supuesta.
    DATE     2026-08-24 22:40Z
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
| Expectativas ECB | `euroyields.com/en/ecb-watch` · `rateprobability.com/ecb` | **OK** — subas descontadas y fecha implicada |
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
