# SPEC-STRAT-001 — SWEEP + CHoCH + FVG + HISTOGRAMA

    STATUS   REGLAS CONGELADAS. Escritas 2026-08-27 ANTES de implementar y
             ANTES de correr un solo backtest.
    FUENTE   Descripcion del trader (2026-08-27) + imagen del patron 1-2-3.
    NOTA     Los videos explicativos NO pudieron procesarse: no hay forma de
             transcribir audio en este entorno. Ver §9.

---

## 1. La secuencia completa

Seis condiciones. Todas obligatorias, en este orden:

    1. CONTEXTO    tendencia definida en H1 y H4
    2. SWEEP       toma de liquidez de un maximo/minimo de H1 o H4,
                   A FAVOR de la tendencia, dentro del horario
    3. CHoCH       cambio de estructura en M1
    4. FVG         hueco de valor justo en M1 (o M3), en el sentido operado
    5. HISTOGRAMA  MACD en M1: >0 para comprar, <0 para vender
    6. HORARIO     el SWEEP debe ocurrir dentro de la ventana

## 2. Direccion

    liquidez tomada en un MINIMO  ->  se busca COMPRA
    liquidez tomada en un MAXIMO  ->  se busca VENTA

Es contra-movimiento en el corto plazo (el precio barre y revierte) pero A FAVOR
de la tendencia mayor de H1/H4.

## 3. Horarios — hora de NUEVA YORK

    ventana A    09:30 - 10:45
    ventana B    03:00 - 04:10

**El SWEEP debe ocurrir DENTRO de la ventana.** No vale que el precio haya
liquidado el maximo o minimo antes del horario operativo. Este es el filtro que
el trader subrayo explicitamente.

[OBSERVED] 4 de los 12 trades aportados como ejemplo caen FUERA de estas
ventanas (09:03, 09:20, 08:44, 09:11), todos entre 08:44 y 09:20. O la ventana
de la mañana empieza antes, o esos horarios estan en otro huso. Queda como
parametro configurable y declarado, no resuelto.

## 4. El patron 1-2-3 (de la imagen aportada)

Ejemplo sobre MINIMOS, para compras:

    VELA 1   establece el minimo que contiene la liquidez
    VELA 2   rompe ese minimo, CIERRA POR DEBAJO y deja mecha inferior
             -> la mecha es la que toma los stops
    VELA 3   rechaza el desplazamiento bajista y NO cierra por debajo
             del minimo de la vela 2 -> confirmacion

Simetrico para maximos y ventas.

[IMPORTANTE] Esta definicion NO coincide con la de TRADER-SWEEP-001, donde un
"sweep" exige que la vela cierre de vuelta del lado original. Aca la vela 2 SI
cierra del otro lado, y la confirmacion la da la vela 3. Son dos definiciones
distintas del mismo nombre y no deben mezclarse.

## 5. Stop y objetivo

    STOP   bajo el minimo (o sobre el maximo) generado al tomar la liquidez,
           confirmado por el cambio de estructura
    TP     R:R = 1:2 -> TP = entrada + 2 x (entrada - stop), con signo

## 6. Definiciones operativas — sin esto no se puede programar

**Tendencia H1/H4:** la del motor de TRADER-STRUCTURE-002 (pivotes 5/5, BOS y
CHoCH por origen directo). Alcista = trend 1, bajista = -1.

**Liquidez H1/H4:** maximos y minimos de swing por pivotes, como
TRADER-SWEEP-001. Un nivel esta PENDIENTE mientras no fue tocado.

**Sweep valido:** el precio penetra el nivel pendiente y vuelve. Penetracion
minima configurable, por defecto 1.0 pip — medido: el 22% de los barridos
penetran menos que el spread real en la señal (0,838 p, E-MT5-032) y son
indistinguibles de ruido de cotizacion.

**CHoCH en M1:** el primer cambio de caracter en M1 posterior al sweep, en el
sentido buscado. Ventana maxima configurable, por defecto 30 minutos.

**FVG:** tres velas donde el hueco queda sin cubrir.
  alcista: low[i] > high[i-2]   -> zona (high[i-2], low[i])
  bajista: high[i] < low[i-2]   -> zona (high[i], low[i-2])
Debe formarse DESPUES del CHoCH y en el sentido operado. La entrada se activa
cuando el precio retrocede a la zona.

**Histograma MACD en M1:** MACD(12,26,9), histograma = macd - signal.
  compra: histograma > 0, o negativo pero SUBIENDO (hist > hist previo)
  venta : histograma < 0, o positivo pero BAJANDO
El trader lo describio como "arriba de cero o retrocediendo hacia el sentido en
el que apunto". La segunda mitad de esa frase es la que admite el caso en que
todavia no cruzo cero pero ya gira.

## 7. Lo que NO esta definido y se decide por defecto

| ambiguedad | decision tomada | por que |
|---|---|---|
| plazo maximo sweep -> CHoCH | 30 min | el setup es intradia y las ventanas duran 70-75 min |
| plazo CHoCH -> FVG | 20 min | idem |
| cuantos niveles de liquidez vigilar | los 20 pendientes mas cercanos | mas que eso es ruido |
| que pasa si hay 2 setups en una ventana | se toma el primero | evita elegir a posteriori |
| TF del sweep | M1, M3 o M5, cualquiera sirve | el trader lo dijo asi |

Cada una es una eleccion, no un hecho. Cambiarlas cambia el resultado, y por eso
quedan escritas ANTES de medir.

## 8. Lo que el trader aporto como evidencia

12 operaciones, 10 ganadoras, 2 perdedoras, +20R, 83% de acierto.

[NOT ESTABLISHED] Que esa tasa sea la real. Son operaciones **seleccionadas y
reportadas de memoria**, no una muestra completa: no se sabe cuantos setups
hubo en esos dias, cuantos se tomaron y no se anotaron, ni si estos son todos
los tomados o los que salieron bien. Con n=12, el intervalo de confianza del
83% va de 52% a 98%.

El punto de equilibrio con R:R 1:2 es 33,3%. Un 83% real seria extraordinario.
Justamente por eso hay que medirlo sobre una muestra que nadie eligio.

**Ese es el proposito del backtest: convertir 12 ejemplos elegidos en N casos
que la regla encuentre sola.**

## 9. Los videos NO se analizaron

Siete archivos .mov, 691 MB. Se leen, pero este entorno no puede transcribir
audio, que es donde esta la explicacion. Si ffmpeg logra instalarse se podran
extraer FOTOGRAMAS y ver los graficos; la narracion queda fuera del alcance.

**Todo lo implementado sale del texto escrito por el trader y de la imagen del
patron 1-2-3, no de los videos.** Si los videos contienen reglas que el texto no
menciona, no estan en el codigo.
