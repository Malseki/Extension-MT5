# E-MT5-039 — PRE-REGISTRO

Escrito **antes** de correr el escaneo. Fecha: 2026-09-03.
Reglas: `spec/SPEC-STRAT-002-videos.md` (congeladas antes de esto).
Codigo: `E-MT5-039-scan-videos.mq5`.

## 1. Por que existe este experimento

E-MT5-038 midio 28,12% sobre n=32 y salio negativo. Al transcribir los videos
quedo claro que **midio otra estrategia**: exigia tendencia alineada (el trader
opera contratendencia a proposito), usaba pivotes H1/H4 (el usa PDH/PDL y Asia),
R:R fijo (el usa la proxima liquidez) y no tenia break-even.

E-MT5-039 mide la estrategia como aparece en los videos.

## 2. Hipotesis

**H1.** La secuencia sweep(PDH/PDL/Asia) → CHoCH M1 → FVG claro → entrada al
toque, con stop al FVG, objetivo en la proxima liquidez y break-even a 1R,
produce una esperanza en R **positiva neta de costo** sobre EURUSD.

**H0.** La esperanza neta es ≤ 0.

## 3. Prediccion cuantitativa

El trader reporta 83% sobre 12 operaciones elegidas de memoria.
El punto de equilibrio depende del R:R, que ahora es variable.

Prediccion registrada **antes de medir**:

- Si el efecto es real, espero **R neto > 0** con hit rate por encima de
  `1/(1+RR_medio)`.
- Espero un embudo **mucho mas ancho** que en 038 (que quedo en 36 setups):
  al sacar el filtro de tendencia deberian sobrevivir varias veces mas
  candidatos. Estimo **entre 150 y 600 setups**. Si salen menos de 50, algo
  esta mal implementado y hay que revisar el codigo antes de leer el resultado.
- Espero que el subgrupo **contratendencia NO sea peor** que el a-favor. Si lo
  fuera, el trader estaria equivocado sobre su propia operativa.

## 4. Criterio de decision, fijado ahora

| resultado | lectura |
|---|---|
| R neto > 0 **y** n ≥ 100 **y** z > +1,96 | evidencia a favor de H1 |
| R neto > 0 pero n < 100 o z < 1,96 | sugerente, **no concluyente** |
| R neto ≤ 0 con n ≥ 100 | evidencia contra H1 |
| n < 50 | implementacion sospechosa, no se interpreta |

## 5. Analisis por subgrupo — declarados ahora, no despues

Se reportan siempre, salgan como salgan:
1. tendencia H1: `a_favor` vs `contra` vs `plana`
2. MACD: `ok` vs `no`
3. rejection block: `si` vs `no`
4. ventana A (NY) vs ventana B (Londres)
5. tipo de nivel: PDH / PDL / ASIA_H / ASIA_L

**Ninguno de estos se puede convertir en filtro despues de ver el resultado.**
Si alguno se ve prometedor, se prueba en un experimento nuevo sobre datos que
este escaneo no toco. Anoche demostre exactamente este error: agregar caducidad
de 20 dias despues de ver un resultado negativo dio vuelta el signo de −5,00R a
+3,00R. Fue descartado por eso.

## 6. Lo que este experimento NO puede responder

- **Rejection block e inducement**: el trader los usa como gatillo y los juzga
  a ojo. Estan como etiqueta, no como regla. Si el edge vive ahi, este escaneo
  no lo encuentra.
- **Liquidez diagonal** (lineas de tendencia, v1): no implementada.
- **"Conjuncion de velas"** (v6): nombrada sin definir.
- El historial M1 de MT5 llega a ~92.000 barras. Si eso no alcanza para n≥100,
  el resultado queda sin poder estadistico y hay que acumular hacia adelante.

## 7. Supuesto conservador declarado

Dentro de una barra M1 no se conoce el orden de maximo y minimo. Se asume
**siempre que el movimiento adverso ocurre primero**. Esto subestima el
resultado: es deliberado.
