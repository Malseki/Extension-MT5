# E-MT5-038 — RESULTADO

    CORRIDA   2026-09-03, escaneo historico sobre EURUSD M1
    VENTANA   la que el historico M1 permitio: 92.309 barras (~64 dias
              de negociacion), no los años solicitados. MT5 no conserva
              mas M1 que eso.

## Embudo

    barras dentro de la ventana horaria : 8695
    con SWEEP de liquidez H1/H4         : 1032
    + tendencia H1 y H4 a favor         :   80   <- se descarta el 92%
    + CHoCH en M1                       :   49
    + FVG en el sentido                 :   38
    + histograma MACD a favor           :   36

El cuello de botella es la tendencia: exigir que H1 **y** H4 muestren
simultaneamente HH+HL (o LL+LH) elimina 952 de 1032 candidatos.

## Resultado

    operaciones      36   (32 resueltas, 4 sin cerrar)
    gana              9
    pierde           23

    HIT RATE      28.12%
    break-even    33.33%   (R:R 1:2)

    R BRUTO        -5.00
    R NETO        -14.82   (costo 0.838 p/entrada, E-MT5-032)

Riesgo medio por operacion: 6.9 pips. Con stops tan cortos el costo pesa
mucho: se lleva 9.82 R adicionales, casi el doble de la perdida bruta.

## Contra la prediccion

El pre-registro predijo "hit rate sustancialmente por debajo del 83%
reportado, y probablemente por debajo del break-even de 33.3%".

    reportado por el trader   83.00%   (12 operaciones recordadas)
    medido                    28.12%   (32 operaciones que la regla encontro sola)

La prediccion se cumple. La diferencia de 55 puntos porcentuales es la
magnitud del efecto de seleccion en operaciones recordadas.

## PERO: n insuficiente para concluir

    n = 32 resueltas
    z = (0.2812 - 0.3333) / sqrt(0.3333*0.6667/32) = -0.63

**No significativo.** El criterio del pre-registro exige n >= 100. Con 32
observaciones el resultado es negativo pero indistinguible del break-even.

No se pudo ampliar la muestra: el historico M1 de MT5 esta limitado a
~92.000 barras y el escaneo es O(barras x niveles), que a 40.000 niveles
no termina.

## Un segundo intento que hay que descartar, y por que

Para acelerar el escaneo se agrego una caducidad de 20 dias a los niveles
de liquidez. Resultado con ese cambio:

    5 setups, 2 ganan / 1 pierde, hit rate 66.67%, R bruto +3.00

Es decir: **un solo parametro agregado despues de ver el primer resultado
dio vuelta el signo**, de -5 R a +3 R, de 28% a 67%.

Ese numero NO es valido y no debe usarse. La caducidad no estaba en
SPEC-STRAT-001, se agrego despues de ver un resultado negativo, y aunque
la razon fue tecnica (rendimiento) y no cosmetica, la contaminacion es la
misma. Con n=3 resueltas, ademas, el 66.67% no significa nada.

Queda registrado como demostracion practica de por que este proyecto
congela los parametros antes de medir: la trampa no requiere mala fe, solo
un cambio razonable en el momento equivocado.

## Estado

[NOT ESTABLISHED] Que la estrategia pierda. La evidencia apunta ahi y es
coherente con E-MT5-022, E-MT5-028, E-MT5-032 y E-MT5-034, pero n=32 no
alcanza.

[OBSERVED] Que el 83% recordado no se reproduce cuando las reglas se
aplican solas sobre un periodo que nadie eligio.
