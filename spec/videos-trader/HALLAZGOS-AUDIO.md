# Lo que dicen los videos — contraste contra lo implementado

Transcripcion: whisper.cpp local, modelo `ggml-large-v3-turbo`, español.
7 videos, 17 min, 2.337 palabras. Nada salio de la maquina.
Fecha: 2026-09-03.

El texto escrito que el trader me paso era un **resumen simplificado** de un
proceso bastante mas rico. Lo que sigue es lo que aparece en la narracion y NO
estaba en el texto.

## A. Resuelto: la discrepancia de horarios

En v3 dice: *"apertura de Nueva York, son las 8 y cuarto, faltan 15 minutos"*
→ en su grafico, Nueva York abre a las **8:30**. La apertura real es 9:30 ET.
**Su grafico corre en ET − 1 hora.**

Se confirma tres veces:
- v3: *"el precio manipula a esto de las 8 y 34 ... esta es la primera ventana"*
  → 9:34 ET, dentro de 09:30-10:45 ✓
- v3: *"entramos a las 9 y 03, buen horario"* → 10:03 ET ✓
- v4: *"liquida el minimo a las 2.30"* → 3:30 ET, dentro de 03:00-04:10 ✓

**Conclusion:** los 12 horarios que reporto (08:44-09:20) estaban en hora de su
grafico, no en ET. Convertidos son 09:44-10:20 ET: **los 12 caen dentro de la
ventana.** No habia discrepancia.

El backtest E-MT5-038 uso `InpNyOffset=-7` (servidor GMT+3 → ET) y ventana en
570 min = 09:30 ET. **Esa parte estaba bien.** El error fue mio al leer sus
timestamps como ET.

Servidor MT5 verificado: 15:10 broker con 12:15 UTC → **GMT+3 = ET+7**.

## B. El error grave: la tendencia NO es un filtro obligatorio

Implementado: el sweep debe ir **a favor** de la tendencia H1 **y** H4.
Ese filtro descarto 952 de 1032 candidatos (1032 → 80).

Lo que dice:
- v2: *"la tendencia aca era bajista, en este caso entramos en contratendencia"*
- v3: *"Estamos en contratendencia, la reaccion de las velas es buena"*

**Opera en contratendencia de forma deliberada.** El filtro que mas candidatos
mato es el que el propio trader no aplica. El resultado del backtest (28,12%
sobre n=32) se midio sobre una muestra construida con una regla que el no usa.

## C. Los niveles de liquidez son otros

Implementado: maximos/minimos de pivotes H1 y H4.

Lo que dice, en 5 de 7 videos:
- v2: *"el precio nos liquida el PDH"* · *"liquida minimo de Asia"*
- v4: *"me liquida un minimo de Asia"*
- v5: *"el minimo de la sesion de asia anterior"*
- v7: *"tomamos la liquidez de la sesion de Asia"* · *"el maximo de la sesion asiatica"*

**Los objetivos son PDH/PDL y maximo/minimo de la sesion asiatica**, no pivotes
H1/H4. Son niveles distintos y el detector no los marca.

Ademas v1: *"todo esto es liquidez ... liquidez en forma de linea de tendencia"*
→ tambien cuenta liquidez diagonal. El detector solo ve horizontales.

## D. Reglas que no estan implementadas en absoluto

| regla | evidencia |
|---|---|
| **Rejection Block** como gatillo de entrada | v2, v3, v4 — *"veo la Rejection Block, veo que el precio llega, la conjuncion es buena"* |
| **Inducement** antes del movimiento | v2, v4 — *"estoy especulando con que saque el Indusment, toque la Rejection y se vaya"* |
| **Break-even** al llegar a zona | v3, v4 — *"al llegar aca yo ya voy a subir break even"* · *"si no hubieras puesto break even te sacaba"* |
| **FVG debe ser "claro"**, chequeado en M5 y M3 | v1 — *"esta chequeado en 5, en 3 minutos y no habia FVG claro, entonces aca directamente no habia entrada"* |
| **Distancia a la proxima liquidez** como filtro | v1 — entro con 15 pips al objetivo en vez de 23; descarta entradas lejanas |
| **FVG de 4H y diario** como zona de reaccion | v5 — *"un FVG de cuatro horas, que suele ser muy respetado"* · v6 *"fair value gap en la temporalidad diaria"* |
| **Conjuncion de velas** M5+M3+M1 | v6 — *"en cinco minutos conjuncion de velas buena, en tres minutos tambien"* |

## E. Reglas implementadas mal

| implementado | lo que dice |
|---|---|
| R:R fijo 1:2 | v2 tomo **1:3** con potencial 1:5. v3 habla de 1:2 y 1:3. El objetivo real es **la proxima zona de liquidez**, no un multiplo fijo |
| MACD obligatorio | v7: *"nuestro filtro, que en este caso es un MACD, pero ustedes le pueden poner un RSI si quieren, lo que se les cante"* → es **opcional y sustituible** |
| stop bajo el extremo del sweep | v1: *"abajo de este FVG"* → el stop va bajo el **FVG sin mitigar**, no bajo el sweep |

## F. Que queda en pie del backtest E-MT5-038

El resultado (28,12%, n=32, R neto −14,82) **midio una regla que no es la del
trader**. Concretamente: exigia tendencia alineada (el no la exige), usaba
pivotes H1/H4 (el usa PDH/PDL y Asia), R:R fijo 1:2 (el usa la proxima liquidez),
sin break-even (el lo usa siempre), sin rejection block ni inducement.

[NOT ESTABLISHED] El 28,12% no refuta la estrategia del trader. Refuta *mi
version simplificada* de ella. Es un resultado sobre otra cosa.

Lo unico que si quedo establecido y sigue en pie: el costo de ejecucion
(0,838 pips en el instante de la señal, E-MT5-032) y la ausencia de sample
suficiente. Ninguna de las dos cambia con estos hallazgos.
