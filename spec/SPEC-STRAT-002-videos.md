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
Ahora, v1 (*"abajo de este FVG"*): **al borde lejano del FVG sin mitigar**,
mas 0,3 pip de colchon.

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
