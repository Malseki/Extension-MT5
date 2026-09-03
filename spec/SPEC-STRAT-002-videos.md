# SPEC-STRAT-002 — la estrategia segun los VIDEOS

Reemplaza a SPEC-STRAT-001, que se escribio solo con el texto del trader y
resulto ser una simplificacion. Fuente: `spec/videos-trader/` (7 transcripciones
+ HALLAZGOS-AUDIO.md).

**Escrito ANTES de medir.** Fecha de congelamiento: 2026-09-03.

---

## 1. Horario

Servidor MT5 = GMT+3 = ET+7. Offset aplicado: −7.

| ventana | ET |
|---|---|
| A (Nueva York) | 09:30 – 10:45 |
| B (Londres)    | 03:00 – 04:10 |

**El sweep debe ocurrir DENTRO de la ventana.** Confirmado en v3: manipulacion
a las 8:34 de su grafico = 9:34 ET → *"esta es la primera ventana"*.

Nota: el grafico del trader corre en ET−1. Sus horarios reportados estan en esa
hora, no en ET. Ya convertidos.

## 2. Niveles de liquidez  ← CAMBIO MAYOR

Antes: pivotes H1/H4.
Ahora, segun 5 de 7 videos:

- **PDH** — maximo del dia anterior (v2: *"el precio nos liquida el PDH"*)
- **PDL** — minimo del dia anterior
- **Asia High / Asia Low** — sesion asiatica, 00:00–06:00 ET del dia en curso
  (v2, v4, v5, v7: *"liquida minimo de Asia"*, *"el maximo de la sesion asiatica"*)

Un nivel se considera **barrido** cuando el precio lo penetra por ≥ 1,0 pip y
la vela cierra de vuelta del lado original.

**ENMIENDA 2026-09-03 (misma fecha, antes de leer ningun resultado valido).**
La primera version de esta spec REEMPLAZABA los pivotes H1/H4 por PDH/PDL+Asia.
Fue una sobre-correccion mia. El texto original del trader pedia "maximos y
minimos de 1h y 4h", y v5 lo confirma en video:

> *"En una hora marcamos esta liquidez, que seria como una liquidez interna"*

Son la **union**, no una alternativa. Los niveles ahora son:
PDH, PDL, Asia High, Asia Low, **pivotes H1 (3/3) y pivotes H4 (3/3)**.

Por que esta enmienda NO contamina el experimento: el pre-registro de E-MT5-039
fijo por adelantado que *"si salen menos de 50 setups, la implementacion es
sospechosa y hay que revisar el codigo ANTES de leer el resultado"*. La primera
corrida dio n=1. Se aplico esa clausula: se corrigio la implementacion sin mirar
el resultado. No es ajuste de parametro contra el resultado — es la via que el
propio pre-registro dejo escrita para este caso.

Segunda correccion de la misma tanda: marcar un nivel como "ya barrido" ahora
exige la misma penetracion minima que el sweep (1,0 pip). Antes cualquier roce
de 0,1 pip mataba el nivel, lo que era inconsistente con la propia definicion de
sweep.

[NO IMPLEMENTADO] Liquidez en linea de tendencia (v1). Es diagonal y
discrecional; no tengo definicion algoritmica honesta. Queda declarado como
faltante, no simulado.

## 3. Tendencia — NO es filtro  ← CAMBIO MAYOR

v2: *"la tendencia aca era bajista, en este caso entramos en contratendencia"*
v3: *"Estamos en contratendencia, la reaccion de las velas es buena"*

**La tendencia NO filtra.** Se registra como etiqueta (`a_favor` / `contra`)
para analizar despues por subgrupo. El filtro anterior descartaba 952 de 1032
candidatos y el trader no lo aplica.

## 4. Secuencia de entrada

1. **Sweep** de un nivel de §2, dentro de ventana, detectado en M1.
2. **CHoCH en M1** dentro de los 30 min del sweep. Pivotes 2/2, regla de origen.
3. **FVG** en direccion del trade, dentro de los 20 min del CHoCH.
   **Debe ser "claro"**: v1 — *"esta chequeado en 5, en 3 minutos y no habia FVG
   claro, entonces aca directamente no habia entrada"*.
   Definicion operativa: gap ≥ 0,5 pip en M1 **y** existe FVG solapado en M3 o
   en M5. Si solo aparece en M1, no cuenta.
4. **Entrada** al tocar el borde cercano del FVG.

## 5. Stop  ← CAMBIO

Antes: bajo el extremo del sweep.
Ahora: **al mas lejano entre el borde del FVG sin mitigar y el extremo del
sweep**, mas 0,3 pip de colchon.

**ENMIENDA 2 (2026-09-03).** La primera version usaba solo el borde del FVG
(v1: *"abajo de este FVG"*). Medido, eso da stops de 0,9 a 3,5 pips, promedio
~1,5. El costo de ejecucion es 0,838 pips: el stop quedaba del orden del spread,
o por debajo. Consecuencias mecanicas:

- una operacion con stop de 0,9 pips no es ejecutable — la mata el spread al entrar;
- con 1R < costo, el marco en R deja de significar algo: aparecen R:R de 26, 42
  y 53 que no son ganancias reales sino artefactos de dividir por un riesgo diminuto;
- el break-even a +1R se armaba casi al instante, y 9 de 15 operaciones
  terminaron en break-even por eso.

v3 dice *"aunque son varios pips de stop"* y *"capaz el stop un poquito mas
cerca del minimo"*; v1 razona con distancias de 15 y 23 pips. Ninguno opera con
stops de 1 pip. Tomar el mas lejano de los dos anclajes es lo fiel a ambos videos.

Ademas: se descarta todo setup cuyo riesgo sea **menor que el costo de
ejecucion**. No es un filtro de rendimiento — es la condicion minima para que la
operacion exista.

Esta enmienda se hace sobre una corrida que dio **R NETO +26,81**, es decir
POSITIVA. No se corrige para mejorar un resultado: se corrige porque el resultado
positivo estaba construido sobre operaciones que no se pueden ejecutar, y dependia
de 2 de 15 casos (sacando el mejor queda +9,50; sacando los dos, −4).

## 6. Objetivo  ← CAMBIO

Antes: 2R fijo.
Ahora: **la proxima zona de liquidez opuesta** (v1: *"tu proximo objetivo seria
esto de aca que es liquidez"*; v2: *"mi objetivo basicamente era este maximo"*).

Operativo: el nivel de §2 no barrido mas cercano en la direccion del trade.
Si el R:R resultante es **< 1,5 → no se toma el trade** (v1 descarta entradas
lejanas del objetivo).
Sin techo superior: v2 saco 1:3 con potencial de 1:5.

## 7. Break-even  ← NUEVO

v3: *"si vos no hubieras puesto break even, te sacaba"*
v4: *"al llegar aca yo ya voy a subir break even"*

Al alcanzar **+1R**, el stop se mueve a la entrada. Desde ahi el peor caso es 0R
(menos costo), no −1R.

## 8. MACD — NO es filtro  ← CAMBIO

v7: *"nuestro filtro, que en este caso es un MACD, pero ustedes le pueden poner
un RSI si quieren, lo que se les cante"*

Se registra como etiqueta (`macd_ok` si el histograma acompaña), no filtra.

## 9. Lo que NO se implementa y por que

| concepto | por que no |
|---|---|
| **Rejection Block** | v2/v3/v4 lo usan como gatillo, pero cada aparicion se juzga a ojo. Cualquier definicion que invente seria mia, no suya. Se registra si la vela previa al FVG tiene mecha ≥ 60% del rango, como **etiqueta**, nunca como filtro |
| **Inducement** | idem. v4 lo abandona en vivo: *"lo vamos a tratar como liquidez, mas que como Indusment. Hipotesis quedo vieja"*. Es reinterpretacion discrecional |
| **Liquidez diagonal** | §2 |
| **"Conjuncion de velas" M5+M3+M1** | v6 lo nombra sin definirlo |

Estas cuatro son **discrecionales**. Si el edge real vive ahi, este backtest no
lo va a encontrar — y eso hay que decirlo antes, no despues.

## 10. Costo

0,838 pips por entrada (E-MT5-032, medido en el instante de la señal).
Se resta siempre. El R neto es el que cuenta.
