# SPEC-RB-IDM-001 — Rejection Block e Inducement

Derivado de las transcripciones de los 7 videos (`spec/videos-trader/`).
**Escrito antes de medir ningun resultado.** Fecha: 2026-09-03.

Motivo: la version mecanica de la estrategia (E-MT5-039) encuentra 0,65 setups
por mes. El trader reporta 12 en pocos dias. La diferencia esta en estos dos
conceptos, que hasta ahora estaban declarados como NO implementados.

---

## 1. REJECTION BLOCK

### Lo que dicen los videos

> v2: *"el precio liquida minimo de Asia / y tenemos aca esta Rejection, que el
> precio viene a reaccionar"*
> v2: *"a muy simple vista, tenes aca una Rejection Block / que tambien estaba
> en dos minutos"*
> v2: *"fijense que el precio toma la liquidez / reacciona la Rejection / y entre"*
> v2: *"esta vela abre inclusive arriba de esta vela / que deja un poco de
> rechazo en la zona de la Rejection"*
> v4: *"primero liquida el minimo a las 2.30, vuelve a retestear la zona, me
> deja este Rejection Block de aca"*
> v3: *"Vela tipo rejection block / La cual reacciona"*

### Lectura

El Rejection Block **es la vela que produjo la toma de liquidez**: la que metio
la mecha mas alla del nivel y cerro de vuelta. Despues se convierte en una zona
a la que el precio **vuelve** ("vuelve a retestear") y desde la que reacciona.
La entrada es en ese retest, no en la toma.

### Definicion operativa

Dada una barra `i` que barre un nivel `L` en direccion `dir`:

1. La vela `i` penetra `L` por >= 0,5 pip y **cierra del lado original**.
2. La **mecha del lado del barrido** mide >= 50% del rango total de la vela.
   (es lo que hace que sea "rechazo" y no simple continuacion)
3. **Zona RB**:
   - barrido de maximo (dir = venta): desde `max(open, close)` hasta `high`
   - barrido de minimo (dir = compra): desde `min(open, close)` hasta `low`
4. **Confirmacion multi-temporal**: existe una vela con la misma forma y zona
   solapada en M3 **o** M5. v2 lo dice explicito: *"tambien estaba en dos minutos"*.
5. **Disparo**: el precio vuelve a entrar en la zona RB dentro de los 60 min.

### Lo que queda como eleccion mia y no del video

- el 50% de mecha (el video dice "rechazo", no da numero)
- los 60 min de validez
- usar M3/M5 como confirmacion (el video nombra "dos minutos", que MT5 no tiene
  como temporalidad estandar; M3 es la mas cercana hacia arriba)

Estan marcadas para que se puedan corregir con datos etiquetados (§3).

---

## 2. INDUCEMENT

### Lo que dicen los videos

> v2: *"ya habiamos tenido un impulso bastante fuerte / que se lleva a estas
> anteriores velas / dejandonos el Indusment y rompiendo la estructura con
> bastante fuerza"*
> v4: *"Y con un Indusment de aca, asi que estoy especulando con que saque el
> Indusment, toque la Rejection y se vaya"*
> v4: *"Lo vamos a tratar como liquidez, mas que como Indusment. Esto ya no me
> sirve. Hipotesis quedo vieja."*
> v3: *"Esto podria llegar a ser un inducement"*

### Lectura

El Inducement es un **maximo o minimo menor que queda entre el precio actual y
la zona real** (el Rejection Block o el FVG). Es la trampa: ahi estan los stops.
La secuencia que el trader espera es **primero se toma el inducement, despues el
precio llega a la zona, y recien ahi se va**.

v4 es la clave de cuando NO vale: si el inducement se toma y no pasa lo
esperado, deja de ser inducement y pasa a ser simplemente liquidez. El propio
trader descarta su hipotesis en vivo.

### Definicion operativa

Despues del CHoCH y antes de la entrada:

1. Se busca el **pivote menor (2/2) mas reciente en direccion contraria al
   trade**, situado **entre el precio del CHoCH y la zona de entrada**.
2. Ese pivote es el Inducement.
3. **Setup con inducement tomado**: el precio penetra ese pivote por >= 0,3 pip
   **antes** de tocar la zona. Es la secuencia de v4.
4. **Setup sin inducement**: el precio llega a la zona sin haberlo tomado.
5. Si no existe ningun pivote menor entre medio, el setup es "sin inducement
   disponible" — categoria distinta de "no tomado".

**El inducement NO filtra.** Se registra en tres categorias (`tomado`,
`no_tomado`, `no_habia`) porque v4 muestra al trader cambiando de opinion sobre
el mismo nivel en vivo. Convertirlo en filtro seria fingir una certeza que el
video no tiene.

---

## 3. QUE MEDICION HACE FALTA PARA SER PRECISO

Esto es lo que el detector NO puede resolver solo, y es la pregunta concreta.

### 3.1 Lo que falta: ejemplos etiquetados

Las tres decisiones marcadas arriba (50% de mecha, 60 min, M3/M5) son mias, no
del video. Cualquiera de las tres cambia cuantos casos aparecen. Para fijarlas
no hace falta que el trader escriba reglas: **alcanza con que marque casos**.

La medicion concreta que hace falta es:

> Una lista de **fecha y hora exacta** (con la zona horaria de su grafico) de
> instancias que el trader considere Rejection Block **y de instancias que
> NO lo sean pero se le parezcan**. Idem para Inducement.
> Con **15-20 de cada** alcanza para fijar los umbrales.

Los negativos son tan necesarios como los positivos: sin ellos no hay forma de
saber si la definicion es demasiado laxa.

### 3.2 Como se convierte en una tarea facil

En vez de pedirle que busque casos, el detector genera **candidatos con fecha,
hora y precio**, y el trader responde si / no sobre cada uno. Eso convierte un
problema de especificacion en una tarea de etiquetado.

Es lo que produce `E-MT5-040-rb-idm-scan.mq5`.

### 3.3 Calibracion por FRECUENCIA, no por resultado

Mientras no haya etiquetas, hay un ancla que si se puede usar sin contaminar
nada: **cuantos setups por dia**.

El trader reporta 12 operaciones en pocos dias. Una definicion que produce 0,65
por mes esta mal por frecuencia sola, sin mirar si gana o pierde. La frecuencia
es observable y no filtra por resultado, asi que calibrar contra ella **no es
ajuste de curva**.

Criterio fijado ahora, antes de medir:

| setups/dia que produzca la definicion | lectura |
|---|---|
| < 0,3 | demasiado estricta, no es lo que hace el trader |
| 0,5 - 3 | compatible con lo que reporta |
| > 6 | demasiado laxa, esta marcando ruido |

### 3.4 CORRECCION 2026-09-03 — los videos SON los datos etiquetados

Se extrajeron fotogramas de v4 en el segundo exacto en que el trader dice
*"me deja este Rejection Block de aca"* (00:00:34) e *"Indusment de aca"*
(00:00:42). Lo que muestra la pantalla cambia dos cosas:

**(a) Los videos son REPLAYS de fechas pasadas.** v4 se grabo el 2026-08-11
pero esta reproduciendo el **viernes 10 de abril de 2026** (etiqueta en pantalla
`Fri 10 Apr '26`, plataforma FX Replay sobre feed OANDA).

Consecuencia: el cruce que se hizo contra las fechas de los archivos de video
(0 de 4 coincidencias) **no probaba nada**: comparaba contra las fechas de
GRABACION, no contra las fechas de los setups. Queda retirado.

**(b) El grafico corre en UTC−4, o sea hora de Nueva York exacta.**
Reloj en pantalla: `03:33:59 UTC-4`. La inferencia previa de ET−1, sacada de v3,
era incorrecta.

Eso reabre la discrepancia de la ventana, con una explicacion mejor: en v3 dice
que Nueva York abre a las 8:30 de su grafico. Si el grafico ya esta en ET, se
refiere a la apertura de las **8:30 ET** (apertura de futuros / horario de
noticias), no a la de acciones de las 9:30. Sus 12 operaciones entre 08:44 y
09:20 ET caen dentro de una ventana que arranca 8:30, no 9:30.

[NOT ESTABLISHED] Que su ventana real sea 08:30-09:45 ET. Es la lectura que
concilia v3, el huso horario verificado y los 12 horarios, pero el trader
escribio 09:30-10:45 y no lo confirmo.

**(c) La medicion que hacia falta ya existe y se puede cosechar.**
No hace falta pedirle que etiquete casos: la fecha del replay, la hora y el
precio **estan a la vista en cada fotograma**. Procedimiento:

1. `whisper-cli -osrt` da el segundo exacto de cada mencion ("Rejection Block",
   "Indusment", "cambio de estructura", "FVG").
2. `ffmpeg -ss <segundo>` extrae el fotograma.
3. Del fotograma se leen: fecha del replay, hora, precio y la zona que dibujo.

Primer caso extraido asi, para usar como positivo conocido:

| campo | valor |
|---|---|
| fecha del replay | 2026-04-10 (viernes) |
| hora | ~03:00 ET (ventana de Londres) |
| instrumento | EURUSD, M1, OANDA |
| zona Rejection Block | 1.16820 - 1.16833 (~1,3 pips de alto) |
| nivel barrido | ~1.16835, un minimo anterior de las ~02:30 |

### 3.5 Lo que sigue sin poder medirse

- **Zona horaria exacta de su grafico.** Se derivo ET−1 de v3
  (*"apertura de Nueva York, son las 8 y cuarto, faltan 15 minutos"*), y encaja
  con sus 12 horarios y con v4. Pero es inferencia, no dato.
- **Cuantos setups VE contra cuantos TOMA.** Los 12 son los tomados. Si ve 30 y
  toma 12, la frecuencia objetivo es otra.


---

## 4. RESULTADO DE LA CALIBRACION POR FRECUENCIA (2026-09-03)

Se probo el detector contra el unico positivo etiquetado disponible: el caso de
v4, extraido del fotograma (2026-04-10, ~03:00 ET, EURUSD).

### 4.1 Falsacion y diagnostico

Con niveles PDH/PDL + Asia + pivotes H1/H4, el 2026-04-10 **no aparecia**.

El fotograma muestra por que: el nivel que el trader barre es **un minimo del
propio M1 de ~27 minutos antes** (la linea horizontal se extiende desde las
~02:30 hasta la vela del sweep a las ~02:57). No es PDL, ni minimo de Asia, ni
un pivote H1/H4. Es la "liquidez interna" que v5 nombra:

> v5: *"En una hora marcamos esta liquidez, que seria como una liquidez interna"*

### 4.2 Correccion aplicada

Se agregaron pivotes 3/3 de **M5 y M15** al conjunto de niveles.

| medida | antes | despues |
|---|---|---|
| niveles | 662 | 1.691 |
| sweeps | 25 | 180 |
| + rejection (mecha >=50%) | 14 | 118 |
| + confirmado M3/M5 | 10 | 107 |
| + retest valido | 7 | 76 |
| **candidatos por dia** | **0,24** | **2,62** |
| candidatos el 2026-04-10 | 0 | 4 |

**2,62/dia cae dentro de la banda 0,5-3 declarada como "compatible" en §3.3
ANTES de medir.** La calibracion por frecuencia se cumplio.

Composicion de los 76 candidatos: 53 M5_L, 16 M5_H, 3 H1_L, 2 PDL, 1 H1_H,
1 ASIA_L. **El 91% es liquidez interna.** El conjunto de niveles anterior no
podia ver el 91% de lo que el trader opera.

### 4.3 Lo que NO se puede afirmar todavia

El candidato de las **02:57 ET del 10 de abril** coincide en fecha, hora
(~02:57-03:00) y tipo de nivel (M5_L) con el Rejection Block del video. Pero la
zona no calza exacta:

| | zona |
|---|---|
| video (FX Replay, feed OANDA) | 1,16820 - 1,16833 |
| candidato (feed del broker MT5) | 1,16840 - 1,16857 |

[NOT ESTABLISHED] Que sean el mismo evento. La diferencia es de ~1-2 pips y hay
una explicacion visible: el fotograma muestra `C1.16832` en un minuto donde los
datos de MT5 dan ~1,16843. **Son feeds distintos** (OANDA contra el broker del
terminal). Eso explicaria el corrimiento, pero no esta verificado.

Para cerrarlo hace falta cosechar mas positivos con el metodo de §3.4 y ver si
el corrimiento es constante. Con un solo caso no se distingue "misma zona con
otro feed" de "zona distinta".

### 4.4 Advertencia sobre lo que esto NO demuestra

Que la definicion ahora encuentre lo que el trader encuentra **no dice nada
sobre si gana**. E-MT5-040 no mide resultado a proposito. Lo unico establecido
es que la definicion pasa la calibracion de frecuencia y ya no es ciega al tipo
de nivel que el trader usa.

Medir rendimiento sobre estos 76 candidatos, ahora que ya se vio el embudo,
seria medir sobre datos que ya se miraron. Ese experimento va aparte, con su
propio pre-registro.
