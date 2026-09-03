# E-MT5-039 — RESULTADO

    CORRIDA   2026-09-03 09:46 (hora local), EURUSD
    DATOS     M1=620.666 barras · M3=207.012 · M5=124.227 · H1=10.366 · D1=434
              rango 2025.01.01 a 2026.09.03
    REGLAS    SPEC-STRAT-002-videos.md (congelada + 2 enmiendas declaradas)
    CODIGO    E-MT5-039-scan-videos.mq5

## Veredicto

**NO INTERPRETABLE.** El pre-registro fijo: *"n < 50 → implementacion sospechosa,
no se interpreta"*. Salieron **13 setups**. Queda por debajo del piso propio.

No es un resultado negativo ni positivo: es una muestra insuficiente.

## Embudo

    63.131  barras dentro de ventana horaria
        80  + sweep de PDH/PDL/Asia/pivotes H1-H4 dentro de la ventana
        58  + CHoCH en M1 dentro de 30 min
        42  + FVG en el sentido dentro de 20 min
        23  + FVG "claro" (confirmado en M3 o M5)
        18  + el precio vuelve a tocar el FVG
        13  + R:R >= 1,5 hasta la proxima liquidez

## Numeros

    13 operaciones:  2 ganan · 4 pierden · 5 break-even · 2 sin resolver
    hit rate 33,33% (2 de 6 decididas)
    R BRUTO  +3,97
    R NETO   +1,52   (costo 0,838 pips)
    riesgo: minimo 1,1 p · mediana 7,9 p · maximo 15,6 p

**Todo el resultado es una sola operacion.** Sacando la mejor (2025.09.12, PDH,
+6,05R): R bruto **−2,08**, R neto **−4,32**.

## Subgrupos (declarados antes de medir, se reportan salgan como salgan)

| tendencia H1 | n | R neto |
|---|---|---|
| contra | 4 | **+5,41** |
| plana | 4 | −0,55 |
| a favor | 5 | −3,34 |

| ventana | n | R neto |
|---|---|---|
| B (Londres 03:00-04:10 ET) | 7 | **+4,79** |
| A (NY 09:30-10:45 ET) | 6 | −3,27 |

| MACD | n | R neto |   | rejection block | n | R neto |
|---|---|---|---|---|---|---|
| ok | 11 | +2,67 |   | no | 12 | +2,62 |
| no | 2 | −1,15 |   | si | 1 | −1,10 |

Tipo de nivel: PDH +5,03 (n=3) · H1_L +0,72 (n=2) · ASIA_H −0,61 (n=2) ·
PDL −0,36 (n=3) · H1_H −1,10 (n=1) · ASIA_L −2,16 (n=2).

**Ninguno de estos subgrupos significa nada con n ≤ 7.** El de "contratendencia"
apunta en la direccion que el trader afirma, pero lo sostiene 1 sola operacion.
Convertir cualquiera de estos en filtro seria exactamente el error que este
proyecto ya cometio dos veces.

## El hallazgo que si importa

13 setups en 20 meses = **0,65 por mes**. El trader reporta 12 operaciones en
pocos dias. La diferencia es de dos ordenes de magnitud.

Eso no se arregla con mas datos: significa que **la parte mecanizable de su
estrategia no es la que genera su frecuencia**. Lo que la genera es lo que quedo
declarado como NO implementado en SPEC-STRAT-002 §9:

- rejection block e inducement (los usa como gatillo, los juzga a ojo)
- liquidez en linea de tendencia (v1)
- "conjuncion de velas" M5+M3+M1 (v6, nombrada sin definir)
- leer el FVG a ojo en vez de la regla mecanica de 3 barras
- "liquidez interna" (v5): niveles intradia mucho mas numerosos que
  PDH/PDL/Asia/pivotes

## Historial de corridas de este experimento (ninguna se oculta)

| # | n | R neto | por que se descarto |
|---|---|---|---|
| 1 | 1 | −0,70 | MaxBars=100000 truncaba el M1 a 68 dias; ademas los pivotes H1/H4 estaban reemplazados en vez de sumados |
| 2 | 15 | **+26,81** | stops de 0,9-3,5 pips contra un costo de 0,838: operaciones no ejecutables. R:R de 26, 42 y 53 eran artefactos de dividir por un riesgo diminuto |
| 3 | 13 | +1,52 | esta. Valida mecanicamente, insuficiente estadisticamente |

La corrida 2 dio **positiva** y se descarto igual. El criterio no es el signo del
resultado sino si las operaciones existen.

## Que haria falta

Para llegar a n ≥ 100 con 0,65 setups/mes harian falta ~13 años de M1, que no
existen. Las dos vias reales:

1. **Acumular hacia adelante**: dejar el detector registrando esta secuencia en
   vivo. Sigue siendo lento (0,65/mes).
2. **Mecanizar lo discrecional**: definir rejection block e inducement con el
   trader, por escrito, y volver a medir. Ahi es donde vive su frecuencia — y
   probablemente su edge, si lo hay.

La opcion 2 es la unica que cambia el orden de magnitud.
