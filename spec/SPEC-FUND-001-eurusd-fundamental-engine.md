# SPEC-FUND-001 — EURUSD FUNDAMENTAL & MARKET SENTIMENT ENGINE

    STATUS   REGLAS SELLADAS. Congeladas 2026-08-24 ANTES de generar el primer
             reporte y ANTES de observar ningun resultado.
    DATE     2026-08-24 22:00Z
    IDIOMA   Espanol deliberado. El resto del repo esta en ingles, pero estas
             reglas las tiene que poder auditar y objetar el trader, que es
             quien las define. Los terminos tecnicos quedan en ingles.

`[OBSERVED]` · `[DERIVED]` · `[INFERRED]` · `[PROPOSED]` · `[NOT ESTABLISHED]`

---

## 0. Que es y que no es este documento

[PROPOSED] Este documento convierte el sistema descrito por el trader en reglas
de puntuacion **operativas**: dado un conjunto de datos publicos, dos personas
distintas deben llegar al mismo score.

**Los pesos de este documento no estan validados.** Estan elegidos a priori por
razonamiento economico, no por ajuste a resultados. Esa es toda su virtud: son
arbitrarios pero **honestos**, porque se fijaron antes de medir nada.

**REGLA DE CONGELAMIENTO.** Ningun peso, umbral o tabla de este documento puede
modificarse despues de haber visto un resultado del experimento E-MT5-036.
Cambiar los pesos tras ver el P&L es exactamente la maniobra que produjo el
balance de $10.862 que se volvio $12,23 sobre datos virgenes (FINDINGS-001
§4.1). Si una regla resulta mal planteada, se abre una version 002 con nueva
fecha y el experimento reinicia su cuenta desde cero. No se corrigen en caliente.

---

## 1. Convencion de signo

    score > 0   ->  favorece EURUSD al alza   (EUR fuerte y/o USD debil)
    score < 0   ->  favorece EURUSD a la baja (USD fuerte y/o EUR debil)

[DERIVED] Todo se mide **relativo**. Nunca "Estados Unidos esta fuerte", siempre
"Estados Unidos esta mas fuerte o mas debil que la Eurozona". Un dato bueno de
EE.UU. con un dato aun mejor de la Eurozona aporta positivo.

---

## 2. Pesos de los cinco motores

| motor | rango | por que ese peso |
|---|---|---|
| M2 — Monetary policy (Fed vs ECB) | −4 … +4 | el diferencial de tasas esperado es el driver estructural del par |
| M1 — Macro relative strength | −2 … +2 | mueve al M2, pero con retraso y ya parcialmente descontado |
| M3 — Data surprises | −2 … +2 | mueve expectativas en el corto plazo |
| M5 — Sentiment / intermarket | −2 … +2 | confirma o contradice; rara vez lidera |
| M4 — Positioning (COT) | −1 … +1 | contrarian en extremos; dato semanal y con retraso |

Score bruto: −11 … +11. **Se acota a ±10** y se redondea a entero.

[INFERRED] M2 pesa el doble que cualquier otro porque es el unico motor cuyo
efecto sobre el par es mecanico: el diferencial de tasas determina el carry.
Los demas actuan a traves de el.

---

## 3. M2 — MONETARY POLICY  (−4 … +4)

### 3.1 Componente principal: diferencial de expectativas a 12 meses

Fuente: Fed funds futures / OIS (CME FedWatch) y €STR forwards para el ECB.

    Δ = (pb de recorte esperados a la Fed en 12m) − (pb de recorte esperados al ECB en 12m)

Si la Fed va a recortar MAS que el ECB, el diferencial de tasas se cierra en
contra del USD → EURUSD alcista → aporte positivo.

| \|Δ\| | aporte |
|---|---|
| ≥ 75 pb | ±4 |
| 50 – 74 pb | ±3 |
| 25 – 49 pb | ±2 |
| 10 – 24 pb | ±1 |
| < 10 pb | 0 |

Signo: `Δ > 0` → **+** (Fed recorta mas). `Δ < 0` → **−**.

### 3.2 Modificador por tono de comunicacion

Ultimo statement / conferencia / minutas de cada banco, dentro de los 30 dias:

| situacion | ajuste |
|---|---|
| un banco vira hawkish y el otro no | ±1 a favor de su moneda |
| ambos viran igual | 0 |
| sin comunicacion relevante | 0 |

El total de M2 se acota a ±4 despues del modificador.

**No se puntua la politica actual, se puntua lo que el mercado ya descuenta.**
Una Fed en 5% con el mercado esperando cuatro recortes es bajista para el USD,
no alcista. Es el error mas comun del analisis fundamental.

---

## 4. M1 — MACRO RELATIVE STRENGTH  (−2 … +2)

Cuatro bloques, cada uno **−0,5 / 0 / +0,5**, comparando tendencia de los
ultimos 3 meses de la Eurozona **contra** Estados Unidos:

| bloque | indicadores | +0,5 si |
|---|---|---|
| actividad | PMI compuesto, GDP, produccion industrial | la Eurozona mejora relativamente |
| empleo | desempleo, NFP, claims, salarios | el mercado laboral EZ mejora relativamente |
| inflacion subyacente | Core CPI, Core PCE, Core HICP | la inflacion subyacente EZ sube relativamente (→ ECB mas hawkish) |
| consumo | retail sales, confianza del consumidor | el consumo EZ mejora relativamente |

`0` cuando la diferencia es marginal o los indicadores del bloque se contradicen.

[NOT ESTABLISHED] Que la inflacion mas alta fortalezca a la moneda. Vale
mientras el banco central este en modo "combatir inflacion". Si la inflacion se
vuelve un problema de credibilidad, el signo se invierte. Anotar el supuesto en
cada reporte donde este bloque no sea 0.

---

## 5. M3 — ECONOMIC DATA SURPRISES  (−2 … +2)

Ventana movil: **10 dias habiles**.

### 5.1 Peso por importancia del dato

| tier | datos | peso |
|---|---|---|
| 1 | CPI, Core CPI, PCE, NFP, FOMC, ECB decision, GDP | 1,0 |
| 2 | PMI, ISM, retail sales, claims, HICP flash, empleo EZ | 0,5 |
| 3 | resto | 0,25 |

### 5.2 Magnitud de la sorpresa

Criterio operativo y verificable con datos publicos, sin necesidad de una base
histórica de desvios:

| la lectura actual cayo… | factor |
|---|---|
| fuera del rango completo de estimaciones de analistas | 1,0 |
| entre el consenso y el extremo del rango | 0,5 |
| en el consenso (±redondeo) | 0 |

### 5.3 Aporte

    aporte_dato = peso × factor × 0,5 × signo

`signo`: dato fuerte de EE.UU. → **−** (USD alcista → EURUSD bajista).
Dato fuerte de la Eurozona → **+**.

Suma de todos los datos de la ventana, acotada a ±2.

[DERIVED] Un solo dato tier 1 con sorpresa maxima aporta 0,5. Hacen falta
cuatro para saturar el motor. Deliberado: una sola sorpresa no debe dominar el
score, porque el mercado la reprecia en minutos y el reporte es diario.

---

## 6. M4 — POSITIONING  (−1 … +1)  ·  CONTRARIAN

Fuente: CFTC COT, posicion neta non-commercial en EUR. Percentil sobre 3 años.

| percentil | lectura | aporte |
|---|---|---|
| > 90 | crowded long EUR | **−1** |
| 75 – 90 | long cargado | −0,5 |
| 25 – 75 | normal | 0 |
| 10 – 25 | short cargado | +0,5 |
| < 10 | crowded short EUR | **+1** |

[PROPOSED] El signo es **inverso** al posicionamiento, siguiendo §8 del sistema
del trader: un long masificado es combustible para un unwind, no confirmacion.

[NOT ESTABLISHED] Que el contrarian sea la lectura correcta. Es una eleccion, y
podria ser exactamente al reves — el posicionamiento tambien puede indicar
tendencia. Queda congelada asi para el experimento. Si E-MT5-036 llega a tener
muestra suficiente, este es el primer parametro que vale la pena examinar,
**y sólo entonces**.

**Retraso conocido:** el COT sale los viernes con datos del martes previo.
Siempre tiene entre 3 y 8 dias de antiguedad. Anotar la fecha del dato en cada
reporte.

---

## 7. M5 — SENTIMENT / INTERMARKET  (−2 … +2)

Tres componentes:

### 7.1 DXY — tendencia de 5 dias  (±0,7)

| variacion 5d | aporte |
|---|---|
| cae > 0,5% | +0,7 |
| cae 0,2 – 0,5% | +0,35 |
| ±0,2% | 0 |
| sube 0,2 – 0,5% | −0,35 |
| sube > 0,5% | −0,7 |

### 7.2 Diferencial de yields a 2 años  (±0,7)

`spread = US2Y − DE2Y`, variacion de 5 dias.

| variacion | aporte |
|---|---|
| se estrecha > 15 pb | +0,7 |
| se estrecha 5 – 15 pb | +0,35 |
| ±5 pb | 0 |
| se amplia 5 – 15 pb | −0,35 |
| se amplia > 15 pb | −0,7 |

El 2 años se elige sobre el 10 años porque descuenta politica monetaria, que es
lo que mueve al par. El 10 años mezcla prima por plazo y expectativas de
crecimiento.

### 7.3 Risk regime  (±0,6)

| regimen | criterio | aporte |
|---|---|---|
| RISK-ON | VIX baja y S&P sube, ambos | +0,6 |
| RISK-OFF | VIX sube > 15% o S&P cae > 1,5% | −0,6 |
| MIXED | se contradicen | 0 |

[NOT ESTABLISHED] Que risk-off implique USD fuerte. Es lo habitual por demanda
de refugio, pero cuando el shock **se origina** en EE.UU. el USD se debilita. Si
el evento de riesgo es estadounidense, este componente va a **0**, no a −0,6.

---

## 8. EVENT RISK  (§13 del sistema)

| nivel | criterio |
|---|---|
| **HIGH** | hay evento tier 1 (FOMC, ECB, CPI, NFP, PCE, GDP) entre ahora y el cierre de NY |
| **MEDIUM** | hay evento tier 2 |
| **LOW** | nada relevante |

Fuente operativa: **calendario nativo de MT5** (`CalendarValueHistory`), filtrado
por monedas USD y EUR e importancia `CALENDAR_IMPORTANCE_HIGH`. Implementado en
el detector, no a mano — ver §12.

---

## 9. CONVICCION  (§16)

Se cuenta un motor como **alineado** si aporta ≥ 0,5 en el mismo sentido que el
score total.

**Conflicto mayor**, cualquiera de los dos:
- dos motores con aportes opuestos y |aporte| ≥ 1,5 cada uno
- M2 apuntando en contra del signo del score total

| conviccion | condicion |
|---|---|
| **HIGH** | ≥ 4 motores alineados **y** \|score\| ≥ 5 **y** sin conflicto mayor |
| **MEDIUM** | 3 motores alineados, **o** \|score\| ≥ 5 con un conflicto mayor |
| **LOW** | ≤ 2 alineados, **o** \|score\| < 3, **o** ≥ 2 conflictos mayores |

---

## 10. ENVIRONMENT  (§17)

| entorno | condicion |
|---|---|
| **FAVORABLE** | conviccion ≥ MEDIUM, event risk ≤ MEDIUM, sin conflicto mayor |
| **UNFAVORABLE** | event risk HIGH, **o** ≥ 2 conflictos mayores |
| **MIXED** | todo lo demas |

---

## 11. BIAS Y SALIDA FINAL  (§15, §18)

| score | bias |
|---|---|
| +8 … +10 | STRONG BULLISH → LONG |
| +5 … +7 | BULLISH → LONG |
| +2 … +4 | MILD BULLISH → LONG |
| −1 … +1 | **NEUTRAL** |
| −2 … −4 | MILD BEARISH → SHORT |
| −5 … −7 | BEARISH → SHORT |
| −8 … −10 | STRONG BEARISH → SHORT |

**Regla de anulacion:** si `environment = UNFAVORABLE`, la Technical Preference
del reporte es `WAIT FOR TECHNICAL CONFIRMATION` **cualquiera sea el score**. El
bias se informa igual, para que quede registrado en el experimento.

[DERIVED] Esta regla existe por E-MT5-032: la ventaja del efecto es 0,562 pips
contra un costo de 0,838 en el instante de la señal. En una ventana de evento el
spread se ensancha mucho mas. No hay margen para pagarlo.

---

## 12. LO QUE EL SCORE NO ES

[NOT ESTABLISHED] El score **no es una probabilidad**. Un +7 no dice que EURUSD
suba con 70% de probabilidad. Dice que siete de las condiciones que este
documento define como favorables estan presentes. La relacion entre eso y el
precio futuro es precisamente lo que E-MT5-036 pretende medir, y hoy es
desconocida.

[OBSERVED] Este proyecto refuto seis hipotesis que parecian solidas. La tasa
base del dominio, medida de primera mano, es que las hipotesis plausibles
mueren sobre datos virgenes (FINDINGS-001 §3). No hay razon para suponer que
esta sea distinta.

---

## 13. FUENTES ADMITIDAS  (§25)

Federal Reserve · ECB · BLS · BEA · Eurostat · CME FedWatch · CFTC · Trading
Economics · Reuters · Bloomberg · Financial Times.

Cada afirmacion de un reporte se etiqueta:

    FACT          publicado por la fuente primaria, con su fecha
    EXPECTATION   lo que el mercado descuenta, con su fuente
    INTERPRETATION lectura propia

**Una interpretacion nunca se presenta como hecho.** Si un dato no se pudo
verificar, el reporte lo dice y el motor correspondiente va a 0. No se rellena
con estimaciones.

---

## 14. LIMITACION ESTRUCTURAL, DECLARADA DE ENTRADA

[OBSERVED] El analista que produce el score es un modelo de lenguaje con corte
de conocimiento en mayo de 2026. Todo dato posterior proviene de busqueda web en
el momento del reporte.

[DERIVED] **Este sistema solo puede evaluarse hacia adelante.** Cualquier
reporte producido para una fecha pasada esta contaminado: el analista conoce lo
que ocurrio despues. Un backtest fundamental de este motor no vale nada, y no se
va a construir. Solo cuenta lo registrado en tiempo real y sellado el mismo dia,
antes de conocer el desenlace.

Es la misma disciplina que el resto del proyecto, aplicada a un motor que no es
un binario: si no se puede sellar antes de ver el resultado, no se mide.
